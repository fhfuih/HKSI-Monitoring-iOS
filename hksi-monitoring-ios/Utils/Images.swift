//
//  Images.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 7/18/25.
//

import AVFoundation
import SwiftUI

let CI_CONTEXT = CIContext(options: nil)

func ciImageToImage(_ ciImage: CIImage) -> Image? {
    guard let cgImage = CI_CONTEXT.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return Image(decorative: cgImage, scale: 1, orientation: .up)
}
