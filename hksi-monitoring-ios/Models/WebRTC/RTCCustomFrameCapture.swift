//
//  RTCDataCapture.swift
//  SimpleWebRTC
//
//  Created by n0 on 2019/02/08.
//  Copyright © 2019 n0. All rights reserved.
//

import Foundation
import WebRTC

class RTCCustomFrameCapturer: RTCVideoCapturer {
    
    let kNanosecondsPerSecond: Float64 = 1000000000
    var nanoseconds: Float64 = 0

    override init(delegate: RTCVideoCapturerDelegate) {
        super.init(delegate: delegate)
    }
    
    public func capture(_ sampleBuffer: CMSampleBuffer){
        let _pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        if let pixelBuffer = _pixelBuffer {
            let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
            let timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * kNanosecondsPerSecond
            let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: Int64(timeStampNs))
            self.delegate?.capturer(self, didCapture: rtcVideoFrame)
        }
    }
    
    public func capture(_ pixelBuffer: CVPixelBuffer){
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let timeStampNs = nanoseconds * kNanosecondsPerSecond

        let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: Int64(timeStampNs))
        self.delegate?.capturer(self, didCapture: rtcVideoFrame)
        nanoseconds += 1
    }
}
