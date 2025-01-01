//
//  DataModel.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 21/9/2024.
//

import Foundation

//class SkinPrediction: Codable {
//    var count: Int
////    var coordinates: Double
//}

class FramePrediction: Codable {
    var hr: Double?
    var hrv: Double?
    
    var fatigue: Double? /// A 0~100 level of fatigue
    
    var darkCircleLeft: Bool?
    var darkCircleRight: Bool?
    var pimpleCount: Int?
    
    /// Whether it is final or not
    var final: Bool
    
    func updateNilWith(other: FramePrediction) {
        if hr == nil {
            hr = other.hr
        }
        if hrv == nil {
            hrv = other.hrv
        }
        if fatigue == nil {
            fatigue = other.fatigue
        }
        if darkCircleLeft == nil {
            darkCircleLeft = other.darkCircleLeft
        }
        if darkCircleRight == nil {
            darkCircleRight = other.darkCircleRight
        }
        if pimpleCount == nil {
            pimpleCount = other.pimpleCount
        }
//        if darkCircles == nil {
//            darkCircles = other.darkCircles
//        }
//        if pimples == nil {
//            pimples = other.pimples
//        }
    }
}

struct BodyPrediction {
    /// Apart from weight and height (directly from `QNScaleData`),
    /// all other values from `getItem()` is nullable
    var weight: Double /// kg
    var bodyFat: Double? /// %
}
