//
//  WebRTCModel.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 28/7/2024.
//  Part of this file and every file inside the `WebRTC` subfolder
//  Are taken from https://github.com/tkmn0/SimpleWebRTCExample_iOS/ (MIT licensed)

import Foundation
import SwiftUI
import WebRTC

@Observable
class WebRTCModel {
    var iceConnectionState: RTCIceConnectionState?
    var connected = false
    
    /// The prediction results. nil = no value yet. non-nil object with nil fields = some models have indetermined values.
    var intermediateValue: FramePrediction?
    var finalValue: FramePrediction? {
        didSet {
            logger.debug("WebRTC have set finalValue")
            if onSessionEnd != nil {
                onSessionEnd!()
            }
            disconnect()
        }
    }
    
    /// Server URL as a user preference
    @ObservationIgnored
    @AppStorage("WebRTC Server")
    var _signalingServer: String = ""
    var signalingServer: String {
        get {
            access(keyPath: \.signalingServer)
            return _signalingServer
        }
        set {
            withMutation(keyPath: \.signalingServer) {
                _signalingServer = newValue
            }
        }
    }
    
    @ObservationIgnored
    var onSessionEnd: (() -> Void)?
    
    @ObservationIgnored
    var shouldSendFrame = true
    
    @ObservationIgnored
    private var useCustomCapturer: Bool
    
    @ObservationIgnored
    private var webRTCClient: WebRTCClient!
    
    init(videoTrack: Bool = true, audioTrack: Bool = false, dataChannel: Bool = true, useCustomCapturer customCapturer: Bool = true) {
        
        /// Initialize capturing device
#if targetEnvironment(simulator)
        // simulator does not have camera
        self.useCustomCapturer = false
#else
        self.useCustomCapturer = customCapturer
#endif

        /// Initializing WebRTC connection
        webRTCClient = WebRTCClient()
        webRTCClient.delegate = self
        webRTCClient.setup(videoTrack: videoTrack, audioTrack: audioTrack, dataChannel: dataChannel, customFrameCapturer: self.useCustomCapturer)
        
        if self.useCustomCapturer {
            logger.debug("--- use custom capturer ---")
//            self.cameraSession = CameraSession()
//            self.cameraSession?.delegate = self
//            self.cameraSession?.setupSession()
//            
//            self.cameraFilter = CameraFilter()
        }
    }
    
    func didOutput(_ sampleBuffer: CMSampleBuffer) {
        if !shouldSendFrame { return }
        if useCustomCapturer {
            self.webRTCClient.captureCurrentFrame(sampleBuffer: sampleBuffer)
        }
    }
    
    func didOutput(_ buffer: CVPixelBuffer) {
        if !shouldSendFrame { return }
        if useCustomCapturer {
            self.webRTCClient.captureCurrentFrame(sampleBuffer: buffer)
        }
    }
    
    func connect() async throws {
        guard !webRTCClient.isConnected else { return }
        webRTCClient.signalingServer = URL(string: signalingServer.trimmingCharacters(in: .whitespacesAndNewlines))
        try await webRTCClient.connect()
    }
    
    func disconnect() {
        guard webRTCClient.isConnected else { return }
        logger.debug("WebRTC disconnecting...")
        webRTCClient.disconnect()
    }
    
    func endSession(onEnd: (() -> Void)?) {
        /// Set the handler when receiving the final prediction message
        self.onSessionEnd = onEnd
        
        /// Request the final prediction from the server
        webRTCClient.sendMessge(message: "end session")
        
        /// Clear the states, so that the next person won't see the 
        logger.debug("WebRTC sending end session message")
    }
    
//    private func sendCandidate(iceCandidate: RTCIceCandidate){
//        let candidate = Candidate.init(sdp: iceCandidate.sdp, sdpMLineIndex: iceCandidate.sdpMLineIndex, sdpMid: iceCandidate.sdpMid!)
//        let signalingMessage = SignalingMessage.init(type: "candidate", sessionDescription: nil, candidate: candidate)
//        do {
//            let data = try JSONEncoder().encode(signalingMessage)
//            let message = String(data: data, encoding: String.Encoding.utf8)!
//            
//            if self.socket.isConnected {
//                self.socket.write(string: message)
//            }
//        }catch{
//            logger.error(error)
//        }
//    }
}

extension WebRTCModel: WebRTCClientDelegate {
    func didGenerateCandidate(iceCandidate: RTCIceCandidate) {
//        logger.debug("New ICE candidate generated: \(iceCandidate.sdpMid ?? "unknown media stream ID")")
//        self.sendCandidate(iceCandidate: iceCandidate)
    }
    
    func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState) {
        self.iceConnectionState = iceConnectionState
    }
    
    func didConnectWebRTC() {
        connected = true
    }
    
    func didDisconnectWebRTC() {
        logger.debug("WebRTC disconnected")
        self.connected = false
    }
    
    func didOpenDataChannel() {
        logger.debug("WebRTC opened data channel")
    }
    
    func didReceiveData(data: Data) {
        logger.debug("WebRTC received binary data from data channel \(data.count)B")
    }
    
    func didReceiveMessage(message: String) {
        /// Decode
        var data: FramePrediction!
        do {
            data = try JSONDecoder().decode(FramePrediction.self, from: message.data(using: .utf8)!)
            logger.debug("WebRTC receive message \(message)")
        } catch {
            logger.warning("Cannot parse WebRTC data message \(message). \(error)")
            return
        }
        
        /// Update data
        if data.final {
            if finalValue != nil {
                data.updateNilWith(other: finalValue!)
            }
            finalValue = data
        } else {
            if intermediateValue != nil {
                data.updateNilWith(other: intermediateValue!)
            }
            intermediateValue = data
        }
    }
}

extension RTCIceConnectionState {
    /// https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/iceConnectionState
    public var description: String {
        return switch self {
        case .new: "new..."
        case .checking: "checking..."
        case .connected: "connected"
        case .completed: "completed"
        case .failed: "failed"
        case .disconnected: "disconnected"
        case .closed: "closed"
        case .count: "count..."
        @unknown default: "???"
        }
    }
}

enum WebRTCConnectionState {
    case disconnected, connecting, connected, inSession
}
