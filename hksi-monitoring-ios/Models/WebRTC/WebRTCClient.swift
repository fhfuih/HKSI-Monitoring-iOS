import UIKit
import WebRTC

private let webRTCOfferConstraints = [
    kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueFalse,
    kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue,
]

protocol WebRTCClientDelegate {
    func didGenerateCandidate(iceCandidate: RTCIceCandidate)
    func didChangeConnectionState(connectionState: RTCPeerConnectionState)
    func didOpenDataChannel()
    func didReceiveData(data: Data)
    func didReceiveMessage(message: String)
    func didConnectWebRTC()
    func didDisconnectWebRTC()
}

class WebRTCClient: NSObject {
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    
    /// NOTE: the iOS WebRTC library doesn't include any ICE candidate when generating offer SDP.
    /// I wanted to facilitate the ICE process by appending every
    private var iceCandidateCache: [String] = []
    
    private var localVideoTrack: RTCVideoTrack!
    private var localAudioTrack: RTCAudioTrack!
    private var remoteStream: RTCMediaStream?
    private var dataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    
    private var videoCapturer: RTCVideoCapturer!
    private var useAudio: Bool = false
    private var useCustomFrameCapturer: Bool = true
    private var cameraDevicePosition: AVCaptureDevice.Position = .front

    // Signaling client
    lazy private var signalingClient = SignalingServerClient(delegate: self)

    /// Used to block the `connect` function until the WebRTC library reports a "connected" state
    private var connectionContinuation: UnsafeContinuation<Void, Error>?

    var delegate: WebRTCClientDelegate?
    public private(set) var isConnected: Bool = false

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
    func setup(audioTrack: Bool) {
        self.useAudio = audioTrack

        /// Peer Connection Factory Setup
        if TARGET_OS_SIMULATOR != 0 {
            logger.debug("setup simulator codec")
            self.peerConnectionFactory = RTCPeerConnectionFactory(
                encoderFactory: RTCSimluatorVideoEncoderFactory(),
                decoderFactory: RTCSimulatorVideoDecoderFactory()
            )
        } else {
            self.peerConnectionFactory = RTCPeerConnectionFactory(
                encoderFactory: RTCDefaultVideoEncoderFactory(),
                decoderFactory: RTCDefaultVideoDecoderFactory()
            )
        }


        /// The function below does nothing because we ALWAYS use customCapturer
        startCaptureLocalVideoIfNotCustom(
            cameraPositon: self.cameraDevicePosition, videoWidth: 640, videoHeight: 640 * 16 / 9,
            videoFps: 30)
    }

    func connect(_ signalingServerURL: URL) async throws {
        /// Create and connect signaling client
        self.signalingClient.delegate = self
        let iceServers = try await self.signalingClient.connect(signalingServerURL)

        /// Create a peer connection
        self.peerConnection = try await setupPeerConnection(iceServers: iceServers)

        /// Create tracks
        self.localVideoTrack = createVideoTrack()
        self.peerConnection!.add(localVideoTrack, streamIds: ["video0"])
        if self.useAudio {
            self.localAudioTrack = createAudioTrack()
            self.peerConnection!.add(localAudioTrack, streamIds: ["audio0"])
        }
        self.dataChannel = self.createDataChannel()
        self.dataChannel?.delegate = self

        /// Make an offer SDP based on the available tracks
        let offerSDP = try await makeOffer()

        /// Send the offer SDP via WebSocket
        try await sendSDPViaWebSocket(offerSDP)

        /// Wait until WebRTC is really connected
        try await withUnsafeThrowingContinuation { continuation in
            self.connectionContinuation = continuation

            Task {
                try await Task.sleep(for: .seconds(30))
                if !isConnected && connectionContinuation != nil {
                    connectionContinuation?.resume(throwing: WebRTCError.connectionTimeout)
                    connectionContinuation = nil
                    isConnected = false
                }
            }
        }
    }

    func disconnect() {
        self.isConnected = false
        
        self.dataChannel?.close()
        self.dataChannel = nil
        self.peerConnection?.close()
        self.peerConnection = nil
        self.signalingClient.disconnect()
        
        DispatchQueue.main.async {
            self.delegate?.didDisconnectWebRTC()
        }
    }

    // MARK: Communication routines
    func sendMessge(message: String) {
        if let _dataChannel = self.remoteDataChannel ?? self.dataChannel {
            if _dataChannel.readyState == .open {
                let buffer = RTCDataBuffer(
                    data: message.data(using: String.Encoding.utf8)!, isBinary: false)
                _dataChannel.sendData(buffer)
                logger.debug("Message sent: \(message)")
            } else {
                logger.warning("data channel is not ready state")
            }
        } else {
            logger.warning("no data channel")
        }
    }

    func stopSendingVideoTrack() {
        if let cameraCapturer = self.videoCapturer as? RTCCameraVideoCapturer {
            cameraCapturer.stopCapture {
                logger.debug("Camera capture stopped")
            }
        }

        if let sender = self.peerConnection?.senders.first(where: { $0.track?.kind == "video" }) {
            self.peerConnection?.removeTrack(sender)
            logger.debug("Video track removed from peerConnection")
        }
    }

    func sendData(data: Data) {
        if let _dataChannel = self.remoteDataChannel ?? self.dataChannel {
            if _dataChannel.readyState == .open {
                let buffer = RTCDataBuffer(data: data, isBinary: true)
                _dataChannel.sendData(buffer)
            }
        }
    }

    func captureCurrentFrame(sampleBuffer: CMSampleBuffer) {
        if let capturer = self.videoCapturer as? RTCCustomFrameCapturer {
            capturer.capture(sampleBuffer)
        }
    }

    func captureCurrentFrame(sampleBuffer: CVPixelBuffer) {
        if let capturer = self.videoCapturer as? RTCCustomFrameCapturer {
            capturer.capture(sampleBuffer)
        }
    }

    // MARK: Other controlling rountines
    func switchCameraPosition() {
        if let capturer = self.videoCapturer as? RTCCameraVideoCapturer {
            capturer.stopCapture {
                let position =
                    (self.cameraDevicePosition == .front)
                    ? AVCaptureDevice.Position.back : AVCaptureDevice.Position.front
                self.cameraDevicePosition = position
                self.startCaptureLocalVideoIfNotCustom(
                    cameraPositon: position, videoWidth: 640, videoHeight: 640 * 16 / 9,
                    videoFps: 30)
            }
        }
    }

    // MARK: - Setup
    private func setupPeerConnection(iceServers: [RTCIceServer]) async throws -> RTCPeerConnection {
        /// Construct PeerConnection
        let rtcConf = RTCConfiguration()
        rtcConf.iceServers = iceServers
        rtcConf.iceTransportPolicy = .relay
        let mediaConstraints = RTCMediaConstraints.init(
            mandatoryConstraints: nil, optionalConstraints: nil)
        let pc = self.peerConnectionFactory.peerConnection(
            with: rtcConf, constraints: mediaConstraints, delegate: self)
        return pc
    }

    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = self.peerConnectionFactory.audioSource(with: audioConstrains)
        let audioTrack = self.peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")

        // audioTrack.source.volume = 10

        return audioTrack
    }

    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = self.peerConnectionFactory.videoSource()

        /// TODO: set video output resolution based on iPad hardware description
        videoSource.adaptOutputFormat(toWidth: 2016, height: 1512, fps: 30)

        if self.useCustomFrameCapturer {
            self.videoCapturer = RTCCustomFrameCapturer(delegate: videoSource)
        } else if TARGET_OS_SIMULATOR != 0 {
            logger.debug("now runnnig on simulator...")
            self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        } else {
            self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        }
        let videoTrack = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
        return videoTrack
    }

    private func startCaptureLocalVideoIfNotCustom(
        cameraPositon: AVCaptureDevice.Position, videoWidth: Int, videoHeight: Int?, videoFps: Int
    ) {
        if let capturer = self.videoCapturer as? RTCCameraVideoCapturer {
            var targetDevice: AVCaptureDevice?
            var targetFormat: AVCaptureDevice.Format?

            /// find target device
            let devicies = RTCCameraVideoCapturer.captureDevices()
            devicies.forEach { (device) in
                if device.position == cameraPositon {
                    targetDevice = device
                }
            }

            /// find target format
            let formats = RTCCameraVideoCapturer.supportedFormats(for: targetDevice!)
            formats.forEach { (format) in
                for _ in format.videoSupportedFrameRateRanges {
                    let description = format.formatDescription as CMFormatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(description)

                    if dimensions.width == videoWidth && dimensions.height == videoHeight ?? 0 {
                        targetFormat = format
                    } else if dimensions.width == videoWidth {
                        targetFormat = format
                    }
                }
            }

            capturer.startCapture(
                with: targetDevice!,
                format: targetFormat!,
                fps: videoFps)
        } else if let capturer = self.videoCapturer as? RTCFileVideoCapturer {
            logger.debug("setup file video capturer")
            if Bundle.main.path(forResource: "sample.mp4", ofType: nil) != nil {
                capturer.startCapturing(fromFileNamed: "sample.mp4") { (err) in
                    logger.error("\(err)")
                }
            } else {
                logger.warning("file did not found")
            }
        }
    }

    private func createDataChannel() -> RTCDataChannel {
        let dataChannelConfig = RTCDataChannelConfiguration()
        dataChannelConfig.isOrdered = true
        dataChannelConfig.channelId = 0

        let _dataChannel = self.peerConnection?.dataChannel(
            forLabel: "dataChannel", configuration: dataChannelConfig)
        return _dataChannel!
    }

    // MARK: - Signaling Offer/Answer
    private func makeOffer() async throws -> RTCSessionDescription {
        return try await withUnsafeThrowingContinuation { cont in
            guard self.peerConnection != nil else {
                cont.resume(throwing: WebRTCError.missingPeerConnection)
                return
            }

            self.peerConnection!.offer(
                for: RTCMediaConstraints.init(
                    mandatoryConstraints: webRTCOfferConstraints, optionalConstraints: nil)
            ) { (offerSDP, error) in
                if let error {
                    logger.error("error with make offer: \(error)")
                    cont.resume(throwing: WebRTCError.generateOfferSDP)
                    return
                }
                if let offerSDP {
                    self.peerConnection!.setLocalDescription(
                        offerSDP,
                        completionHandler: { (err) in
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

    private func receiveAnswer(answerSDP: RTCSessionDescription) async throws {
        return try await withUnsafeThrowingContinuation { cont in
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
                logger.debug("Received answer SDP: \(answerSDP)")
                cont.resume()
            }
        }
    }

    private func makeAnswer() async throws -> RTCSessionDescription {
        logger.warning("Making answers from the client is not supported currently")

        return try await withUnsafeThrowingContinuation { cont in
            guard self.peerConnection != nil else {
                cont.resume(throwing: WebRTCError.missingPeerConnection)
                return
            }

            self.peerConnection!.answer(
                for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil),
                completionHandler: { (answerSessionDescription, err) in
                    if let error = err {
                        logger.error("failed to create local answer SDP: \(error)")
                        cont.resume(throwing: WebRTCError.generateAnswerSDP)
                        return
                    }

                    if let answerSDP = answerSessionDescription {
                        self.peerConnection!.setLocalDescription(
                            answerSDP,
                            completionHandler: { (err) in
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

    private func sendSDPViaWebSocket(_ sessionDescription: RTCSessionDescription) async throws {
        guard sessionDescription.type == .offer else {
            throw WebRTCError.notImplementedError("Must make and send `offer` SDP, not answer")
        }

        let sdpData = SDPMessageData(
            sdp: sessionDescription.sdp.appending(self.iceCandidateCache.joined(separator: "\r\n")),
            type: "offer"
        )
        let outboundMessage = SDPMessage(type: "offer", data: sdpData)

        let answerSDP = try await signalingClient.sendSDPMessage(outboundMessage)
        guard answerSDP.type == "answer" && answerSDP.data.type == "answer" else {
            logger.error("Mismatched SDP types. Outbound: offer, Incoming: \(answerSDP.type)")
            throw WebRTCError.internalError("Mismatched SDP types. Outbound: offer, Incoming: \(answerSDP.type)")
        }
        
        try await self.receiveAnswer(answerSDP: RTCSessionDescription(type: .answer, sdp: answerSDP.data.sdp))
    }

    private func sendICECandidateViaWebSocket(_ candidate: RTCIceCandidate) async throws {
        let candidateData = IceCandidateMessageData(
            sdp: candidate.sdp,
            sdpMLineIndex: candidate.sdpMLineIndex,
            sdpMid: candidate.sdpMid
        )
        let message = IceCandidateMessage(type: "ice-candidate", data: candidateData)

        let response = try await signalingClient.sendICECandidate(message)
        if response.type == "error" {
            throw WebRTCSignalingServerError.errorResponse(response.data?.code, response.data?.message)
        }
    }

}

// MARK: - SignalingServerClientDelegate
extension WebRTCClient: SignalingServerClientDelegate {
    func signalingClientDidDisconnect(_ client: SignalingServerClient, error: Error?) {
        logger.error(
            "Signaling client disconnected: \(error?.localizedDescription ?? "Unknown error")")
        // Handle unexpected disconnection
        if isConnected {
            self.disconnect()
        }
    }

    func remoteDidTrickle(_ client: SignalingServerClient, candidate: RTCIceCandidate) {
        logger.debug("Received trickled ICE candidate: \(candidate.sdp)")
        self.peerConnection?.add(candidate)
    }
}

// MARK: - PeerConnection Delegeates
extension WebRTCClient: RTCPeerConnectionDelegate {
    /// When remote adds a new stream
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        logger.debug("Remote added stream \(stream.streamId)")
        self.remoteStream = stream

        if let track = stream.videoTracks.first {
            logger.debug("Found video track \(track.trackId) in remote stream")
        }

        if let audioTrack = stream.audioTracks.first {
            logger.debug("Found audio track \(audioTrack.trackId) in remote stream")
            audioTrack.source.volume = 8
        }
    }

    /// When remote removes a stream
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        logger.debug("Remote removed stream \(stream.streamId)")
        self.remoteStream = nil
    }

    /// When PeerConnectionState changed
    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState
    ) {
        logger.debug("connectionState -> \(newState.description)")

        switch newState {
        case .connected:
            if !self.isConnected {
                self.isConnected = true
                /// Unblock the `async connect()` function
                if self.connectionContinuation != nil {
                    self.connectionContinuation?.resume()
                    self.connectionContinuation = nil
                }
                /// Execute external event handler
                DispatchQueue.main.async {
                    self.delegate?.didConnectWebRTC()
                }
            }
        case .disconnected:
            if self.isConnected {
                self.disconnect()
            }
        case .failed:
            if self.isConnected {
                self.disconnect()
            }
            /// Unblock the `async connect()` function
            if self.connectionContinuation != nil {
                self.connectionContinuation?.resume(throwing: WebRTCError.connectionError)
                self.connectionContinuation = nil
            }
        default:
            break
        }

        /// Execute the external event handler (exposed via delegate) asynchronously
        DispatchQueue.main.async {
            self.delegate?.didChangeConnectionState(connectionState: newState)
        }
    }

    /// When signaling state change
    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState
    ) {
        logger.debug("signalingState -> \(stateChanged.description)")
    }

    /// When ICE connection state changes
    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState
    ) {
        logger.debug("iceConnectionState -> \(newState.description)")
    }

    /// When ICE gathering state changes
    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState
    ) {
        logger.debug("iceGatheringState -> \(newState.description)")
    }

    /// When new local ICE candidate is generated
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate)
    {
        logger.debug("ICE candidate found: \(candidate.sdp)")
        
        self.iceCandidateCache.append("a=\(candidate.sdp)")

        // Send via WebSocket
        Task {
            do {
                try await sendICECandidateViaWebSocket(candidate)
            } catch {
                logger.error("Failed to send candidate '\(candidate.sdp)' to remote: \(error)")
            }
        }

        self.delegate?.didGenerateCandidate(iceCandidate: candidate)
    }

    /// When local ICE(s) are removed
    func peerConnection(
        _ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]
    ) {
        logger.debug(
            "ICE candiate removed: \(candidates.map({ $0.serverUrl ?? "nil URL" }).joined(separator: ","))"
        )
    }

    /// When data channel is opened
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        logger.debug("DataChannel opened: \(dataChannel.channelId)")
        self.remoteDataChannel = dataChannel
        self.delegate?.didOpenDataChannel()
    }

    /// When negotiation is needed, for example ICE has restarted
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        logger.debug("Negotiation is needed. (ICE may have restarted.)")
    }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCClient: RTCDataChannelDelegate {
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        DispatchQueue.main.async {
            if buffer.isBinary {
                self.delegate?.didReceiveData(data: buffer.data)
            } else {
                self.delegate?.didReceiveMessage(
                    message: String(data: buffer.data, encoding: String.Encoding.utf8)!)
            }
        }
    }

    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        logger.debug("DataChannel state -> \(dataChannel.readyState.description)")
    }
}

// MARK: Helper extensions to log the states verbally
extension RTCIceConnectionState {
    // https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/iceConnectionState
    public var description: String {
        return switch self {
        case .new: "NEW"
        case .checking: "CHECKING"
        case .connected: "CONNECTED"
        case .completed: "COMPLETED"
        case .failed: "FAILED"
        case .disconnected: "DISCONNECTED"
        case .closed: "CLOSED"
        case .count: "COUNT"
        @unknown default: "UNKNOWN(\(self.rawValue))"
        }
    }
}

extension RTCPeerConnectionState {
    // https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/connectionState
    public var description: String {
        return switch self {
        case .new: "NEW"
        case .connecting: "CONNECTING"
        case .connected: "CONNECTED"
        case .failed: "FAILED"
        case .disconnected: "DISCONNECTED"
        case .closed: "CLOSED"
        @unknown default: "UNKNOWN(\(self.rawValue))"
        }
    }
}

extension RTCIceGatheringState {
    // https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/iceGatheringState
    public var description: String {
        return switch self {
        case .new: "NEW"
        case .gathering: "GATHERING"
        case .complete: "COMPLETE"
        @unknown default: "UNKNOWN(\(self.rawValue))"
        }
    }
}

extension RTCSignalingState {
    // https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnection/signalingState
    public var description: String {
        return switch self {
        case .stable: "STABLE"
        case .haveLocalOffer: "HAVE_LOCAL_OFFER"
        case .haveLocalPrAnswer: "HAVE_LOCAL_PR_ANSWER"
        case .haveRemoteOffer: "HAVE_REMOTE_OFFER"
        case .haveRemotePrAnswer: "HAVE_REMOTE_PRE_ANSWER"
        case .closed: "UNKNOWN(\(self.rawValue))"
        /// According to the source code, this is not an actual state
        @unknown default: "UNKNOWN(\(self.rawValue))"
        }
    }
}

extension RTCDataChannelState {
    // https://developer.mozilla.org/en-US/docs/Web/API/RTCDataChannel/readyState
    public var description: String {
        return switch self {
        case .connecting: "CONNECTING"
        case .open: "OPEN"
        case .closing: "CLOSING"
        case .closed: "CLOSED"
        @unknown default: "UNKNOWN(\(self.rawValue))"
        }
    }
}
