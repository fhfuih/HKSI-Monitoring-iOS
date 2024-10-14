//
//  ScaleDeviceButtonLabel.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 24/4/2024.
//

import SwiftUI

struct ScaleDeviceButtonLabel: View {
    let qnDevice: QNDeviceInfo
    
    var body: some View {
        VStack {
            Text(qnDevice.bluetoothName)
            HStack {
                Text(qnDevice.name + " " + qnDevice.mac)
                if (qnDevice.hasWifi) {
                    Label("Support Wi-Fi", systemImage: "wifi.circle")
                        .labelStyle(.iconOnly)
                }
                if (qnDevice.hasEightElectrodes) {
                    Label("Support Eight Electrodes", systemImage: "8.circle")
                        .labelStyle(.iconOnly)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

//#Preview {
//    let device = QNBleDevice()
//    ScaleDeviceButtonLabel()
//}
