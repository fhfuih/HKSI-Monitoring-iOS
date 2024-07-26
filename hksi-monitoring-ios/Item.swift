//
//  Item.swift
//  hksi-monitoring-ios
//
//  Created by 黄泽宇 on 26/7/2024.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
