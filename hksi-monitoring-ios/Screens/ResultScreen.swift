//
//  ResultScreen.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 16/7/2024.
//

import SwiftUI

struct ResultScreen: View {
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel
    @Environment(RouteModel.self) var routeModel: RouteModel
    @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 50) {
                Grid(horizontalSpacing: 50, verticalSpacing: 50) {
                    GridRow {
                        FeatureSection(feature: .hr) {
                            VStack {
                                let hr = webRTCModel.finalValue?.hr
                                let hrv = webRTCModel.finalValue?.hrv
                                
                                if let hr {
                                    Text("HR: ")
                                        .font(.system(size: 28, weight: .semibold)) +
                                    Text(hr, format: .number)
                                        .font(.system(size: 40, weight: .bold))
                                }
                                
                                if hr == nil {
                                    Text("No data")
                                }
                                
//                                if let hrv {
//                                    Text("HRV: ")
//                                        .font(.system(size: 28, weight: .semibold)) +
//                                    Text(hrv, format: .number)
//                                        .font(.system(size: 40, weight: .bold))
//                                }
                                
//                                if hr == nil && hrv == nil {
//                                    Text("No data")
//                                }
                            }
                        }
                        FeatureSection(feature: .mood) {
                            if let fatigue = webRTCModel.finalValue?.fatigue {
                                VStack {
                                    Text("Fatigue level: ")
                                        .font(.system(size: 28, weight: .semibold))
                                    Text(fatigue, format: .percent)
                                        .font(.system(size: 40, weight: .bold))
                                }
                            } else {
                                Text("No data")
                            }
                        }
                    }
                    GridRow {
                        FeatureSection(feature: .body) {
                            VStack {
                                let weight = qnScaleModel.finalValue?.weight
                                let bodyFat = qnScaleModel.finalValue?.bodyFat
//                                let weight = qnScaleModel.intermediateWeight
                                
                                if let weight {
                                    Text("Weight: ")
                                        .font(.system(size: 28, weight: .semibold)) +
                                    Text(weight, format: .number)
                                        .font(.system(size: 40, weight: .bold)) +
                                    Text("kg")
                                        .font(.system(size: 28, weight: .semibold))
                                } else {
                                    
                                    Text("Weight: ")
                                        .font(.system(size: 28, weight: .semibold)) +
                                    Text("No data")
                                        .font(.system(size: 28))
                                }
                                
                                if let bodyFat {
                                    Text("Body Fat: ")
                                        .font(.system(size: 28, weight: .semibold)) +
//                                    Text(bodyFat, format: .percent)
                                    Text(bodyFat, format: .number)
                                        .font(.system(size: 40, weight: .bold)) +
                                    Text("%")
                                        .font(.system(size: 28, weight: .semibold))
                                } else {
                                    Text("Body Fat: ")
                                        .font(.system(size: 28, weight: .semibold)) +
                                    Text("No data")
                                        .font(.system(size: 28))
                                }
                            }
                        }
                        FeatureSection(feature: .skin) {
                            VStack {
                                     let darkCircleLeft = webRTCModel.finalValue?.darkCircleLeft
                                     let darkCircleRight = webRTCModel.finalValue?.darkCircleRight
                                     let pimpleCount = webRTCModel.finalValue?.pimpleCount

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
                                     Spacer().frame(height: 25)
                                     if let pimpleCount {
                                         Text("Pimple count: ")
                                             .font(.system(size: 28, weight: .semibold)) +
                                         Text(pimpleCount, format: .number)
                                             .font(.system(size: 40, weight: .bold))
                                     }
                                     
                                     if darkCircleLeft == nil && darkCircleRight == nil && pimpleCount == nil {
                                         Text("No data")
                                     }
                                 }
                                .padding(.top, -25)
//                            VStack {
//                                let darkCirclesCount = webRTCModel.finalValue?.darkCircles?.count
//                                let pimpleCount = webRTCModel.finalValue?.pimples?.count
//                                
//                                if let darkCirclesCount {
//                                    Text("Dark circles around eyes: ")
//                                        .font(.system(size: 28, weight: .semibold))
//                                    Text(darkCirclesCount, format: .percent)
//                                        .font(.system(size: 40, weight: .bold))
//                                }
//                                
//                                if let pimpleCount {
//                                    Text("Pimples: ")
//                                        .font(.system(size: 28, weight: .semibold))
//                                    Text(pimpleCount, format: .percent)
//                                        .font(.system(size: 40, weight: .bold))
//                                }
//                                
//                                if darkCirclesCount == nil && pimpleCount == nil {
//                                    Text("No data")
//                                }
//                            }
                        }
                    }
                }
                .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 0)
                
//                VStack(alignment: .center, spacing: 20) {
//                    Text("TBD: portal to historical data and long-term data analysis.")
//                }
            }
            
            Button(action: finish) {
                Text("Finish")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.all)
                    .foregroundStyle(.white)
                    .containerRelativeFrame(.horizontal, count: 3, spacing: 0, alignment: .center)
                    .background(RoundedRectangle(cornerRadius: 50).fill(.navy))
                    .cornerRadius(50)
            }
        }
        .toolbar(.hidden)
    }
    
    private func finish() {
        webRTCModel.intermediateValue = nil
        webRTCModel.finalValue = nil
        qnScaleModel.intermediateWeight = nil
        qnScaleModel.finalValue = nil
        
        print("Finish result screen 1")
        
        // routeModel.pop() // 原逻辑
        routeModel.pushReplaceTop(.questionnaire) // 新逻辑：跳转到问卷
        
        print("Finish result screen 2")
    }
    
//    private func finish() {
//        webRTCModel.intermediateValue = nil
//        webRTCModel.finalValue = nil
//        qnScaleModel.intermediateWeight = nil
//        qnScaleModel.finalValue = nil
//        routeModel.pop()
//    }
}

#Preview {
    ResultScreen()
        .environment(RouteModel())
        .environment(WebRTCModel())
        .environment(QNScaleModel())
}
