//
//  WelcomeView.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 5/4/2024.
//

import SwiftUI

struct WelcomeScreen: View {
    @State var showAlert: Bool = false
    @State var alertMessage: String?

    @State var participantID: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Athlete Daily Monitoring Booth")
                    .font(
                        .custom(
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
                let wideViewWidth = (geometry.size.width + gap) / 6 * 4 - gap
                let wideViewHeight = (geometry.size.height + gap) / 5 * 2 - gap
                let smallViewWidth = (geometry.size.width + gap) / 6 * 2 - gap
                let smallViewHeight = (geometry.size.height + gap) / 5 * 3 - gap
                let buttonWidth = (geometry.size.width + gap) / 6 * 2 - 0.5 * gap
                let buttonHeight = (geometry.size.height + gap) / 5 * 1 - 0.5 * gap
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
                        hasError: $showAlert,
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

private struct StartButton: View {
    @Environment(CameraModel.self) var cameraModel: CameraModel
    @Environment(RouteModel.self) var routeModel: RouteModel
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel
    @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel

    private enum StartingState: Int {
        case initial = 0
        case
            requestingID,
            connecting,
            connected
    }

    @State private var state: StartingState = .initial

    @Binding var hasError: Bool

    @Binding var participantID: String
    @FocusState private var focusParticipantIDTextField: Bool

    @Binding var errorMessage: String? {
        didSet {
            hasError = errorMessage != nil && errorMessage != ""
            logger.error("Error when starting session: \(String(describing: errorMessage))")
        }
    }

    var body: some View {
        switch self.state {
        case .initial:
            Button {
                /// Check configurations are properly set
                if webRTCModel.signalingServer == "" {
                    errorMessage = "WebRTC signaling server URL"
                } else if cameraModel.selectedCaptureDevice == nil {
                    errorMessage = "camera device"
                } else if qnScaleModel.selectedDevice == nil {
                    errorMessage = "scale device"
                } else {
                    self.state = .requestingID
                    self.focusParticipantIDTextField = true
                    logger.debug("WelcomeScreen: Proceeding to requesting participant ID")
                }
            } label: {
                Text("Start")
                    .padding()
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isDisabled ? Color.gray : Color.navy)
                    .cornerRadius(50)
            }.disabled(isDisabled || (self.state != .initial))
        case .requestingID:
            VStack {
                Text("Enter participant ID")
                    .fontWeight(.bold)
                
                TextField("Enter ID", text: $participantID)
                    .focused($focusParticipantIDTextField)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                
                HStack(spacing: 10) {
                    Button(role: .cancel) {
                        self.focusParticipantIDTextField = false
                        self.state = .initial
                        self.participantID = ""
                        logger.debug("WelcomeScreen: Back to initial state")
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await startSession()
                        }
                        logger.debug("WelcomeScreen: Proceeding to connecting stuff")
                    } label: {
                        Label("OK", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.navy)
                    .foregroundColor(.white)
                    .disabled(participantID.isEmpty)
                }
            }
            .padding()
            .font(.system(size: 36))
            .background(.white)
        case .connecting:
            ProgressView()
        case .connected:
            Label("Launching...", systemImage: "figure.run")
                .padding()
                .fontWeight(.bold)
                .foregroundColor(.black)
        }
    }

    var isDisabled: Bool {
        !isInPreview()
            && (cameraModel.selectedCaptureDevice == nil || qnScaleModel.selectedDevice == nil
                || webRTCModel.signalingServer == "")
    }

    private func startSession() async {
        self.state = .connecting

        do {
            /// Uncomment either one of the `scaleConnectionTask`.
            /// The first (shorter) one will let the system abort when no scale is found.
            /// The second (longer) one will persist initializing a session.
//            async let scaleConnectionTask: Void = qnScaleModel.waitForSelectedDevice()
            async let scaleConnectionTask: Void = Task {
                do {
                    return try await qnScaleModel.waitForSelectedDevice()
                } catch {
                    logger.warning("Error connecting to scale: \(error). Skipping this error and still initiating a session...")
                }
            }.value
            
            async let webRTCConnectionTask: Void = webRTCModel.connect()
            
            _ = try await (webRTCConnectionTask, scaleConnectionTask)
        } catch {
            switch error {
            case is QNError:
                errorMessage = "Error connecting to scale: \(error)"
            case is WebRTCError:
                errorMessage = "Error connecting to WebRTC: \(error)"
            default:
                errorMessage = "Error connecting to either scale or WebRTC: \(error)"
            }
            webRTCModel.disconnect()
            self.state = .requestingID
            return
        }
        logger.debug("WelcomeScreen: Done connecting to both WebRTC and scale")

        webRTCModel.sendParticipantID(stringID: participantID)
        logger.debug("WelcomeScreen: Sending participant ID via WebRTC (cannot capture message arrival)")

        cameraModel.shouldDetectFace = true

        self.state = .connected
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            routeModel.paths.append(.scanning)
            self.state = .initial
        }
        logger.debug("WelcomeScreen: All done. Redirecting in 1 second")
    }
}

private struct BottomStatusIndicator: View {
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
                BottomStatusIndicator.message(
                    "Camera: specified (\(cameraModel.selectedCaptureDevice!.localizedName))",
                    .success)
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
                        : BottomStatusIndicator.message(
                            "Scale: waiting for connection of \(qnScaleModel.selectedDevice!.mac)",
                            .success)
                case .error:
                    BottomStatusIndicator.message(
                        "Scale: error \(String(describing: qnScaleModel.sdkError))", .warning)
                @unknown default:
                    BottomStatusIndicator.message(
                        "Scale: unknown state \(qnScaleModel.sdkStatus)", .warning)
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
        let icon =
            switch type {
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
