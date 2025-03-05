//
//  Features.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 13/4/2024.
//

import SwiftUI

enum FeatureType {
    case hr, mood, body, skin
}

enum FeatureIconVariant {
    case still, rotating, noBorder
}

extension FeatureType {
    var title: String {
        switch self {
        case .hr:
//            "Heart Rate & HRV"
            "Heart Rate"
        case .mood:
            "Moods"
        case .body:
            "Body Fat"
        case .skin:
            "Skin Conditions"
        }
    }
    var icon: Image {
        switch self {
        case .hr:
            Image("heartbeat")
        case .mood:
            Image("mood-search")
        case .body:
            Image("run")
        case .skin:
            Image("lego")
        }
    }
    var lightColor: Color {
        switch self {
        case .hr:
            Color("MagentaLight")
        case .mood:
            Color("YellowLight")
        case .body:
            Color("GreenLight")
        case .skin:
            Color("BlueLight")
        }
    }
    var fgColor: Color {
        switch self {
        case .hr:
            Color("MagentaMain")
        case .mood:
            Color("YellowMain")
        case .body:
            Color("GreenMain")
        case .skin:
            Color("BlueMain")
        }
    }
}
