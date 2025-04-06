//
//  WelcomeView.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 5/4/2024.
//

import SwiftUI

struct WelcomeScreen: View {
    @State var isStartingSession: Bool = false
    @State var showAlert: Bool = false
    @State var alertMessage: String?
    
    @State var showParticipantIDAlert: Bool = false
    @State var participantID: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Athlete Daily Monitoring Booth")
                    .font(.custom(
                            "Lexend",
                            size: 50,
                            relativeTo: .title
                        ))
                Spacer()
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                }
            }
            Spacer(minLength: 40)
            // GeometryReader takes up as much space as possible from its parent
            // and provide its own size to children so that
            // they can use its for complex layouts
            GeometryReader { geometry in
                let gap = 0.07 * geometry.size.height
                let wideViewWidth = (geometry.size.width + gap) / 6 * 4  - gap
                let wideViewHeight = (geometry.size.height + gap) / 5 * 2  - gap
                let smallViewWidth = (geometry.size.width + gap) / 6 * 2  - gap
                let smallViewHeight = (geometry.size.height + gap) / 5 * 3  - gap
                let buttonWidth = (geometry.size.width + gap) / 6 * 2  - 0.5 * gap
                let buttonHeight = (geometry.size.height + gap) / 5 * 1  - 0.5 * gap
                ZStack {
                    HStack {
                        FeatureIcon(feature: .hr, variant: .noBorder)
                            .frame(width: 120, height: 120)
                        Spacer().frame(width: 30)
                        Text(FeatureType.hr.title)
                    }
                    .frame(width: wideViewWidth, height: wideViewHeight)
                    .background(FeatureType.hr.lightColor)
                    .cornerRadius(50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    
                    VStack {
                        FeatureIcon(feature: .mood, variant: .noBorder)
                            .frame(width: 120, height: 120)
                        Text(FeatureType.mood.title)
                    }
                    .frame(width: smallViewWidth, height: smallViewHeight)
                    .background(FeatureType.mood.lightColor)
                    .cornerRadius(50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    
                    VStack {
                        FeatureIcon(feature: .body, variant: .noBorder)
                            .frame(width: 120, height: 120)
                        Text(FeatureType.body.title)
                    }
                    .frame(width: smallViewWidth, height: smallViewHeight)
                    .background(FeatureType.body.lightColor)
                    .cornerRadius(50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    
                    HStack {
                        FeatureIcon(feature: .skin, variant: .noBorder)
                            .frame(width: 120, height: 120)
                        Spacer().frame(width: 30)
                        Text(FeatureType.skin.title)
                    }
                    .frame(width: wideViewWidth, height: wideViewHeight)
                    .background(FeatureType.skin.lightColor)
                    .cornerRadius(50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    
                    StartButton(
                        loading: $isStartingSession,
                        hasError: $showAlert,
                        showParticipantIDAlert: $showParticipantIDAlert,
                        participantID: $participantID,
                        errorMessage: $alertMessage
                    )
                    .frame(width: buttonWidth, height: buttonHeight)
                    
                }
                    .font(.system(size: 50))
            }

            BottomStatusIndicator()
        }
        .padding(.horizontal, 50.0)
        .padding(.top, 20.0)
        .alert("Fail to start", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage ?? "unknown error")
        }
    }
}

fileprivate struct StartButton: View {
        @Environment(CameraModel.self) var cameraModel: CameraModel
        @Environment(RouteModel.self) var routeModel: RouteModel
        @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel
        @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel

        @Binding var loading: Bool
        @Binding var hasError: Bool

        @Binding var showParticipantIDAlert: Bool
        @Binding var participantID: String


        @Binding var errorMessage: String? {
            didSet {
                hasError = errorMessage != nil
                logger.error("Error when starting session: \(String(describing: errorMessage))")
            }
        }

        var body: some View {
            Button(action: {
                showParticipantIDAlert = true

                // 在弹出输入框时就预先连接
                if webRTCModel.signalingServer != "" {
                    Task {
                        do {
                            try await webRTCModel.connect()
                            logger.debug("Pre-connected to WebRTC server")
                        } catch {
                            logger.error("WebRTC pre-connection failed: \(error)")
                            errorMessage = "WebRTC connection failed"
                        }
                        await startSession()
                    }
                }
            }) {
                if loading {
                    ProgressView()
                } else {
                    Text("Start")
                        .padding()
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isDisabled ? Color.gray : Color.navy)
                        .cornerRadius(50)
                }
            }
            .disabled(isDisabled || loading)
            .alert("Please enter Participant ID", isPresented: $showParticipantIDAlert) {
                TextField("Enter ID", text: $participantID)
                Button("Cancel", role: .cancel) {
//                    logger.debug("User canceled input. Disconnecting WebRTC.")
//                    webRTCModel.disconnect()
                }
                Button("Confirm") {
                    if !participantID.isEmpty {
                        logger.debug("Participant ID type: \(type(of: participantID)) | Value: \(participantID)")
                        Task {
//                            try await webRTCModel.connect()
//                            await startSession()
//                            participantID = ""  // 确保 session 启动后再清空
                        }
                    }
                }.disabled(participantID.isEmpty)
            }
            .onDisappear {
                // 当 alert 关闭时清空 participantID
                participantID = ""
            }
        }

        var isDisabled: Bool {
            cameraModel.selectedCaptureDevice == nil && !isInPreview()
        }

        private func startSession() {
            loading = true
            
            guard webRTCModel.signalingServer != "" else {
                errorMessage = "Missing server URL configuration"
                return
            }
            
            Task { @MainActor in
                do {
                    defer {
                        loading = false
                    }
                    
//                    try await webRTCModel.connect()
//                    logger.debug("WebRTC connected: \(webRTCModel.isConnected)")
                    
                    // TODO: make it parallel to await webRTCModel.connect()
                    do {
                        try await qnScaleModel.waitForSelectedDevice()
                    } catch {
                        logger.warning("Error connecting to scale device: \(error)")
                    }
                    
//                    try await webRTCModel.connect()    // 尝试改变一下首次建立connect的地方
          
                    // send to backend
                    webRTCModel.sendParticipantID(stringID: participantID)
                    logger.debug("Already sent Participant ID to backend")
                    
                    cameraModel.shouldDetectFace = true
                    routeModel.push(.historyresult)
//                    routeModel.push(.questionnaire)
//                    routeModel.paths.append(.scanning)
                } catch {
                    errorMessage = "Error starting a user session: \(error)"
                }
            }
        }
    }


fileprivate struct BottomStatusIndicator: View {
    @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel
    @Environment(CameraModel.self) var cameraModel: CameraModel
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel

    var body: some View {
        HStack {
            //            switch webRTCModel.connected {
            //            case false:
            //                BottomStatusIndicator.message("Cloud prediction models: not connected", .error)
            //            case true:
            //                BottomStatusIndicator.message("Cloud prediction models: connected", .success)
            //            }
            
            /// Camera status indicator
            switch cameraModel.selectedCaptureDevice {
            case nil:
                BottomStatusIndicator.message("Camera: not specified", .error)
            default:
                BottomStatusIndicator.message("Camera: specified (\(cameraModel.selectedCaptureDevice!.localizedName))", .success)
            }
            
            /// QNScale status indicator
            if !qnScaleModel.hasBluetoothPermission {
                BottomStatusIndicator.message("Scale: no BLE permission", .error)
            } else {
                switch qnScaleModel.sdkStatus {
                case .unloaded:
                    BottomStatusIndicator.message("Scale: unloaded", .warning)
                case .loading:
                    BottomStatusIndicator.message("Scale: loading", .warning)
                case .ready:
                    qnScaleModel.selectedDevice == nil
                    ? BottomStatusIndicator.message("Scale: device not specified", .warning)
                    : BottomStatusIndicator.message("Scale: waiting for connection of \(qnScaleModel.selectedDevice!.mac)", .success)
                case .error:
                    BottomStatusIndicator.message("Scale: error \(String(describing: qnScaleModel.sdkError))", .warning)
                @unknown default:
                    BottomStatusIndicator.message("Scale: unknown state \(qnScaleModel.sdkStatus)", .warning)
                }
            }
            
            /// Network (WebRTC) status indicator
            if webRTCModel.signalingServer == "" {
                BottomStatusIndicator.message("WebRTC: server URL not configured", .error)
            } else {
                BottomStatusIndicator.message("WebRTC: \(webRTCModel.signalingServer)", .success)
            }
        }
    }
    
    private static func message(_ text: String, _ type: MessageType) -> some View {
        let icon = switch type {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .error:
            Image(systemName: "x.circle.fill")
                .foregroundStyle(.red)
        case .loading:
            Image(systemName: "hourglass")
                .foregroundStyle(.gray)
        }
        
        return Label {
            Text(text)
                .foregroundStyle(.secondary)
        } icon: {
            icon
        }
    }
    
    private enum MessageType {
        case success, warning, error, loading
    }
}

#Preview {
    WelcomeScreen()
        .environment(QNScaleModel())
        .environment(CameraModel())
}
