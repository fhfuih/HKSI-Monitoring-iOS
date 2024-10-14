//
//  WebRTCTestScreen.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 28/7/2024.
//

import SwiftUI

struct WebRTCTestScreen: View {
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel
    
    var body: some View {
        VStack {
            Text(webRTCModel.iceConnectionState?.description ?? "Init")
            Text(webRTCModel.connected ? "Connected" : "Not connected")
            Button("Start") {
                Task {
                    try? await webRTCModel.connect()
                }
            }
        }
    }
}

#Preview {
    WebRTCTestScreen()
        .environment(WebRTCModel())
}
