//
//  ScanningView.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 12/4/2024.
//

import SwiftUI

fileprivate let DURATION_DISCARD: Double = 2
fileprivate let DURATION_TOTAL: Double = 36
fileprivate let DURATION_SENDING: Double = 34

struct ScanningScreen: View {
    /// XCode preview constantly crash. I have to pause the camera and countdown thing and actually run it to develop UI
    private let DEBUG = false
    
    @Environment(RouteModel.self) var routeModel: RouteModel
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel
    @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel
    
    /// This is the internal timer that stops the entire session in 30 seconds
    @State private var stopSessionTimer: Timer?

    /// This is the timer that stops sending more frames in 20 seconds
    @State private var stopSendingTimer: Timer?
    
    /// This is the timer that delays frame-sending for some seconds
    @State private var startSendingTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            Text("Athlete Daily Monitoring Booth")
                .font(.custom("Lexend", size: 50, relativeTo: .title))
            
            HStack(spacing: 50) {
                VStack(spacing: 50) {
                    FeatureSection(feature: .hr) {
                        VStack {
                            let hr = webRTCModel.intermediateValue?.hr ?? (DEBUG ? Optional(80.0) : nil)
                            let hrv = webRTCModel.intermediateValue?.hrv ?? (DEBUG ? Optional(70.0) : nil)
                            
                            if let hr {
                                Text("HR: ")
                                    .font(.system(size: 28, weight: .semibold)) +
                                Text(hr, format: .number)
                                    .font(.system(size: 40, weight: .bold))
                            }
                            
                            if let hrv {
                                Text("HRV: ")
                                    .font(.system(size: 28, weight: .semibold)) +
                                Text(hrv, format: .number)
                                    .font(.system(size: 40, weight: .bold))
                            }

                            if hr == nil && hrv == nil {
                                ProgressView()
                            }
                        }
                    }
                    FeatureSection(feature: .body) {
                        VStack {
                            /// Only weight is available in intermediate results
                            /// But we show body fat anyway to pretend awesome
//                            let weight = qnScaleModel.finalValue?.weight ?? qnScaleModel.intermediateWeight
//                            let bodyFat = qnScaleModel.finalValue?.bodyFat
                            let weight = qnScaleModel.intermediateWeight

                            if let weight {
                                Text("Weight: ")
                                    .font(.system(size: 28, weight: .semibold)) +
                                Text(weight, format: .number)
                                    .font(.system(size: 40, weight: .bold)) +
                                Text("kg")
                                    .font(.system(size: 28, weight: .semibold))
                            } else {
                                HStack {
                                    Text("Weight: ")
                                        .font(.system(size: 28, weight: .semibold))
                                    ProgressView()
                                        .frame(width: 40, height: 40)
                                }
                            }
                            
//                            if let bodyFat {
//                                Text("Body Fat: ")
//                                    .font(.system(size: 28, weight: .semibold)) +
//                                Text(bodyFat, format: .percent)
//                                    .font(.system(size: 40, weight: .bold))
//                            } else {
//                                HStack {
//                                    Text("Body Fat: ")
//                                        .font(.system(size: 28, weight: .semibold))
//                                    ProgressView()
//                                        .frame(width: 40, height: 40)
//                                }
//                            }
                        }
                    }
                }

                VStack {
                    CameraView()
                        .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: 0)
                    Text("Please put your face in the outlined area.")
                        .font(.title3)
//                    FrameToUploadView()
                }

                VStack(spacing: 50) {
                    FeatureSection(feature: .mood) {
                        if let fatigue = webRTCModel.intermediateValue?.fatigue ?? (DEBUG ? Optional(0.5) : nil) {
                            VStack {
                                Text("Fatigue level: ")
                                    .font(.system(size: 28, weight: .semibold))
                                Text(fatigue, format: .percent)
                                    .font(.system(size: 40, weight: .bold))
                            }
                        } else {
                            ProgressView()
                        }
                    }
                    FeatureSection(feature: .skin) {
                        VStack {
                                 let darkCircleLeft = webRTCModel.intermediateValue?.darkCircleLeft ?? (DEBUG ? Optional(false) : nil)
                                 let darkCircleRight = webRTCModel.intermediateValue?.darkCircleRight ?? (DEBUG ? Optional(false) : nil)
                                 let pimpleCount = webRTCModel.intermediateValue?.pimpleCount ?? (DEBUG ? Optional(0) : nil)

                            
                                 if let darkCircleLeft {
                                     Text("Dark circle (left): ")
                                         .font(.system(size: 28, weight: .semibold)) +
                                     Text(darkCircleLeft ? "Yes" : "No")
                                         .font(.system(size: 40, weight: .bold))
                                 }
                                 
                                 if let darkCircleRight {
                                     Text("Dark circle (right): ")
                                         .font(.system(size: 28, weight: .semibold)) +
                                     Text(darkCircleRight ? "Yes" : "No")
                                         .font(.system(size: 40, weight: .bold))
                                 }
                                 
                                 if let pimpleCount {
                                     Spacer().frame(height: 25)
                                     
                                     Text("Pimple count: ")
                                         .font(.system(size: 28, weight: .semibold)) +
                                     Text(pimpleCount, format: .number)
                                         .font(.system(size: 40, weight: .bold))
                                 }
                                 
                                 if darkCircleLeft == nil && darkCircleRight == nil && pimpleCount == nil {
                                     ProgressView()
                                 }
                            }
                            .padding(.top, -25)
                             
//                        VStack {
//                            let darkCircles = webRTCModel.intermediateValue?.darkCircles?.count ?? (DEBUG ? Optional(0) : nil)
//                            let pimples = webRTCModel.intermediateValue?.pimples?.count ?? (DEBUG ? Optional(0) : nil)
//                            
//                            if let darkCircles {
//                                Text("Dark circles around eyes: ")
//                                    .font(.system(size: 28, weight: .semibold))
//                                Text(darkCircles, format: .number)
//                                    .font(.system(size: 40, weight: .bold))
//                            }
//                            
//                            if let pimples {
//                                Text("Pimples: ")
//                                    .font(.system(size: 28, weight: .semibold))
//                                Text(pimples, format: .number)
//                                    .font(.system(size: 40, weight: .bold))
//                            }
//                            
//                            if darkCircles == nil && pimples == nil {
//                                ProgressView()
//                            }
//                        }
                    }
                }
            }
            
            let now = Date()
            ProgressView(timerInterval: now...(now.addingTimeInterval(DURATION_TOTAL)), countsDown: false) {
                HStack {
                    Text("Analyzing...")
                }
            }
        }
        .padding(.horizontal, 50.0)
        .padding(.vertical, 20.0)
        .toolbar(.hidden)
        .onAppear() {
            startSession()
        }
        .onDisappear() {
            stopSession()
        }
    }
    
    private func startSession() {
        /// Allow sending frames
        webRTCModel.shouldSendFrame = !DEBUG
        
        if !isInPreview() && !DEBUG {
            /// Optionally discard the first few frames
            if DURATION_DISCARD > 0 {
                webRTCModel.shouldSendFrame = false
                startSendingTimer = Timer(timeInterval: DURATION_DISCARD, repeats: false) { _ in
                    startSendingFrames()
                }
                RunLoop.current.add(startSendingTimer!, forMode: .common)
            }
            /// The countdown to stop sending frames (~20 seconds)
            stopSendingTimer = Timer(timeInterval: DURATION_SENDING, repeats: false) { _ in
                stopSendingFrames()
            }
            /// The countdown to stop session (~30 seconds): delete all unprocessed frames and ask for a final data from the server
            stopSessionTimer = Timer(timeInterval: DURATION_TOTAL, repeats: false) { _ in
                stopSession()
            }
            RunLoop.current.add(stopSendingTimer!, forMode: .common)
            RunLoop.current.add(stopSessionTimer!, forMode: .common)
        }
    }
    
    private func startSendingFrames() {
        startSendingTimer?.invalidate()
        startSendingTimer = nil
        
        webRTCModel.shouldSendFrame = !DEBUG
        
        logger.debug("ScanningScreen start sending frames \(webRTCModel.shouldSendFrame)")
    }
    
    private func stopSendingFrames() {
        stopSendingTimer?.invalidate()
        stopSendingTimer = nil
        
        webRTCModel.shouldSendFrame = false
        
        logger.debug("ScanningScreen stop sending frames")
    }
    
    private func stopSession() {
        /// Stop the ~20second timer
        stopSendingFrames()

        /// Stop the ~30second timer
        stopSessionTimer?.invalidate()
        stopSessionTimer = nil
        
        /// Disconnect WebRTC
        webRTCModel.endSession(onEnd: {
            logger.debug("ScanningScreen navigating away because an end data is received")
            routeModel.pushReplaceTop(.result)
        })
        
        /// Disconnect scale
        /// (Not really) chances are that the fat is still detecting near the end of 30 seconds
//        Task {
//            try? await qnScaleModel.disconnectDevice()
//        }
        
        logger.debug("ScanningScreen stop session")
    }
}

#Preview {
    ScanningScreen()
        .environment(RouteModel())
        .environment(WebRTCModel())
        .environment(QNScaleModel())
}
