//
//  SignalingSDP.swift
//  SimpleWebRTC
//
//  Created by n0 on 2019/01/08.
//  Copyright © 2019 n0. All rights reserved.
//

/// `type` must be `offer` or `answer`
struct SDPMessage: Codable {
    let type: String
    let data: SDPMessageData
}

/// `type` must be `ice-candidate`
struct IceCandidateMessage: Codable {
    let type: String
    let data: IceCandidateMessageData
}

/// `type` must be `ice-server`
struct IceServerMessage: Codable {
    let type: String
    let data: [IceServer]
}

/// `type` must be `error` or `success`
struct ResponseMessage: Codable {
    let type: String
    let data: ErrorMessageData?
}

/// ------

struct SDPMessageData: Codable {
    let sdp: String
    let type: String
}

struct IceCandidateMessageData: Codable {
    let sdp: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
}

struct IceServer: Codable {
    let urls: [String]
    let username: String?
    let credential: String?
}

struct ErrorMessageData: Codable {
    let message: String
    let code: Int
}
