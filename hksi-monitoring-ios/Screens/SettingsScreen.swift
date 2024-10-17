//
//  SettingsView.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 12/4/2024.
//

import SwiftUI
import AVFoundation

fileprivate enum SettingsItem: String, CaseIterable {
    case webRTC = "WebRTC Server"
    case camera = "Camera Device"
    case scale = "Scale Device"
}

struct SettingsScreen: View {
    @State private var selectedSetting: SettingsItem? = .webRTC
    
    var body: some View {
        NavigationSplitView {
            List(SettingsItem.allCases, id: \.self, selection: $selectedSetting) { selection in
                NavigationLink(selection.rawValue, value: selection)
            }
            .navigationTitle("Settings")
//            .navigationDestination(for: SettingsItem.self) { setting in
//                switch setting {
//                    case .camera: CameraSettings()
//                    case .scale: ScaleSettings()
//                }
//            }
        } detail: {
            switch selectedSetting {
            case .camera: CameraSettings()
            case .scale: ScaleSettings()
            case .webRTC: WebRTCSettings()
            case .none: Text("Please select a settings item")
            }
        }
//        .navigationTitle("Settings") // This is for outer navigation
    }
}

struct CameraSettings: View {
    @Environment(CameraModel.self) var cameraModel: CameraModel
    
    var body: some View {
        @Bindable var cameraModel = cameraModel
        VStack {
            CameraView()
                .containerRelativeFrame(.horizontal, alignment: .center) { length, _ in
                    return min(length * 0.8, 500)
                }
                .clipped()

            List {
                Picker("Camera Device", selection: $cameraModel.selectedCaptureDevice) {
                    Text("(Not selected)").tag(nil as AVCaptureDevice?)
                    ForEach(cameraModel.availableCaptureDevices) { device in
                        Text(device.localizedName)
                            .tag(device as AVCaptureDevice?)
                    }
                }
                
                /// This feature is not implemented
                /// selectedFormat and availableFormats are not properly set
//                Picker("Camera Format", selection: $cameraModel.selectedFormat) {
//                    Text("(Not selected)").tag(nil as AVCaptureDevice.Format?)
//                    ForEach(cameraModel.availableFormats, id:\.hash) { format in
//                        Text(format.supportedMaxPhotoDimensions.description)
//                            .tag(format as AVCaptureDevice.Format?)
//                    }
//                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear {
            cameraModel.shouldDetectFace = false
        }
    }
}

struct ScaleSettings: View {
    @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel
    
    @State private var alertError: (any Error)? = nil
    @State private var showAlert = false

    var body: some View {
        List {
//            Section {
//                ForEach(qnScaleModel
//                    .connectedDevices
//                    .sorted(
//                        by: {a, b in a.value.rssi!.compare(b.value.rssi!) == .orderedAscending}),
//                        id: \.self.key
//                ) { mac, device in
//                    ScaleDeviceButtonLabel(qnDevice: device)
//                }
//            } header: {
//                Text("Connected Device")
//            }
            
            Section {
                let savedScale = qnScaleModel.selectedDevice
                if savedScale != nil {
                    ScaleDeviceButtonLabel(qnDevice: savedScale!)
                } else {
                    Text("No selected scale device")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Selected Device")
            }
            
            Section {
                ForEach(qnScaleModel
                    .scannedDevices
                    .sorted(
                        by: {a, b in a.value.device.rssi!.compare(b.value.device.rssi!) == .orderedAscending}),
                    id: \.self.key
                ) { mac, deviceAndState in
                    let device = deviceAndState.device
                    let isConnecting = deviceAndState.state == .connecting
                    Button {
                        Task {
                            do {
                                /// Actually we don't need to connect... But anyway
                                try await qnScaleModel.connectDevice(device)
                                /// Disconnect to prevent receiving useless unsteady weight. Ignore errors (`try?`).
                                try? await qnScaleModel.disconnectDevice(device)
                            } catch {
                                alertError = error
                                showAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            ScaleDeviceButtonLabel(qnDevice: QNDeviceInfo(device))
                            if (isConnecting) {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isConnecting)
                }

                if qnScaleModel.isScanning {
                    Button("Stop scanning", role: .destructive) {
                        Task {
                            do {
                                try await qnScaleModel.stopScanning()
                            } catch {
                                alertError = error
                                showAlert = true
                            }
                        }
                    }
                } else {
                    Button("Start scanning") {
                        Task {
                            do {
                                try await qnScaleModel.startScanning()
                            } catch {
                                alertError = error
                                showAlert = true
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Scanned Devices")
                    if qnScaleModel.isScanning {
                        ProgressView()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(String(describing: alertError))
        }
    }
}

struct WebRTCSettings: View {
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel

    var body: some View {
        /// Silly apple again
        /// I cannot directly do `TextField("...", text: $webRTCModel.serverURL)`
        @Bindable var webRTCModel = webRTCModel

        List {
            Section {
                LabeledContent {
                    TextField("Server URL", text: $webRTCModel.signalingServer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .onSubmit {
                            webRTCModel.signalingServer = webRTCModel.signalingServer.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                } label: {
                    Text("Server URL")
                }
            } header: {
                Text("WebRTC Server Configuration")
            }
        }
    }
}

struct ScaleSettings_Previews: PreviewProvider {
    static var previews: some View {
//        let d = UserDefaults(suiteName: "preview_user_defaults")!
//        let _ = d.set(
//            QNDeviceInfo(mac: "66:66:66:66:66:66",
//                         name: "Name",
//                         bluetoothName: "Bluetooth-Name",
//                         hasWifi: true,
//                         hasEightElectrodes: true),
//            forKey: "scale")
//        
        SettingsScreen()
            .environment(QNScaleModel())
            .environment(CameraModel())
    }
}
