//
//  WebRTCClient.swift
//  SimpleWebRTC
//
//  Created by n0 on 2019/01/06.
//  Copyright © 2019年 n0. All rights reserved.
//

import UIKit
import WebRTC

fileprivate let webRTCOfferConstraints = [
    kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueFalse,
    kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue,
]

protocol WebRTCClientDelegate {
    func didGenerateCandidate(iceCandidate: RTCIceCandidate)
    func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState)
    func didOpenDataChannel()
    func didReceiveData(data: Data)
    func didReceiveMessage(message: String)
    func didConnectWebRTC()
    func didDisconnectWebRTC()
}

class WebRTCClient: NSObject {
    public var signalingServer: URL?
    
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var videoCapturer: RTCVideoCapturer!
    private var localVideoTrack: RTCVideoTrack!
    private var localAudioTrack: RTCAudioTrack!
//    private var localRenderView: RTCEAGLVideoView?
//    private var localView: UIView!
//    private var remoteRenderView: RTCEAGLVideoView?
//    private var remoteView: UIView!
    private var remoteStream: RTCMediaStream?
    private var dataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    private var channels: (video: Bool, audio: Bool, datachannel: Bool) = (false, false, false)
    private var customFrameCapturer: Bool = false
    private var cameraDevicePosition: AVCaptureDevice.Position = .front
    
    var delegate: WebRTCClientDelegate?
    public private(set) var isConnected: Bool = false
    
//    func localVideoView() -> UIView {
//        return localView
//    }
//    
//    func remoteVideoView() -> UIView {
//        return remoteView
//    }
    
    override init() {
        super.init()
        logger.debug("WebRTC Client initialize")
    }
    
    deinit {
        logger.debug("WebRTC Client Deinit")
        self.peerConnectionFactory = nil
        self.peerConnection = nil
    }
    
    // MARK: Lifecycle routines
    func setup(videoTrack: Bool, audioTrack: Bool, dataChannel: Bool, customFrameCapturer: Bool){
        self.channels.video = videoTrack
        self.channels.audio = audioTrack
        self.channels.datachannel = dataChannel
        self.customFrameCapturer = customFrameCapturer
        
        var videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        var videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        
        if TARGET_OS_SIMULATOR != 0 {
            logger.debug("setup simulator codec")
            videoEncoderFactory = RTCSimluatorVideoEncoderFactory()
            videoDecoderFactory = RTCSimulatorVideoDecoderFactory()
        }
        self.peerConnectionFactory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        
//        setupView()
        setupLocalTracks()
        
        if self.channels.video {
            startCaptureLocalVideoIfNotCustom(cameraPositon: self.cameraDevicePosition, videoWidth: 640, videoHeight: 640*16/9, videoFps: 30)
//            self.localVideoTrack?.add(self.localRenderView!)
        }
    }
    
    func connect() async throws {
        self.peerConnection = setupPeerConnection()
        self.peerConnection!.delegate = self
        
        if self.channels.video {
            self.peerConnection!.add(localVideoTrack, streamIds: ["video0"])
        }
        if self.channels.audio {
            self.peerConnection!.add(localAudioTrack, streamIds: ["audio0"])
        }
        if self.channels.datachannel {
            self.dataChannel = self.setupDataChannel()
            self.dataChannel?.delegate = self
        }
        
        let offerSDP = try await makeOffer()
        try await sendSDP(offerSDP)
    }
    
    func disconnect(){
        self.peerConnection?.close()
    }
    
    // MARK: Communication routines
    func sendMessge(message: String){
        if let _dataChannel = self.remoteDataChannel ?? self.dataChannel {
            if _dataChannel.readyState == .open {
                let buffer = RTCDataBuffer(data: message.data(using: String.Encoding.utf8)!, isBinary: false)
                _dataChannel.sendData(buffer)
            }else {
                logger.warning("data channel is not ready state")
            }
        }else{
            logger.warning("no data channel")
        }
    }
    
    func sendData(data: Data){
        if let _dataChannel = self.remoteDataChannel ?? self.dataChannel {
            if _dataChannel.readyState == .open {
                let buffer = RTCDataBuffer(data: data, isBinary: true)
                _dataChannel.sendData(buffer)
            }
        }
    }
    
    func captureCurrentFrame(sampleBuffer: CMSampleBuffer){
        if let capturer = self.videoCapturer as? RTCCustomFrameCapturer {
            capturer.capture(sampleBuffer)
        }
    }
    
    func captureCurrentFrame(sampleBuffer: CVPixelBuffer){
        if let capturer = self.videoCapturer as? RTCCustomFrameCapturer {
            capturer.capture(sampleBuffer)
        }
    }
    
    // MARK: Other controlling rountines
    func switchCameraPosition() {
        if let capturer = self.videoCapturer as? RTCCameraVideoCapturer {
            capturer.stopCapture {
                let position = (self.cameraDevicePosition == .front) ? AVCaptureDevice.Position.back : AVCaptureDevice.Position.front
                self.cameraDevicePosition = position
                self.startCaptureLocalVideoIfNotCustom(cameraPositon: position, videoWidth: 640, videoHeight: 640*16/9, videoFps: 30)
            }
        }
    }
    
    // MARK: - Setup
    private func setupPeerConnection() -> RTCPeerConnection {
        let rtcConf = RTCConfiguration()
//        rtcConf.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        let mediaConstraints = RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: nil)
        let pc = self.peerConnectionFactory.peerConnection(with: rtcConf, constraints: mediaConstraints, delegate: nil)
        return pc
    }
    
//    private func setupLocalViewFrame(frame: CGRect){
//        localView.frame = frame
//        localRenderView?.frame = localView.frame
//    }
//
//    private func setupRemoteViewFrame(frame: CGRect){
//        remoteView.frame = frame
//        remoteRenderView?.frame = remoteView.frame
//    }
    
//    private func setupView(){
//        localRenderView = RTCEAGLVideoView()
//        localRenderView!.delegate = self
//        localView = UIView()
//        localView.addSubview(localRenderView!)
//
//        remoteRenderView = RTCEAGLVideoView()
//        remoteRenderView?.delegate = self
//        remoteView = UIView()
//        remoteView.addSubview(remoteRenderView!)
//    }
    
    private func setupLocalTracks(){
        if self.channels.video == true {
            self.localVideoTrack = createVideoTrack()
        }
        if self.channels.audio == true {
            self.localAudioTrack = createAudioTrack()
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = self.peerConnectionFactory.audioSource(with: audioConstrains)
        let audioTrack = self.peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
        
        // audioTrack.source.volume = 10

        return audioTrack
    }
    
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = self.peerConnectionFactory.videoSource()
        
        /// TODO: set video output resolution based on iPad hardware description
        videoSource.adaptOutputFormat(toWidth: 2016, height: 1512, fps: 30)
        
        if self.customFrameCapturer {
            self.videoCapturer = RTCCustomFrameCapturer(delegate: videoSource)
        } else if TARGET_OS_SIMULATOR != 0 {
            logger.debug("now runnnig on simulator...")
            self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        }
        else {
            self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        }
        let videoTrack = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
        return videoTrack
    }
    
    private func startCaptureLocalVideoIfNotCustom(cameraPositon: AVCaptureDevice.Position, videoWidth: Int, videoHeight: Int?, videoFps: Int) {
        if let capturer = self.videoCapturer as? RTCCameraVideoCapturer {
            var targetDevice: AVCaptureDevice?
            var targetFormat: AVCaptureDevice.Format?
            
            // find target device
            let devicies = RTCCameraVideoCapturer.captureDevices()
            devicies.forEach { (device) in
                if device.position ==  cameraPositon{
                    targetDevice = device
                }
            }
            
            // find target format
            let formats = RTCCameraVideoCapturer.supportedFormats(for: targetDevice!)
            formats.forEach { (format) in
                for _ in format.videoSupportedFrameRateRanges {
                    let description = format.formatDescription as CMFormatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(description)
                    
                    if dimensions.width == videoWidth && dimensions.height == videoHeight ?? 0{
                        targetFormat = format
                    } else if dimensions.width == videoWidth {
                        targetFormat = format
                    }
                }
            }
            
            capturer.startCapture(with: targetDevice!,
                                  format: targetFormat!,
                                  fps: videoFps)
        } else if let capturer = self.videoCapturer as? RTCFileVideoCapturer {
            logger.debug("setup file video capturer")
            if let _ = Bundle.main.path( forResource: "sample.mp4", ofType: nil ) {
                capturer.startCapturing(fromFileNamed: "sample.mp4") { (err) in
                    logger.error("\(err)")
                }
            }else{
                logger.warning("file did not found")
            }
        }
    }
    
    private func setupDataChannel() -> RTCDataChannel{
        let dataChannelConfig = RTCDataChannelConfiguration()
        dataChannelConfig.isOrdered = true
        dataChannelConfig.channelId = 0
        
        let _dataChannel = self.peerConnection?.dataChannel(forLabel: "dataChannel", configuration: dataChannelConfig)
        return _dataChannel!
    }
    
    // MARK: - Signaling Offer/Answer
    private func makeOffer() async throws -> RTCSessionDescription {
        return try await withUnsafeThrowingContinuation { cont in
            guard self.peerConnection != nil else {
                cont.resume(throwing: WebRTCError.missingPeerConnection)
                return
            }

            self.peerConnection!.offer(for: RTCMediaConstraints.init(mandatoryConstraints: webRTCOfferConstraints, optionalConstraints: nil)) { (sdp, err) in
                if let error = err {
                    logger.error("error with make offer: \(error)")
                    cont.resume(throwing: WebRTCError.generateOfferSDP)
                    return
                }
                
                if let offerSDP = sdp {
                    self.peerConnection!.setLocalDescription(offerSDP, completionHandler: { (err) in
                        if let error = err {
                            logger.error("error with set local offer sdp: \(error)")
                            cont.resume(throwing: WebRTCError.setLocalOffserSDP)
                            return
                        }
                        logger.debug("Generated offser SDP: \(offerSDP)")
                        cont.resume(returning: offerSDP)
                    })
                }
            }
        }
    }
    
    private func receiveAnswer(answerSDP: RTCSessionDescription) async throws -> Void {
        return try await withUnsafeThrowingContinuation() {cont in
            guard self.peerConnection != nil else {
                cont.resume(throwing: WebRTCError.missingPeerConnection)
                return
            }

            self.peerConnection!.setRemoteDescription(answerSDP) { (err) in
                if let error = err {
                    logger.error("failed to set remote answer SDP: \(error)")
                    cont.resume(throwing: WebRTCError.setRemoteAnswerSDP)
                    return
                }
                cont.resume()
            }
        }
    }
    
    private func makeAnswer() async throws -> RTCSessionDescription {
        logger.warning("Making answers from the client is not supported currently")
        
        return try await withUnsafeThrowingContinuation() {cont in
            guard self.peerConnection != nil else {
                cont.resume(throwing: WebRTCError.missingPeerConnection)
                return
            }

            self.peerConnection!.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), completionHandler: { (answerSessionDescription, err) in
                if let error = err {
                    logger.error("failed to create local answer SDP: \(error)")
                    cont.resume(throwing: WebRTCError.generateAnswerSDP)
                    return
                }
                
                if let answerSDP = answerSessionDescription {
                    self.peerConnection!.setLocalDescription( answerSDP, completionHandler: { (err) in
                        if let error = err {
                            logger.error("failed to set local ansewr SDP: \(error)")
                            cont.resume(throwing: WebRTCError.setLocalAnswerSDP)
                            return
                        }
                        cont.resume(returning: answerSDP)
                    })
                }
            })
        }
    }
    
    private func receiveOffer(offerSDP: RTCSessionDescription) async throws -> RTCSessionDescription {
        logger.warning("Receiving offer from the client is currently not supported")
        
        if (self.peerConnection == nil) {
            logger.debug("offer received, create peerconnection")
            self.peerConnection = setupPeerConnection()
            self.peerConnection!.delegate = self
            if self.channels.video {
                self.peerConnection!.add(localVideoTrack, streamIds: ["stream-0"])
            }
            if self.channels.audio {
                self.peerConnection!.add(localAudioTrack, streamIds: ["stream-0"])
            }
            if self.channels.datachannel {
                self.dataChannel = self.setupDataChannel()
                self.dataChannel?.delegate = self
            }
            
        }
        
        logger.debug("set remote description")
        let _: Void = try await withUnsafeThrowingContinuation() { cont in
            guard self.peerConnection != nil else {
                cont.resume(throwing: WebRTCError.missingPeerConnection)
                return
            }

            self.peerConnection!.setRemoteDescription(offerSDP) { (err) in
                if let error = err {
                    logger.error("failed to set remote offer SDP: \(error)")
                    cont.resume(throwing: WebRTCError.setRemoteOffserSDP)
                    return
                }
                cont.resume()
            }
        }
        
        return try await makeAnswer()
    }
    
    private func receiveCandidate(candidate: RTCIceCandidate){
        self.peerConnection!.add(candidate)
    }

    private func sendSDP(_ sessionDescription: RTCSessionDescription) async throws {
        guard let signalingServer = self.signalingServer else {
            throw WebRTCError.missingSignalingServer
        }
        
        var type = ""
        if sessionDescription.type == .offer {
            type = "offer"
        } else if sessionDescription.type == .answer {
            type = "answer"
        }
        
        let outboundMessage = SDPMessage.init(type: type, sdp: sessionDescription.sdp)
        
        let postData = try JSONEncoder().encode(outboundMessage)
        var request = URLRequest(url: signalingServer)
        request.httpMethod = "POST"
        request.httpBody = postData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if (response as! HTTPURLResponse).statusCode >= 400 {
            logger.error("Error when requesting signaling server: \(String(data: data, encoding: .utf8) ?? "unknown response")")
            return
        }
        
        let incomingMessage = try JSONDecoder().decode(SDPMessage.self, from: data)
        guard (incomingMessage.type == "answer" && outboundMessage.type == "offer" || incomingMessage.type == "offer" && outboundMessage.type == "answer") else {
            logger.error("Error when requesting signaling server: mismatched SDP types. Outbound message of type \(outboundMessage.type) is responded with type \(incomingMessage.type)")
            return
        }
        
        switch incomingMessage.type {
        case "answer":
            try await self.receiveAnswer(answerSDP: RTCSessionDescription(type: .answer, sdp: incomingMessage.sdp))
//        case "offer":
//            logger.warning("Receive signaling message of type `offer`. This message is not expected in the current system implementation.")
//            let answerSDP = try await self.receiveOffer(offerSDP: RTCSessionDescription(type: .offer, sdp: incomingMessage.sdp))
//            try await self.sendSDP(answerSDP)
        default:
            logger.warning("Receive unknown signaling message of type `\(incomingMessage.type)`.")
        }
    }
    
    // MARK: - Connection Events + Delegates
    private func onConnected(){
        self.isConnected = true
        
        DispatchQueue.main.async {
//            self.remoteRenderView?.isHidden = false
            self.delegate?.didConnectWebRTC()
        }
    }
    
    private func onDisConnected(){
        self.isConnected = false
        
        DispatchQueue.main.async {
            logger.debug("--- Disconnected ---")
            self.peerConnection!.close()
            self.peerConnection = nil
//            self.remoteRenderView?.isHidden = true
            self.dataChannel = nil
            self.delegate?.didDisconnectWebRTC()
        }
    }
}

// MARK: - PeerConnection Delegeates
extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        var state = ""
        if stateChanged == .stable{
            state = "stable"
        }
        
        if stateChanged == .closed{
            state = "closed"
        }
        
        logger.debug("signaling state changed: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        
        switch newState {
        case .connected, .completed:
            if !self.isConnected {
                self.onConnected()
            }
        default:
            if self.isConnected{
                self.onDisConnected()
            }
        }
        
        DispatchQueue.main.async {
            self.delegate?.didIceConnectionStateChanged(iceConnectionState: newState)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        logger.debug("Stream added \(stream.streamId)")
        self.remoteStream = stream
        
        if let track = stream.videoTracks.first {
            logger.debug("Found video track \(track.trackId)")
//            track.add(remoteRenderView!)
        }
        
        if let audioTrack = stream.audioTracks.first{
            logger.debug("Found audio track \(audioTrack.trackId)")
            audioTrack.source.volume = 8
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.didGenerateCandidate(iceCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        logger.debug("--- did remove stream ---")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        self.remoteDataChannel = dataChannel
        self.delegate?.didOpenDataChannel()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
}

// MARK: - RTCVideoView Delegate
//extension WebRTCClient: RTCVideoViewDelegate {
//    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
//        let isLandScape = size.width < size.height
//        var renderView: RTCEAGLVideoView?
//        var parentView: UIView?
//        if videoView.isEqual(localRenderView){
//            logger.debug("local video size changed")
//            renderView = localRenderView
//            parentView = localView
//        }
//        
//        if videoView.isEqual(remoteRenderView!){
//            logger.debug("remote video size changed to: \(size.debugDescription)")
//            renderView = remoteRenderView
//            parentView = remoteView
//        }
//        
//        guard let _renderView = renderView, let _parentView = parentView else {
//            return
//        }
//        
//        if(isLandScape){
//            let ratio = size.width / size.height
//            _renderView.frame = CGRect(x: 0, y: 0, width: _parentView.frame.height * ratio, height: _parentView.frame.height)
//            _renderView.center.x = _parentView.frame.width/2
//        }else{
//            let ratio = size.height / size.width
//            _renderView.frame = CGRect(x: 0, y: 0, width: _parentView.frame.width, height: _parentView.frame.width * ratio)
//            _renderView.center.y = _parentView.frame.height/2
//        }
//    }
//}

// MARK: - RTCDataChannelDelegate
extension WebRTCClient: RTCDataChannelDelegate {
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        DispatchQueue.main.async {
            if buffer.isBinary {
                self.delegate?.didReceiveData(data: buffer.data)
            }else {
                self.delegate?.didReceiveMessage(message: String(data: buffer.data, encoding: String.Encoding.utf8)!)
            }
        }
    }
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let stateString = switch dataChannel.readyState {
            case .closed: "closed"
            case .closing: "closing"
            case .connecting: "connecting"
            case .open: "open"
            @unknown default: "???"
        }
        logger.debug("Data channel state changed to \(stateString)")
    }
}
