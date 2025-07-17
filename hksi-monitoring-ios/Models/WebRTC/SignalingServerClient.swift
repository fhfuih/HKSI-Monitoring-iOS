import Foundation
import WebRTC

// MARK: - SignalingServerClientDelegate Protocol

protocol SignalingServerClientDelegate: AnyObject {
    /// Called when WebSocket disconnects unexpectedly
    func signalingClientDidDisconnect(_ client: SignalingServerClient, error: Error?)
    
    /// Called when server sends ICE candidate (trickling)
    func remoteDidTrickle(_ client: SignalingServerClient, candidate: RTCIceCandidate)
}

// MARK: - SignalingServerClient Class

class SignalingServerClient: NSObject {
    
    // MARK: - Public Properties
    weak var delegate: SignalingServerClientDelegate?
    
    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    // MARK: - Initialization
    init(delegate: SignalingServerClientDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Public Methods
    func connect(_ serverURL: URL) async throws -> [RTCIceServer] {
        let formattedServerURL = switch serverURL.scheme {
        case "http": URL(string: serverURL.absoluteString.replacingOccurrences(of: "http://", with: "ws://"))!
        case "https": URL(string: serverURL.absoluteString.replacingOccurrences(of: "https://", with: "wss://"))!
        default: serverURL
        }
        
        self.urlSession = URLSession(configuration: .default)
        self.webSocketTask = urlSession?.webSocketTask(with: formattedServerURL)
        
        webSocketTask?.resume()
        
        // TODO: hide hardcoded RTCIceServer
        /// Ideally, don't save any secret on client.
        /// Can (a)wait for an initial `ice-server` message after WS connection and only resolve after receiving that message (throwing if timeout and stop).
        /// But fuck it, nobody pays me for writing these codes and I publish no paper for that.
        return [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun.relay.metered.ca:80"]),
            RTCIceServer(urlStrings: [
                "turn:global.relay.metered.ca:80",
                "turn:global.relay.metered.ca:80?transport=tcp",
                "turn:global.relay.metered.ca:443",
                "turns:global.relay.metered.ca:443?transport=tcp",
            ], username: "aa60b60315b7c288cf8af307", credential: "hONiDDIaOod1EnhJ")
        ]
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
    }
    
    func sendSDPMessage(_ message: SDPMessage) async throws -> SDPMessage {
        return try await sendMessageAndWaitForResponse(message, SDPMessage.self)
    }
    
    func sendICECandidate(_ message: IceCandidateMessage) async throws -> ResponseMessage {
        return try await sendMessageAndWaitForResponse(message, ResponseMessage.self)
    }
    
    // MARK: - Private Methods
    private func sendMessageAndWaitForResponse<T: Codable, R: Decodable>(_ message: T, _ responseType: R.Type) async throws -> R {
        guard let webSocketTask = webSocketTask else {
            throw WebRTCSignalingServerError.connection
        }
        
        let data = try JSONEncoder().encode(message)
        let text = String(data: data, encoding: .utf8)!
        
        try await webSocketTask.send(.string(text))
        
        return try await waitForResponse(responseType)
    }
    
    private func waitForResponse<T: Decodable>(_ responseType: T.Type) async throws -> T {
        for _ in 0..<10 {
            let responseString = try await waitForSingleMessage()
            if let response = try processSingleResponse(responseString, responseType) {
                return response
            }
        }
        throw WebRTCSignalingServerError.tooManyIceCandidates
    }
    
    /// Try to decode and return the message in the expected type.
    /// If receiving a trickling ice candidate: return nil.
    /// Throws if receiving an error reponse or having other internal errors
    private func processSingleResponse<T: Decodable>(_ response: String, _ responseType: T.Type) throws -> T? {
        guard let responseUtf8 = response.data(using: .utf8) else {
            throw WebRTCSignalingServerError.internalError("Cannot encode response in UTF8")
        }
        /// First try decode into expected response (and expected response can be Error as well)
        if let expectedResponse = try? JSONDecoder().decode(responseType, from: responseUtf8) {
            if let errorResponse = expectedResponse as? ResponseMessage, errorResponse.type == "error" {
                throw WebRTCSignalingServerError.errorResponse(errorResponse.data?.code, errorResponse.data?.message)
            }
            return expectedResponse
        }
        /// Then try to decode into an Error type
        if let errorResponse = try? JSONDecoder().decode(ResponseMessage.self, from: responseUtf8),
           errorResponse.type == "error" {
            throw WebRTCSignalingServerError.errorResponse(errorResponse.data?.code, errorResponse.data?.message)
        }
        /// Then try to decode into an iceCandidate
        if let iceCandidateResponse = try? JSONDecoder().decode(IceCandidateMessage.self, from: responseUtf8),
           iceCandidateResponse.type == "ice-candidate" {
            let candidate = RTCIceCandidate(
                sdp: iceCandidateResponse.data.sdp,
                sdpMLineIndex: iceCandidateResponse.data.sdpMLineIndex,
                sdpMid: iceCandidateResponse.data.sdpMid)
            self.delegate?.remoteDidTrickle(self, candidate: candidate)
            return nil
        }
        throw WebRTCSignalingServerError.unsupportedMessage("Response not in expected type, error, or ice-candidate")
    }
    
    private func waitForSingleMessage() async throws -> String {
        guard let webSocketTask else {
            throw WebRTCSignalingServerError.internalError("Wait for message but the webSocketTask is gone.")
        }
        
        switch try await webSocketTask.receive() {
        case let .data(data):
            throw WebRTCSignalingServerError.unsupportedMessage(String(data: data, encoding: .utf8) ?? "Non-UTF8 binary with \(data.count)B")
        case let .string(text):
            return text
        @unknown default:
            throw WebRTCSignalingServerError.internalError("Unknown message type beyond String and binary Data.")
        }
        
        //        return try await withUnsafeThrowingContinuation { cont in
        //            webSocketTask.receive { result in
        //                switch result {
        //                case .success(let message):
        ////                    cont.resume(returning: message)
        //                    switch message {
        //                    case .data(let data):
        //                        cont.resume(throwing: WebRTCSignalingServerError.unsupportedMessage(String(data: data, encoding: .utf8) ?? "Non-UTF8 binary with \(data.count)B"))
        //                    case .string(let string):
        //                        cont.resume(returning: string)
        //                    @unknown default:
        //                        cont.resume(throwing: WebRTCSignalingServerError.internalError("Unknown message type beyond String and binary Data."))
        //                    }
        //                case .failure(let error):
        //                    /// If the task reaches the `maximumMessageSize` while buffering the frames, this call fails with an error.
        //                    cont.resume(throwing: WebRTCSignalingServerError.internalError("Can't buffer incoming message: \(error)"))
        //                }
        //            }
        //        }
    }
}
