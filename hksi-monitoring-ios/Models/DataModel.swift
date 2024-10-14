//
//  DataModel.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 21/9/2024.
//

import Foundation

class SkinPrediction: Codable {
    var count: Int
//    var coordinates: Double
}

class FramePrediction: Codable {
    var hr: Double?
    var hrv: Double?
    
    var fatigue: Double? /// A 0~1 level of fatigue
    
    var darkCircles: SkinPrediction?
    var pimples: SkinPrediction?
    
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
        if darkCircles == nil {
            darkCircles = other.darkCircles
        }
        if pimples == nil {
            pimples = other.pimples
        }
    }
}

struct BodyPrediction {
    /// Apart from weight and height (directly from `QNScaleData`),
    /// all other values from `getItem()` is nullable
    var weight: Double /// kg
    var bodyFat: Double? /// %
}
