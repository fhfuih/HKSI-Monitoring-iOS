//
//  Errors.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 12/10/2024.
//

enum QNError: Error {
    case cannotStartScanning
    case cannotStopScanning
    case cannotConnect
    case cannotDisconnect
    case deviceNotSupported
    case waitSelectedDeviceTimeout
    case missingSelectedDevice
}

enum WebRTCError: Error {
    case malformedSignalingServerURL
    case missingSignalingServer
    case connection
    case missingPeerConnection
    case generateOfferSDP
    case generateAnswerSDP
    case setLocalOffserSDP
    case setLocalAnswerSDP
    case setRemoteOffserSDP
    case setRemoteAnswerSDP
    case connectionTimeout
    case connectionError
    case notImplementedError(String)
    case internalError(String)
}

enum WebRTCSignalingServerError: Error {
    case errorResponse(Int?, String?)
    case tooManyIceCandidates
    case connection
    case unsupportedMessage(String?)
    case internalError(String)
}
