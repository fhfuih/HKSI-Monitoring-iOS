//
//  QNScaleModel.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 23/4/2024.
//
/** SDK doc: https://yolandaqingniu.github.io/zh/ */

import Foundation
import SwiftUI
import os.log
import ObservableUserDefault

//fileprivate let qnAppId = "XGKJ202410"
//fileprivate let qnConfigFileName = "XGKJ202410"
fileprivate let qnAppId = "123456789"
fileprivate let qnConfigFileName = "123456789"


enum QNSdkStatus {
    case unloaded, loading, ready, error
}

struct QNDeviceAndState: Identifiable {
    var device: QNBleDevice
    var state: QNScaleState

    var id: String {
        get {
            device.mac
        }
    }
}

@Observable
class QNScaleModel: NSObject {
   
    /// Whether the entire SDK is loaded successfully
    var sdkStatus: QNSdkStatus = .unloaded

    /// Whether there is an error when the SDK tries to load
    var sdkError: Error? = nil

    /// Whether the SDK is scanning for scale devices
    var isScanning = false
    
    /// The state of `waitForSelectedDevice` async call, oppose to generic `isScanning` state
    var isWaitingForSelectedDevice = false

    /// The list of devices discovered (EXCLUDING the connected devices)
    var scannedDevices: [String: QNDeviceAndState] = [:]

    /// The list of connected devices
    var connectedDevices: [String: QNBleDevice] = [:]
    
    /// Intermediate value: only weight is available
    var intermediateWeight: Double?
    
    /// Final value: convert the QNScaleData object to a customized struct
    /// because QNScaleData is dynamic
    /// https://yolandaqingniu.github.io/zh/attouched_list/body_indexes.html
    var finalValue: BodyPrediction?
    
    /// The Bluetooth permission, in an observable (notify UI update when change).
    /// But there is no API to subscribe to bluetooth permission change!!!
    /// I must subcribe to foreground/background change of the entire app
    /// because a bluetooth permission popup triggers that event
    /// https://stackoverflow.com/questions/75033894/is-it-possible-to-detect-when-the-user-answers-the-bluetooth-permission-request
    private(set) var hasBluetoothPermission: Bool = CBCentralManager.authorization == .allowedAlways
    
    /// The user-selected device
    /// default is the last-connected device
    /// It is saved as a prefence so that it is auto-connected next time
    @ObservationIgnored
    @AppStorage("scale")
    var _selectedDevice: QNDeviceInfo?
    
    var selectedDevice: QNDeviceInfo? {
        get {
            access(keyPath: \.selectedDevice)
            return _selectedDevice
        }
        set {
            withMutation(keyPath: \.selectedDevice) {
                _selectedDevice = newValue
            }
        }
    }

    /// The Bluetooth permission request popup appears when creating a `CBCentralManager` object
    /// There is NO API like `askForPermission`
    /// I really hate Apple. They make messy SDK for developers while boasting s^^t at every WWDC.
    @ObservationIgnored
    private var __cbManager = CBCentralManager()

    @ObservationIgnored
    private var qnBleApi: QNBleApi {
        get { return QNBleApi.shared() }
    }
    
    /// This function and the AsyncStream allow `waitForSelectedDevice` to `await` until a specific device is added
    /// Note that `deviceDiscoveryStream` must be `lazy` because it modifies `addToDeviceDiscoveryStream`
    @ObservationIgnored
    private var addToDeviceDiscoveryStream: ((QNBleDevice) -> Void)?
    @ObservationIgnored
    lazy private var deviceDiscoveryStream: AsyncStream<QNBleDevice> = {
        AsyncStream { cont in
            addToDeviceDiscoveryStream = { qnBleDevice in
                cont.yield(qnBleDevice)
            }
        }
    }()
    
    override init() {
        super.init()
        
        /// Don't initialize SDK if in preview
        guard !isInPreview() else {
            logger.debug("QNScaleModel skipping SDK initialization because in XCode preview")
            return
        }
        
        if (CBCentralManager.authorization != .allowedAlways) {
            logger.debug("QNScaleModel skipping SDK initialization because Bluetooth is not ready")
        } else {
            logger.debug("QNScaleModel initializing SDK...")
            initSdk()
        }
    }
    
    func checkBluetoothPermission() -> Void {
        self.hasBluetoothPermission = CBCentralManager.authorization == .allowedAlways
        if self.hasBluetoothPermission && self.sdkStatus == .unloaded {
            self.initSdk()
        }
    }
    
    /// This function is intended to be used on `WelcomeScreen`
    func waitForSelectedDevice() async throws -> Void {
        if self.selectedDevice == nil {
            throw QNError.missingSelectedDevice
        }
        
        /// Set UI state
        isWaitingForSelectedDevice = true
        defer {
            isWaitingForSelectedDevice = false
        }

        /// Ensure that `deviceDiscoveryStream` (lazy) is initialized --- device discovery callback is registered
        let deviceStream = self.deviceDiscoveryStream

        /// Start scanning. Now every device should enter `deviceDiscoveryStream`
        try await self.startScanning()
        logger.debug("QNScaleModel waitForSelectedDevice scanning started")
        
        /// ====== Wait for the discovery of selectedDevice, with timeout ======
        /// https://stackoverflow.com/questions/74710155/how-to-add-a-timeout-to-an-awaiting-function-call
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    /// Start waiting for devices
                    for await qnBleDevice in deviceStream {
                        guard qnBleDevice.mac == self.selectedDevice?.mac else { continue }
                        return /// Terminate the infinate waiting loop so that It won't wait forever and get timed-out
                    }
                }
                
                group.addTask {
                    /// timeout
                    try await Task.sleep(for: .seconds(8))
                    throw CancellationError()
                }
                
                /// see if fetch succeeded
                guard let _ = try await group.next() else {
                    /// theoretically, it should not be possible to get here (as we either return a value or throw an error), but just in case
                    throw QNError.waitSelectedDeviceTimeout
                }
                
                /// if we successfully fetched a value, cancel the timeout task, and return
                group.cancelAll()
                return
            }
        } catch is CancellationError {
            /// Convert `CancellationError` to our custom `waitSelectedDeviceTimeout` error
            throw QNError.waitSelectedDeviceTimeout
        }
        logger.debug("QNScaleModel waitForSelectedDevice discovered selected device")
        /// ====== ======
        
        guard let selectedDevice else {
            /// Theoretically we cannot get here. But just in case `selectedDevice` is changed when we are waiting for devices
            throw QNError.missingSelectedDevice
        }
        try await connectDevice(selectedDevice.mac)
        logger.debug("QNScaleModel waitForSelectedDevice connected to selected device")
    }
    
    /// The following functions (scanning and selecting devices) are intended to be used on `SettingsScreen`
    func startScanning() async throws {
        if isScanning { return }

        // Whether successfully start scanning or not,
        // clear scanned device list anyway
        scannedDevices = [:]
        
        return try await withCheckedThrowingContinuation { continuation in
            qnBleApi.startBleDeviceDiscovery { error in
                // error if it fails to start
                if (error != nil) {
                    logger.error("Error starting scan: \(error)")
                    continuation.resume(throwing: QNError.cannotStartScanning)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func stopScanning() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            qnBleApi.stopBleDeviceDiscorvery { error in
                // error if it fails to stop
                if (error != nil) {
                    logger.error("Error stoping scan: \(error)")
                    continuation.resume(throwing: QNError.cannotStopScanning)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func connectDevice(_ deviceMac: String) async throws {
        // 调用连接前，最好把之前的扫描给停止
        //（我们发现部分手机同时蓝牙扫描和蓝牙连接，会降低连接成功的失败率）
        // 停止扫描后，延迟个 200~500ms 再调用连接，会提升连接的成功率
        guard let device = scannedDevices[deviceMac]?.device else {
            return
        }
        
        // IMPORTANT! Please terminate with unsupported device here
        // So that no delays will be made later
        if device.deviceType != .userScale {
            throw QNError.deviceNotSupported
        }
        
        // Stop scanning and wait for 500ms (according to QN doc)
        // But don't care if it fails
        try! await stopScanning()
        try? await Task.sleep(nanoseconds: 500)
        
        switch device.deviceType {
        case .userScale:
            let config = QNUserScaleConfig()
            let visitorUser = QNUser()
            visitorUser.userId = "Booth user"
            visitorUser.height = 165
            visitorUser.gender = "female"
            visitorUser.birthday = ISO8601DateFormatter().date(from: "2000-01-01T00:00:00+08:00")
            visitorUser.athleteType = .sport
//            visitorUser.clothesWeight = 0 // TODO
            config.isVisitor = true
            config.curUser = visitorUser
            return try await withCheckedThrowingContinuation { continuation in
                qnBleApi.connectUserScale(
                    device,
                    config: config,
                    callback: { error in
                        if (error != nil) {
                            logger.error("Error connecting to device \(device.mac): \(error)")
                            continuation.resume(throwing: QNError.cannotConnect)
                        } else {
                            continuation.resume()
                        }
                    }
                )
            }
        default:
            throw QNError.deviceNotSupported
        }
    }
    
    func connectDevice(_ device: QNBleDevice!) async throws {
        return try await connectDevice(device.mac)
    }
    
    func disconnectDevice(_ device: QNBleDevice) async throws {
        guard connectedDevices.keys.contains(device.mac) else {
            return
        }

        return try await withUnsafeThrowingContinuation { continuation in
            qnBleApi.disconnectDevice(device) { error in
                if (error != nil) {
                    logger.error("Error disconnecting device \(device.mac): \(error)")
                    continuation.resume(throwing: QNError.cannotDisconnect)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func disconnectDevice(_ deviceMac: String) async throws {
        guard connectedDevices.keys.contains(deviceMac) else {
            return
        }
        
        return try await withUnsafeThrowingContinuation { continuation in
            qnBleApi.disconnectDevice(withMac: deviceMac) { error in
                if (error != nil) {
                    logger.error("Error disconnecting device \(deviceMac): \(error)")
                    continuation.resume(throwing: QNError.cannotDisconnect)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func disconnectDevice() async throws {
        if selectedDevice != nil {
            return try await disconnectDevice(selectedDevice!.mac)
        }
    }
    
    // This function is not converted into async mode
    // Rather, it stores error state in sdkStatus and sdkError properties
    // Because it is automatically called once on object init
    // where no one can catch the errors
    private func initSdk() {
        sdkStatus = .loading
        sdkError = nil
        
        let file = Bundle.main.path(forResource: qnConfigFileName, ofType: "qn")
        
        qnBleApi.initSdk(qnAppId, firstDataFile: file, callback: { error in
            if (error != nil) {
                self.sdkStatus = .error
                self.sdkError = error
                logger.debug("Error init QN scale SDK: \(error)")
            } else {
                self.sdkStatus = .ready
                self.qnBleApi.discoveryListener = self
                self.qnBleApi.connectionChangeListener = self
                self.qnBleApi.dataListener = self
                self.qnBleApi.logListener = self
                logger.debug("Init QN scale SDK.")
            }
        })
    }
}

/// Event handlers of bluetooth device scanning/discovery/management
extension QNScaleModel: QNBleDeviceDiscoveryListener {
    func onStartScan() {
        logger.log("Start Scan")
        isScanning = true
    }
    
    func onDeviceDiscover(_ device: QNBleDevice!) {
        logger.debug("""
            Discover device \(device.mac):
            name=\(device.name)
            modeId=\(device.modeId)
            bluetoothName=\(device.bluetoothName)
            RSSI=\(device.rssi)
            screenState=\(device.screenState.rawValue)
            supportWifi=\(device.isSupportWifi)
            deviceType=\(device.deviceType.rawValue)
            maxUserNum=\(device.maxUserNum)
            registeredUserNum=\(device.registeredUserNum)
            isSupportEightElectrodes=\(device.isSupportEightElectrodes)
            """)
        
        if (scannedDevices[device.mac] != nil) {
            // Device already found in last scan
            // Preserve last device state
            // But change device object because the RSSI, user, name, etc. may change
            scannedDevices[device.mac]!.device = device
        } else {
            // Device is not found in last scan
            // Create new device entry
            scannedDevices[device.mac] = QNDeviceAndState(device: device, state: .disconnected)
        }
        
        addToDeviceDiscoveryStream?(device)
    }
    
    func onBroadcastDeviceDiscover(_ device: QNBleBroadcastDevice!) {
        logger.debug("Found Broadcast Device (unsupported)")
    }
    
    func onKitchenDeviceDiscover(_ device: QNBleKitchenDevice!) {
        logger.debug("Found Kitchen Device (unsupported)")
    }
    
    func onStopScan() {
        logger.log("Stop Scan")
        isScanning = false
    }
}

/// Event handlers when any bluetooth device's state changes
extension QNScaleModel: QNBleConnectionChangeListener {
    func onConnecting(_ device: QNBleDevice!) {
        if scannedDevices[device.mac] == nil {
            logger.warning("Connecting to a device [\(device.mac), \(device.bluetoothName)] not listed in scannedDevices.")
        } else {
            logger.debug("Connecting to \(device.mac), \(device.bluetoothName)")
        }
        
        // If the device is liste in the connectedDeivce list, remove it
        connectedDevices[device.mac] = nil
        scannedDevices[device.mac] = QNDeviceAndState(device: device, state: .connecting)
    }
    
    func onConnected(_ device: QNBleDevice!) {
        // If the device is not listed in the scannedDevice list, issue a warning BUT STILL PROCEED
        // Because we use a dedicated array to store the connected devices
        if scannedDevices[device.mac] == nil {
            logger.warning("Connected to a device [\(device.mac), \(device.bluetoothName)] not listed in scannedDevices")
        } else {
            logger.debug("Connected to \(device.mac), \(device.bluetoothName)")
            scannedDevices[device.mac] = nil // Remove the item from the scannedDevice list
        }
        
        // Move the item to the connectedDevice list
        connectedDevices[device.mac] = device
        // Save this (new?) device as the selectedDevice
        if (selectedDevice?.mac != device.mac) {
            selectedDevice = QNDeviceInfo(device)
        }
    }
    
    func onServiceSearchComplete(_ device: QNBleDevice!) {
        //该状态是搜索服务完成后的方法，通常这个方法无需业务逻辑
    }
    
    func onDisconnecting(_ device: QNBleDevice!) {
        if connectedDevices[device.mac] == nil {
            logger.warning("Disconnecting from a device [\(device.mac), \(device.bluetoothName)] not listed in connectedDevices.")
        } else {
            logger.debug("Disconnecting from \(device.mac), \(device.bluetoothName)")
        }
        
        // If the device is liste in the connectedDeivce list, remove it and move to scannedDevice
        connectedDevices[device.mac] = nil
        scannedDevices[device.mac] = QNDeviceAndState(device: device, state: .disconnecting)
    }
    
    func onDisconnected(_ device: QNBleDevice!) {
        logger.debug("Disconnected from \(device.mac), \(device.bluetoothName)")
        
        connectedDevices[device.mac] = nil // Removes value
        scannedDevices[device.mac] = QNDeviceAndState(device: device, state: .disconnected)
    }
    
    func onConnectError(_ device: QNBleDevice!, error: (any Error)!) {
        // 错误码参考附表
        logger.error("Connection Error: \(error) with device \(device.mac), \(device.bluetoothName)")
        
        connectedDevices[device.mac] = nil // Removes value
        scannedDevices[device.mac] = QNDeviceAndState(device: device, state: .disconnected)
        
    }
}

extension QNScaleModel: QNLogProtocol {
    func onLog(_ log: String) {
//        logger.debug("The Content of LogListener: \(log)")
    }
}

/// Event handlers when receiving data from a bluetooth device
extension QNScaleModel: QNScaleDataListener {
    /// Intermediate weight data during the session
    func onGetUnsteadyWeight(_ device: QNBleDevice!, weight: Double) {
        logger.debug("QNScale Received unsteady weight \(weight) from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
        guard device.mac == self.selectedDevice?.mac else { return }
        self.intermediateWeight = weight
    }
    
    /// Stablized data (including weight and others)
    func onGetScaleData(_ device: QNBleDevice!, data scaleData: QNScaleData!) {
        logger.debug("QNScale Received stablized data: \(scaleData.weight) from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
        guard device.mac == self.selectedDevice?.mac else { return }
        self.finalValue = BodyPrediction(
            weight: scaleData.weight,
            bodyFat: scaleData.getItemValue(.bodyFatRate)
        )
    }
    
    /// When the user used the scale just before BLE connection, the cached data is sent, instead of real-time data
    func onGetStoredScale(_ device: QNBleDevice!, data storedDataList: [QNScaleStoreData]!) {
        logger.debug("QNScale Received stored data: \(storedDataList) from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
    }
    
    /// Battery %. Only useful with chargeable models
    func onGetElectric(_ electric: UInt, device: QNBleDevice!) {
        logger.debug("QNScale Received battery: \(electric)% from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
    }
    
    /// Connection & measurement state change of this specific device (cf. `QNBleConnectionChangeListener`)
    func onScaleStateChange(_ device: QNBleDevice!, scaleState state: QNScaleState) {
        // Should be useless for now.
        // There are some other interesting states one may check out
        switch state {
        case .wiFiBleStartNetwork:
            logger.debug("QNScale state \(state.rawValue) wiFiBleStartNetwork from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
            break
        case .wiFiBleNetworkFail:
            logger.debug("QNScale state \(state.rawValue) wiFiBleNetworkFail from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
            break
        case .wiFiBleNetworkSuccess:
            logger.debug("QNScale state \(state.rawValue) wiFiBleNetworkSuccess from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
            break
        case .measureCompleted:
            logger.debug("QNScale state \(state.rawValue) measureCompleted from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
            break
        case .connecting:
            logger.debug("QNScale state \(state.rawValue) connecting from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
        case .bodyFat:
            logger.debug("QNScale state \(state.rawValue) detecting bodyfat from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
        default:
            logger.debug("QNScale state \(state.rawValue) (unhandled) from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
            break
        }
    }
    
    /// Scale events 例如WiFi蓝牙双模设备开始配网，用户秤注册用户成功
    func onScaleEventChange(_ device: QNBleDevice!, scaleEvent: QNScaleEvent) {
        logger.debug("QNScale event \(scaleEvent.rawValue) (unhandled) from \(device.mac == self.selectedDevice?.mac ? "current" : device.mac)")
    }
}

// 我专门定义了一个额外的类作为QNBleDevice的替代
// 原因是Swift好像不允许我直接为QNBleDevice创建extension来conform to other protocols
// 不知道为什么，或许和QNBleDevice是Objective-C class而非Swift class有关？
struct QNDeviceInfo {
    var mac: String
    var name: String
    var bluetoothName: String
    var hasWifi: Bool
    var hasEightElectrodes: Bool
        
    init(mac: String, name: String, bluetoothName: String, hasWifi: Bool, hasEightElectrodes: Bool) {
        self.mac = mac
        self.name = name
        self.bluetoothName = bluetoothName
        self.hasWifi = hasWifi
        self.hasEightElectrodes = hasEightElectrodes
    }
    
    init(_ device: QNBleDevice) {
        self.init(
            mac: device.mac,
            name: device.name,
            bluetoothName: device.bluetoothName,
            hasWifi: device.isSupportWifi,
            hasEightElectrodes: device.isSupportEightElectrodes
        )
    }
}

extension QNDeviceInfo: RawRepresentable {
    public typealias RawValue = String
    
    public init?(rawValue: RawValue) {
        guard
            let data = rawValue.data(using: .utf8),
            let device = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = device
    }
    
    public var rawValue: RawValue{
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data:data,encoding: .utf8) else {
            return ""
        }
        return result
    }
}

extension QNDeviceInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case mac, name, bluetoothName, hasWifi, hasEightElectrodes
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mac = try c.decode(String.self, forKey: .mac)
        name = try c.decode(String.self, forKey: .name)
        bluetoothName = try c.decode(String.self, forKey: .bluetoothName)
        hasWifi = try c.decode(Bool.self, forKey: .hasWifi)
        hasEightElectrodes = try c.decode(Bool.self, forKey: .hasEightElectrodes)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mac, forKey: .mac)
        try c.encode(name, forKey: .name)
        try c.encode(bluetoothName, forKey: .bluetoothName)
        try c.encode(hasWifi, forKey: .hasWifi)
        try c.encode(hasEightElectrodes, forKey: .hasEightElectrodes)
    }
}


//// 扩展 QNScaleModel 添加日志监听功能
//extension QNScaleModel: QNLogListener {
//    
//    /// 实现 SDK 的日志监听方法
//    func onLog(_ log: String) {
//        // 输出日志到控制台
//        logger.debug("SDK Log: \(log)")
//        
//        // 保存日志到本地文件
//        saveLogToFile(log)
//    }
//    
//    /// 将日志保存到本地文件
//    private func saveLogToFile(_ log: String) {
//        let fileManager = FileManager.default
//        let logsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let logFileURL = logsDirectory.appendingPathComponent("sdk_logs.txt")
//        
//        // 尝试追加日志到文件
//        do {
//            if fileManager.fileExists(atPath: logFileURL.path) {
//                // 文件存在，追加日志
//                let fileHandle = try FileHandle(forWritingTo: logFileURL)
//                fileHandle.seekToEndOfFile()
//                if let data = (log + "\n").data(using: .utf8) {
//                    fileHandle.write(data)
//                }
//                fileHandle.closeFile()
//            } else {
//                // 文件不存在，创建新文件并写入日志
//                try log.write(to: logFileURL, atomically: true, encoding: .utf8)
//            }
//        } catch {
//            logger.error("Failed to save log to file: \(error.localizedDescription)")
//        }
//    }
//}
//
//// 在初始化 SDK 时设置日志监听器
//extension QNScaleModel {
//    func initializeLogListener() {
//        qnBleApi.setLogListener(self)
//        logger.debug("Log listener has been set.")
//    }
//}
