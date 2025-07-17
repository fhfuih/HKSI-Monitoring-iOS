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
    var connectionState: RTCPeerConnectionState?
    var connected = false
    
    var person_id: String?
    var participant_id: String?
    
    /// The prediction results. nil = no value yet. non-nil object with nil fields = some models have indetermined values.
    var intermediateValue: FramePrediction?
    var finalValue: FramePrediction? {
        didSet {
            logger.debug("WebRTC have set finalValue")
            if onSessionEnd != nil {
                onSessionEnd!()
            }
//            disconnect()
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
    
    init(audioTrack: Bool = false) {
        
        /// Initialize capturing device
#if targetEnvironment(simulator)
        // simulator does not have camera
        self.useCustomCapturer = false
#else
        self.useCustomCapturer = true
#endif

        /// Initializing WebRTC connection
        webRTCClient = WebRTCClient()
        webRTCClient.delegate = self
        webRTCClient.setup(audioTrack: audioTrack)
        
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
        guard let signalingServerURL = URL(string: signalingServer.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw WebRTCError.malformedSignalingServerURL
        }
        try await webRTCClient.connect(signalingServerURL)
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
        
        webRTCClient.stopSendingVideoTrack()
        logger.debug("Stop getting frames from the camera & Video track no longer transmits data")
        
    }
    
    func sendWeightData(weightData: Double?) {
        var weightDataDict: [String: Double?] = [:]
        
        weightDataDict["Weight"] = weightData
        
//        guard let participantID = finalValue?.person_id else {
//            logger.error("Participant ID is missing, can not record weight data to DB")
//            return
//        }
        guard let participantID = finalValue?.participant_id else {
            logger.error("Participant ID is missing, can not record weight data to DB")
            return
        }
        let personID = finalValue?.person_id
        
        // 构造包含 participantID 和 surveyResult 的新字典
        let payload: [String: Any] = [
            "ParticipantID": participantID,
            "PersonID": personID,
            "weightDataDict": weightDataDict
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                webRTCClient.sendMessge(message: jsonString)
                logger.debug("Successfully sent weight Data: \(jsonString)")
            }
        } catch {
            logger.error("Failed to submit weight data: \(error.localizedDescription)")
        }
        
//        // 执行数据发送
//        do {
//            let jsonData = try JSONEncoder().encode(payload)
//            if let jsonString = String(data: jsonData, encoding: .utf8) {
//                webRTCClient.sendMessge(message: jsonString)
//                logger.debug("Successfully sent weight Data: \(jsonString)")
//            }
//        } catch {
//            logger.error("Failed to submit weight data")
//        }
    }
    
    func sendBodyData(weightData: Double?, bodyfatData: Double?) {
        var bodyDataDict: [String: Double?] = [:]
        
        bodyDataDict["Weight"] = weightData
        bodyDataDict["Body Fat"] = bodyfatData
        
//        guard let participantID = finalValue?.person_id else {
//            logger.error("Participant ID is missing, can not record weight data to DB")
//            return
//        }
        guard let participantID = finalValue?.participant_id else {
            logger.error("Participant ID is missing, can not record weight data to DB")
            return
        }
        let personID = finalValue?.person_id
        
        // 构造包含 participantID 和 surveyResult 的新字典
        let payload: [String: Any] = [
            "ParticipantID": participantID,
            "PersonID": personID,
            "bodyDataDict": bodyDataDict
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                webRTCClient.sendMessge(message: jsonString)
                logger.debug("Successfully sent body Data: \(jsonString)")
            }
        } catch {
            logger.error("Failed to submit body data: \(error.localizedDescription)")
        }
        
//        // 执行数据发送
//        do {
//            let jsonData = try JSONEncoder().encode(bodyDataDict)
//            if let jsonString = String(data: jsonData, encoding: .utf8) {
//                webRTCClient.sendMessge(message: jsonString)
//                logger.debug("Successfully sent Body Data: \(jsonString)")
//            }
//        } catch {
//            logger.error("Failed to submit body data")
//        }
    }
    
//    func sendParticipantID(stringID: String) {
//        webRTCClient.sendMessge(message: stringID)
//        logger.debug("Successfully sent Participant ID: \(stringID)")
//    }
    func sendParticipantID(stringID: String) {
        let messageDict = ["ParticipantID": stringID]
        if let jsonData = try? JSONSerialization.data(withJSONObject: messageDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webRTCClient.sendMessge(message: jsonString)
            logger.debug("Successfully sent Participant ID: \(jsonString)")
        } else {
            logger.error("Failed to encode Participant ID as JSON")
        }
    }
    
    func sendSurveyData(surveyResult: [String: Int]) {
//        guard let participantID = finalValue?.person_id else {
//            logger.error("Participant ID is missing, can not record data to DB")
//            return
//        }
        guard let participantID = finalValue?.participant_id else {
            logger.error("Participant ID is missing, can not record data to DB")
            return
        }
        let personID = finalValue?.person_id
        
        // 构造包含 participantID 和 surveyResult 的新字典
        let payload: [String: Any] = [
            "ParticipantID": participantID,
            "PersonID": personID,
            "surveyResult": surveyResult
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                webRTCClient.sendMessge(message: jsonString)
                logger.debug("Successfully sent Survey Data: \(jsonString)")
            }
        } catch {
            logger.error("Failed to submit survey data: \(error.localizedDescription)")
        }
        
//        // 执行数据发送
//        do {
//            let jsonData = try JSONEncoder().encode(surveyResult)
//            if let jsonString = String(data: jsonData, encoding: .utf8) {
//                webRTCClient.sendMessge(message: jsonString)
//                logger.debug("Successfully sent Survey Data: \(jsonString)")
//            }
//        } catch {
//            logger.error("Failed to submit survey data")
//        }
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
    
    func didChangeConnectionState(connectionState: RTCPeerConnectionState) {
        self.connectionState = connectionState
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
            logger.debug("Currently, it is data.final")
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

enum WebRTCConnectionState {
    case disconnected, connecting, connected, inSession
}
