//
//  SignalingSDP.swift
//  SimpleWebRTC
//
//  Created by n0 on 2019/01/08.
//  Copyright © 2019 n0. All rights reserved.
//

import Foundation

struct SDPMessage: Codable {
    let type: String
    let sdp: String
}

struct CandidateMessage: Codable {
    let type: String
    let candidate: Candidate
}

struct Candidate: Codable {
    let sdp: String
    let sdpMLineIndex: Int32
    let sdpMid: String
}
