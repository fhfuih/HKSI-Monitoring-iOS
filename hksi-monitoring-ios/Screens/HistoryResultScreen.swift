//
//  HistoryResultScreen.swift
//  hksi-monitoring-ios
//
//  Created by chen qiaoyi on 25/3/2025.
//

import SwiftUI
import Charts

struct HistoryResultScreen: View {
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel
    @Environment(RouteModel.self) var routeModel: RouteModel
    @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 50) {
                Grid(horizontalSpacing: 50, verticalSpacing: 50) {
                    GridRow {
                        FeatureSection(feature: .hr) {
                            HRChartView()
                        }
                        FeatureSection(feature: .mood) {
                            FatigueChartView()
                        }
                    }
                    GridRow {
                        FeatureSection(feature: .body) {
                            BodyChartView()
                        }
                        FeatureSection(feature: .skin) {
                            SkinChartView()
                        }
                    }
                }
                .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 0)
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

    // 定义结构体
    struct HRDataPoint: Identifiable {
        let id = UUID()
        let index: Int
        let label: String
        let value: Double
        let isImputed: Bool
        let isLatestReal: Bool
    }
    @ViewBuilder
    func HRChartView() -> some View {
        VStack {
            let rawHRList: [Double?] = [72.0, 76.5, nil, 70.8, 76.0, nil, nil, 72.0, 76.5, nil, 70.8, 76.0, nil, 70.8, 76.0]
//            let rawHRList: [Double?] = [72.0, 76.5]
            
            let data: [HRDataPoint] = {
                var result: [HRDataPoint] = []
                var lastValid: Double? = 65.0
                var lastRealIndex: Int? = nil
                let count = rawHRList.count
                
                for (index, val) in rawHRList.enumerated() {
                    let label = String(index + 1)
                    if let v = val {
                        lastValid = v
                        lastRealIndex = index
                        result.append(HRDataPoint(index: index, label: label, value: v, isImputed: false, isLatestReal: false))
                    } else if let fallback = lastValid {
                        result.append(HRDataPoint(index: index, label: label, value: fallback, isImputed: true, isLatestReal: false))
                    }
                }
                
                if let realIndex = lastRealIndex, realIndex == count - 1 {
                    // 原始最后一个是有效值 → 标记该点为 isLatestReal
                    result = result.map { point in
                        if point.index == realIndex {
                            return HRDataPoint(index: point.index, label: point.label, value: point.value, isImputed: point.isImputed, isLatestReal: true)
                        } else {
                            return point
                        }
                    }
                } else if let lastIndex = result.indices.last {
                    // 否则标记最后一个补值点为 isLatestReal（用于展示 "No Latest Data"）
                    result[lastIndex] = HRDataPoint(
                        index: result[lastIndex].index,
                        label: result[lastIndex].label,
                        value: result[lastIndex].value,
                        isImputed: result[lastIndex].isImputed,
                        isLatestReal: true
                    )
                }
                
                return result
            }()
            
            if data.count >= 2 {
                Text("HR (bpm)")
                    .font(.headline)
                
                Chart {
                    ForEach(data) { point in
                        BarMark(
                            x: .value("Measurement", point.label),
                            y: .value("HR", point.value)
                        )
                        .foregroundStyle(point.isImputed ? Color.gray.opacity(0.35) : Color.blue)
                        
                        if point.isLatestReal && !point.isImputed {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("HR", point.value)
                            )
                            .symbolSize(100)
                            .foregroundStyle(Color.red)
                            .annotation(position: .top) {
                                //                                Text("Latest: \(Int(point.value))")
                                Text("Latest: \(point.value.formatted(.number.precision(.fractionLength(1))))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        } else if point.isLatestReal && point.isImputed {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("HR", point.value)
                            )
                            .symbolSize(0)
                            .foregroundStyle(Color.gray.opacity(0.4))
                            .annotation(position: .top) {
                                Text("No Latest Data")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .padding(.top, 10)
            } else if (data.count == 1) {
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
                
            }
        }
    }
//        VStack {
//            let rawHRList: [Double?] = [72.0, 76.5, nil, 70.8, 76.0, nil, 77.1]
//
//            // 👇 提前处理数据
//            let data: [HRDataPoint] = {
//                var result: [HRDataPoint] = []
//                var lastValid: Double? = nil
//                let count = rawHRList.count
//
//                for (index, val) in rawHRList.enumerated() {
//                    let label = String(index + 1)
//                    let isLast = index == count - 1
//
//                    if let v = val {
//                        lastValid = v
//                        result.append(HRDataPoint(index: index, label: label, value: v, isImputed: false, isLast: isLast))
//                    } else if let fallback = lastValid {
//                        result.append(HRDataPoint(index: index, label: label, value: fallback, isImputed: true, isLast: isLast))
//                    }
//                }
//
//                return result
//            }()
//
//            if data.count >= 2 {
//                Text("HR (bpm)")
//                    .font(.headline)
//
//                Chart {
//                    ForEach(data) { point in
//                        if point.isImputed {
//                            // 外框灰色柱
//                            BarMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("HR", point.value)
//                            )
//                            .foregroundStyle(.gray)
//
//                            // 内部白色覆盖制造空心效果
//                            BarMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("HR", point.value * 0.8) // 稍微短一点
//                            )
//                            .foregroundStyle(.white)
//                        } else {
//                            BarMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("HR", point.value)
//                            )
//                            .foregroundStyle(point.isLast ? .red : .blue)
//                        }
//
//                        if point.isLast {
//                            PointMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("HR", point.value)
//                            )
//                            .annotation(position: .top) {
//                                Text("Latest: \(Int(point.value))")
//                                    .font(.caption)
//                                    .foregroundColor(.red)
//                            }
//                        }
//                    }
//                }
//                .frame(height: 220)
//                .padding(.top, 10)
//            } else if rawHRList.count == 1 {
//                if let hr = webRTCModel.finalValue?.hr {
//                    Text("HR: ")
//                        .font(.system(size: 28, weight: .semibold)) +
//                    Text(hr, format: .number)
//                        .font(.system(size: 40, weight: .bold))
//                } else {
//                    Text("No data")
//                }
//            } else {
//                Text("No data")
//            }
//        }
//        VStack {
//
//            let hrList: [Double] = [72.0, 75.5, 78.2, 74.8, 76.0, 73.3, 77.1]
////                                let hrList: [Double?] = [72.0, 75.5, nil, 74.8, 76.0, 73.3, 77.1]
//            
//            // 判断一下hrList长度，长度为1的时候可以直接按照之前的样子显示
////                                if !hrList.isEmpty {
//            if hrList.count >= 2 {
//                let lastIndex = hrList.count - 1
//                Text("HR (bpm)")
//                    .font(.headline)
//
//                Chart {
//                    ForEach(Array(hrList.enumerated()), id: \.offset) { index, value in
//                        let label = String(index + 1)                // 横轴为 1 ~ 7
//                        let barColor: Color = index == lastIndex ? .red : .blue
//
//                        BarMark(
//                            x: .value("Measurement", label),
//                            y: .value("HR", value)
//                        )
//                        .foregroundStyle(barColor)
//
//                        
//                        // 可选：在最后一项上方加标签
//                        if index == lastIndex {
//                            PointMark(
//                                x: .value("Measurement", label),
//                                y: .value("HR", value)
//                            )
////                                                .foregroundStyle(index == hrList.count - 1 ? Color.red : Color.blue)
//                            .annotation(position: .top) {
//                                Text("Latest: \(Int(value))")
//                                    .font(.caption)
//                                    .foregroundColor(.red)
//                            }
//                        }
//                    }
//                }
//                .frame(height: 220)
//                .padding(.top, 10)
//            } else if (hrList.count == 1) {
//                    let hr = webRTCModel.finalValue?.hr
//                    let hrv = webRTCModel.finalValue?.hrv
//                
//                    if let hr {
//                         Text("HR: ")
//                            .font(.system(size: 28, weight: .semibold)) +
//                         Text(hr, format: .number)
//                            .font(.system(size: 40, weight: .bold))
//                    }
//                
//                    if hr == nil {
//                        Text("No data")
//                    }
//                                                
//                }
//                else {
//                    Text("No data")
//                }
//        }
//    }
    
    struct FatigueDataPoint: Identifiable {
        let id = UUID()
        let index: Int
        let label: String
        let value: Double
        let isImputed: Bool
        let isLast: Bool
    }
    @ViewBuilder
    func FatigueChartView() -> some View {
        VStack {
            let rawFatigueList: [Double?] = [0.5, 0.75, nil, 0.5, 0.75, nil, nil, 0.5, 0.75, nil, 0.5, 0.75, nil, 0.5, 0.75]
            //            let rawFatigueList: [Double?] = [0.5, 0.75]
            //            let rawFatigueList: [Double?] = [0.5]
            
            // 提前处理数据，变成结构化数组
            let data: [FatigueDataPoint] = {
                var result: [FatigueDataPoint] = []
                var lastValid: Double? = 0
                let count = rawFatigueList.count
                
                for (index, val) in rawFatigueList.enumerated() {
                    let label = String(index + 1)
                    let isLast = index == count - 1
                    
                    if let v = val {
                        lastValid = v
                        result.append(FatigueDataPoint(index: index, label: label, value: v, isImputed: false, isLast: isLast))
                    } else if let fallback = lastValid {
                        result.append(FatigueDataPoint(index: index, label: label, value: fallback, isImputed: true, isLast: isLast))
                    }
                }
                
                return result
            }()
            
            if data.count >= 2 {
                Text("Fatigue Level (%)")
                    .font(.headline)
                
                Chart {
                    ForEach(data) { point in
                        // 折线始终连接
                        LineMark(
                            x: .value("Measurement", point.label),
                            y: .value("Fatigue Level", point.value * 100)
                        )
                        .foregroundStyle(point.isImputed ? .gray : .blue)
                        
                        // 数据点：空心灰点 or 蓝实心点
                        if point.isImputed {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Fatigue Level", point.value * 100)
                            )
                            .symbolSize(80)
                            .foregroundStyle(.gray)
                            
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Fatigue Level", point.value * 100)
                            )
                            .symbolSize(30)
                            .foregroundStyle(.white) // 空心中心
                        } else {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Fatigue Level", point.value * 100)
                            )
                            .symbolSize(60)
                            .foregroundStyle(point.isLast ? .red : .blue)
                        }
                        
                        // 最后一个点的注解
                        if point.isLast && !point.isImputed {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Fatigue Level", point.value * 100)
                            )
                            .symbolSize(220)
                            .foregroundStyle(.red)
                            .annotation(position: .top) {
                                Text("Latest: \(Int(point.value * 100))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Fatigue Level", point.value * 100)
                            )
                            .foregroundStyle(.blue)
                        } else if point.isLast {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Fatigue Level", point.value * 100)
                            )
                            .symbolSize(0)
                            .foregroundStyle(Color.gray.opacity(0.4))
                            .annotation(position: .top) {
                                Text("No Latest Data")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .padding(.top, 10)
                .chartYScale(domain: 0...100)
            } else if (data.count == 1) {
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
    }
//            else {
//                Text("Not enough data")
//            }
//        }
//        // 用灰色实心点表示未测试出数据的情况（灰色点的值为上一次测试的结果）
//        VStack {
//            let rawFatigueList: [Double?] = [0.5, 0.75, nil, 0.5, 0.75, nil, 1]
//            
//            // 提前处理数据
//            let data: [FatigueDataPoint] = {
//                var result: [FatigueDataPoint] = []
//                var lastValid: Double? = nil
//                let count = rawFatigueList.count
//                
//                for (index, val) in rawFatigueList.enumerated() {
//                    let label = String(index + 1)
//                    let isLast = index == count - 1
//                    
//                    if let v = val {
//                        lastValid = v
//                        result.append(FatigueDataPoint(index: index, label: label, value: v, isImputed: false, isLast: isLast))
//                    } else if let fallback = lastValid {
//                        result.append(FatigueDataPoint(index: index, label: label, value: fallback, isImputed: true, isLast: isLast))
//                    }
//                }
//                return result
//            }()
//            
//            if data.count >= 2 {
//                Text("Fatigue Level (%)")
//                    .font(.headline)
//                
//                Chart {
//                    ForEach(data) { point in
//                        let color: Color = point.isImputed ? .gray : (point.isLast ? .red : .blue)
//                        
//                        LineMark(
//                            x: .value("Measurement", point.label),
//                            y: .value("Fatigue Level", point.value * 100)
//                        )
//                        .foregroundStyle(color)
//                        
//                        PointMark(
//                            x: .value("Measurement", point.label),
//                            y: .value("Fatigue Level", point.value * 100)
//                        )
//                        .foregroundStyle(color)
//                        
//                        if point.isLast {
//                            PointMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("Fatigue Level", point.value * 100)
//                            )
//                            .symbolSize(220)
//                            .foregroundStyle(.red)
//                            .annotation(position: .top) {
//                                Text("Latest: \(Int(point.value * 100))")
//                                    .font(.caption)
//                                    .foregroundColor(.red)
//                            }
//                            
//                            PointMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("Fatigue Level", point.value * 100)
//                            )
//                            .foregroundStyle(.blue)
//                        }
//                    }
//                }
//                .frame(height: 220)
//                .padding(.top, 10)
//                .chartYScale(domain: 0...100)
//            } else {
//                Text("Not enough data")
//            }
//        }
//        VStack {
//            let fatigueList: [Double?] = [0.5, 0.75, nil, 0.5, 0.75, nil, 1]
//            
//            if fatigueList.compactMap({ $0 }).count >= 2 {
//                let lastIndex = fatigueList.count - 1
//                Text("Fatigue Level (%)")
//                    .font(.headline)
//                
//                Chart {
//                    var lastValid: Double? = nil
//                    
//                    ForEach(Array(fatigueList.enumerated()), id: \.offset) { index, value in
//                        let label = String(index + 1)
//                        let isLast = index == lastIndex
//                        
//                        let actualValue: Double?
//                        let isImputed: Bool
//                        
//                        if let v = value {
//                            actualValue = v
//                            lastValid = v
//                            isImputed = false
//                        } else if let fallback = lastValid {
//                            actualValue = fallback
//                            isImputed = true
//                        } else {
//                            actualValue = nil
//                            isImputed = false
//                        }
//
//                        if let val = actualValue {
//                            LineMark(
//                                x: .value("Measurement", label),
//                                y: .value("Fatigue Level", val * 100)
//                            )
//                            .foregroundStyle(isImputed ? .gray : .blue)
//                            
//                            PointMark(
//                                x: .value("Measurement", label),
//                                y: .value("Fatigue Level", val * 100)
//                            )
//                            .foregroundStyle(isImputed ? .gray : (isLast ? .red : .blue))
//                            
//                            if isLast {
//                                PointMark(
//                                    x: .value("Measurement", label),
//                                    y: .value("Fatigue Level", val * 100)
//                                )
//                                .symbolSize(220)
//                                .foregroundStyle(.red)
//                                .annotation(position: .top) {
//                                    Text("Latest: \(Int(val * 100))")
//                                        .font(.caption)
//                                        .foregroundColor(.red)
//                                }
//
//                                PointMark(
//                                    x: .value("Measurement", label),
//                                    y: .value("Fatigue Level", val * 100)
//                                )
//                                .foregroundStyle(.blue)
//                            }
//                        }
//                    }
//                }
//                .frame(height: 220)
//                .padding(.top, 10)
//                .chartYScale(domain: 0...100)
//            } else if fatigueList.isEmpty {
//                Text("No data")
//            } else {
//                if let fatigue = webRTCModel.finalValue?.fatigue {
//                    VStack {
//                        Text("Fatigue level: ")
//                            .font(.system(size: 28, weight: .semibold))
//                        Text(fatigue, format: .percent)
//                            .font(.system(size: 40, weight: .bold))
//                    }
//                } else {
//                    Text("No data")
//                }
//            }
//        }
        
//        VStack {
//            let fatigueList: [Double] = [0.5, 0.75, 0.5, 0.5, 0.75, 0.5, 1]
//            
//            if fatigueList.count >= 2 {
//                let lastIndex = fatigueList.count - 1
//                Text("Fatigue Level (%)")
//                    .font(.headline)
//                Chart {
//                    // 折线和描点
//                    ForEach(Array(fatigueList.enumerated()), id: \.offset) { index, value in
//                        let label = String(index + 1)
//                        let isLast = index == lastIndex
//                        
//                        LineMark(
//                            x: .value("Measurement", label),
//                            y: .value("Fatigue Level", value * 100)
//                        )
//                        .foregroundStyle(.blue) // 整体线的颜色
//                        
//                        PointMark(
//                            x: .value("Measurement", label),
//                            y: .value("Fatigue Level", value * 100)
//                        )
//                        .foregroundStyle(isLast ? .red : .blue)
//                        
//                        if isLast {
//                            // 为最后一个点加注释
//                            PointMark(
//                                x: .value("Measurement", label),
//                                y: .value("Fatigue Level", value * 100)
//                            )
//                            .symbolSize(220) // 比默认大（默认约为 30）
//                            .foregroundStyle(.red)
//                            .annotation(position: .top) {
//                                Text("Latest: \(Int(value * 100))")
//                                    .font(.caption)
//                                    .foregroundColor(.red)
//                            }
//                            
//                            // 再画小蓝点，覆盖在大红点上方
//                            PointMark(
//                                x: .value("Measurement", label),
//                                y: .value("Fatigue Level", value * 100)
//                            )
//                            //                                            .symbolSize(30)
//                            .foregroundStyle(.blue)
//                        }
//                    }
//                }
//                .frame(height: 220)
//                .padding(.top, 10)
//                .chartYScale(domain: 0...100)
//            } else if fatigueList.isEmpty {
//                Text("No data")
//            } else {
//                if let fatigue = webRTCModel.finalValue?.fatigue {
//                    VStack {
//                        Text("Fatigue level: ")
//                            .font(.system(size: 28, weight: .semibold))
//                        Text(fatigue, format: .percent)
//                            .font(.system(size: 40, weight: .bold))
//                    }
//                } else {
//                    Text("No data")
//                }
//            }
//        }
//    }
    
    
//    struct BodyDataPoint: Identifiable {
//        let id = UUID()
//        let index: Int
//        let label: String
//        let weight: Double
//        let bodyfat: Double
//        let isImputedWeight: Bool
//        let isImputedBodyfat: Bool
//        let isLast: Bool
//    }
//    struct HealthDataPoint {
//        let index: Int
//        let label: String
//        let value: Double
//        let isImputed: Bool
//        let isLast: Bool
//    }
//    
    struct CombinedHealthDataPoint: Identifiable {
        let id = UUID()
        let index: Int
        let label: String
        let weight: Double
        let bodyfat: Double
        let isImputedWeight: Bool
        let isImputedBodyfat: Bool
        let isLast: Bool
    }

    func generateCombinedHealthData(
        rawWeightList: [Double?],
        latestWeight: Double?,
        rawBodyFatList: [Double?],
        latestBodyFat: Double?,
        defaultWeight: Double = 70.0,
        defaultBodyFat: Double = 22.0
    ) -> [CombinedHealthDataPoint] {
        
        // 内部通用处理函数
        func process(rawList: [Double?], latestValue: Double?, defaultValue: Double) -> [(value: Double, isImputed: Bool)] {
            var lastValid: Double? = defaultValue
            let combined = rawList + [latestValue]
            var result: [(Double, Bool)] = []
            
            for val in combined {
                if let v = val {
                    lastValid = v
                    result.append((v, false))
                } else if let fallback = lastValid {
                    result.append((fallback, true))
                }
            }
            return result
        }
        
        let weightData = process(rawList: rawWeightList, latestValue: latestWeight, defaultValue: defaultWeight)
        let bodyFatData = process(rawList: rawBodyFatList, latestValue: latestBodyFat, defaultValue: defaultBodyFat)
        let count = max(weightData.count, bodyFatData.count)
        
        var combinedData: [CombinedHealthDataPoint] = []
        
        for i in 0..<count {
            let weight = i < weightData.count ? weightData[i].value : defaultWeight
            let isImputedWeight = i < weightData.count ? weightData[i].isImputed : true
            
            let bodyfat = i < bodyFatData.count ? bodyFatData[i].value : defaultBodyFat
            let isImputedBodyfat = i < bodyFatData.count ? bodyFatData[i].isImputed : true
            
            combinedData.append(
                CombinedHealthDataPoint(
                    index: i,
                    label: String(i + 1),
                    weight: weight,
                    bodyfat: bodyfat,
                    isImputedWeight: isImputedWeight,
                    isImputedBodyfat: isImputedBodyfat,
                    isLast: i == count - 1
                )
            )
        }
        
        return combinedData
    }
    @ViewBuilder
    func BodyChartView() -> some View {
        VStack {
            let weight = qnScaleModel.finalValue?.weight
            let bodyFat = qnScaleModel.finalValue?.bodyFat
            
//            let rawWeightList =
            
            let rawWeightList: [Double?] = [75.56, nil, 78.11, 75.56, nil, 78.11, 75.56, nil, 78.11, 80.33, 81.00, 85.44, 86.33, 88.21]
            let rawBodyfatList: [Double?] = [nil, nil, 23.3, 22.3, 26.2, nil, 21.6, 23.3, 22.3, 26.2, 21.6, 23.3, 22.3, 26.2]
//            let rawWeightList: [Double?] = []
//            let rawBodyfatList: [Double?] = []

            let data = generateCombinedHealthData(
                rawWeightList: rawWeightList,
                latestWeight: weight,
                rawBodyFatList: rawBodyfatList,
                latestBodyFat: bodyFat
            )
            
            if data.count >= 2 {
                Text("Weight (kg) & Body Fat (%)")
                    .font(.headline)
                
                Chart {
                    ForEach(data) { point in
                        // MARK: - Weight Line
                        LineMark(
                            x: .value("Measurement", point.label),
                            y: .value("Weight (kg)", point.weight),
                            series: .value("Metric", "Weight")
                        )
                        .foregroundStyle(point.isImputedWeight ? .gray : .blue)
                        
                        if point.isImputedWeight {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Weight (kg)", point.weight)
//                                series: .value("Metric", "Weight")
                            )
                            .symbolSize(80)
                            .foregroundStyle(.gray)
                            
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Weight (kg)", point.weight)
                            )
                            .symbolSize(30)
                            .foregroundStyle(.white)
                        } else {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Weight (kg)", point.weight)
                            )
                            .symbolSize(60)
                            .foregroundStyle(.blue)
                        }
                        
                        if point.isLast && !point.isImputedWeight {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Weight (kg)", point.weight)
                            )
                            .symbolSize(220)
                            .foregroundStyle(.red)
                            .annotation(position: .top) {
                                Text("Latest Weight: \(String(format: "%.1f", point.weight))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Weight (kg)", point.weight)
                            )
                            .symbolSize(60)
                            .foregroundStyle(.blue)
                        } else if point.isLast {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Weight (kg)", point.weight)
                            )
                            .symbolSize(0)
                            .foregroundStyle(Color.gray.opacity(0.4))
                            .annotation(position: .top) {
                                Text("No Latest Weight")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    ForEach(data) { point in
                        // MARK: - Body Fat Line
                        LineMark(
                            x: .value("Measurement", point.label),
                            y: .value("Body Fat (%)", point.bodyfat),
                            series: .value("Metric", "Body Fat")
                        )
                        .foregroundStyle(point.isImputedBodyfat ? .gray : .brown) // 棕黄色（建议在 Assets 加一个颜色）
                        
                        if point.isImputedBodyfat {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Body Fat (%)", point.bodyfat)
                            )
                            .symbolSize(80)
                            .foregroundStyle(.gray)
                            
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Body Fat (%)", point.bodyfat)
                            )
                            .symbolSize(30)
                            .foregroundStyle(.white)
                        } else {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Body Fat (%)", point.bodyfat)
                            )
                            .symbolSize(60)
                            .foregroundStyle(.brown)
                        }
                        
                        if point.isLast && !point.isImputedBodyfat {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Body Fat (%)", point.bodyfat)
                            )
                            .symbolSize(220)
                            .foregroundStyle(.red)
                            .annotation(position: .top) {
                                Text("Latest Body Fat: \(String(format: "%.1f", point.bodyfat))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Body Fat (%)", point.bodyfat)
                            )
                            .symbolSize(60)
                            .foregroundStyle(.brown)
                        } else if point.isLast {
                            PointMark(
                                x: .value("Measurement", point.label),
                                y: .value("Body Fat (%)", point.bodyfat)
                            )
                            .symbolSize(0)
                            .foregroundStyle(Color.gray.opacity(0.4))
                            .annotation(position: .top) {
                                Text("No Latest Body Fat")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .padding(.top, 10)
                .chartYScale(domain: 0...100)
            }


//            let data: [BodyDataPoint] = {
//                var result: [BodyDataPoint] = []
//                var lastWeight: Double? = nil
//                var lastBodyfat: Double? = nil
//                let count = min(rawWeightList.count, rawBodyfatList.count)
//                
//                for index in 0..<count {
//                    let label = String(index + 1)
//                    let isLast = index == count - 1
//                    
//                    var weightVal: Double = 0
//                    var bodyfatVal: Double = 0
//                    var imputedWeight = false
//                    var imputedBodyfat = false
//                    
//                    if let w = rawWeightList[index] {
//                        weightVal = w
//                        lastWeight = w
//                    } else if let fallback = lastWeight {
//                        weightVal = fallback
//                        imputedWeight = true
//                    }
//                    
//                    if let b = rawBodyfatList[index] {
//                        bodyfatVal = b
//                        lastBodyfat = b
//                    } else if let fallback = lastBodyfat {
//                        bodyfatVal = fallback
//                        imputedBodyfat = true
//                    }
//                    
//                    result.append(BodyDataPoint(
//                        index: index,
//                        label: label,
//                        weight: weightVal,
//                        bodyfat: bodyfatVal,
//                        isImputedWeight: imputedWeight,
//                        isImputedBodyfat: imputedBodyfat,
//                        isLast: isLast
//                    ))
//                }
//                return result
//            }()
//            if data.count >= 2 {
//                Text("Body Fat")
//                    .font(.headline)
//
//                Chart {
//                    // 画 Weight 线
//                    ForEach(data) { point in
//                        LineMark(
//                            x: .value("Measurement", point.label),
//                            y: .value("Weight (kg)", point.weight)
//                        )
//                        .foregroundStyle(.blue)
//                        .lineStyle(StrokeStyle(lineWidth: 2))
//
//                        PointMark(
//                            x: .value("Measurement", point.label),
//                            y: .value("Weight (kg)", point.weight)
////                            series: .value("Metric", "Weight")
//                        )
//                        .symbolSize(50)
//                        .foregroundStyle(point.isImputedWeight ? .gray : .blue)
//
//                        if point.isLast {
//                            PointMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("Weight (kg)", point.weight)
//                            )
//                            .symbolSize(200)
//                            .foregroundStyle(.blue)
//                            .annotation(position: .top) {
//                                Text("Latest Weight: \(String(format: "%.1f", point.weight))kg")
//                                    .font(.caption)
//                                    .foregroundColor(.blue)
//                            }
//                        }
//                    }
//
//                    // 画 Body Fat 线
//                    ForEach(data) { point in
//                        LineMark(
//                            x: .value("Measurement", point.label),
//                            y: .value("Body Fat (%)", point.bodyfat)
//                        )
//                        .foregroundStyle(.green)
//                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
//
//                        PointMark(
//                            x: .value("Measurement", point.label),
//                            y: .value("Body Fat (%)", point.bodyfat)
//                        )
//                        .symbolSize(50)
//                        .foregroundStyle(point.isImputedBodyfat ? .gray : .green)
//
//                        if point.isLast {
//                            PointMark(
//                                x: .value("Measurement", point.label),
//                                y: .value("Body Fat (%)", point.bodyfat)
//                            )
//                            .symbolSize(200)
//                            .foregroundStyle(.green)
//                            .annotation(position: .top) {
//                                Text("Latest Body Fat: \(String(format: "%.1f", point.bodyfat))%")
//                                    .font(.caption)
//                                    .foregroundColor(.green)
//                            }
//                        }
//                    }
//                }
//                .frame(height: 250)
//                .padding(.top, 10)
//                .chartYScale(domain: 0...100)
//            }
            else {
//                Text("Not enough data")
                if let weight {
    //                                    bodyDataDict["Weight"] = weight
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
    //                                    bodyDataDict["Body Fat"] = bodyFat
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
        .onAppear{
            let weight = qnScaleModel.finalValue?.weight
            let bodyFat = qnScaleModel.finalValue?.bodyFat
            
            if weight == nil && bodyFat == nil {
                logger.debug("No bady data needs to send to backend")
                webRTCModel.sendBodyData(weightData: 60.32, bodyfatData: 22.3)
            } else{
                if bodyFat == nil{
                    webRTCModel.sendWeightData(weightData: weight)
                    logger.debug("No badyfat data needs to send to backend, only send weight data")
                }
                else{
                    webRTCModel.sendBodyData(weightData: weight, bodyfatData: bodyFat)
                    logger.debug("Send weight and bodyfat data to backend")
                }
            }
        }
    }

    
//    @ViewBuilder
//    func BodyChartView() -> some View {
//        VStack {
//            let weight = qnScaleModel.finalValue?.weight
//            let bodyFat = qnScaleModel.finalValue?.bodyFat
//            
////                                if weight == nil && bodyFat == nil {
////                                    logger.debug("No bady data needs to send to backend")
////                                } else{
////                                    if bodyFat == nil{
////                                        webRTCModelSend.sendWeightData(weightData: weight)
////                                        logger.debug("No badyfat data needs to send to backend, only send weight data")
////                                    }
////                                    else{
////                                        webRTCModelSend.sendBodyData(weightData: weight, bodyfatData: bodyFat)
////                                        logger.debug("Send weight and bodyfat data to backend")
////                                    }
////                                }
//            
////                                var bodyDataDict: [String: Double] = [:]
//
////                                // Update data dictionary outside ViewBuilder
////                                updateBodyDataDict(weight: weight, bodyFat: bodyFat)
//            
//            if let weight {
////                                    bodyDataDict["Weight"] = weight
//                Text("Weight: ")
//                    .font(.system(size: 28, weight: .semibold)) +
//                Text(weight, format: .number)
//                    .font(.system(size: 40, weight: .bold)) +
//                Text("kg")
//                    .font(.system(size: 28, weight: .semibold))
//            } else {
//                Text("Weight: ")
//                    .font(.system(size: 28, weight: .semibold)) +
//                Text("No data")
//                    .font(.system(size: 28))
//            }
//            
//            if let bodyFat {
////                                    bodyDataDict["Body Fat"] = bodyFat
//                Text("Body Fat: ")
//                    .font(.system(size: 28, weight: .semibold)) +
////                                    Text(bodyFat, format: .percent)
//                Text(bodyFat, format: .number)
//                    .font(.system(size: 40, weight: .bold)) +
//                Text("%")
//                    .font(.system(size: 28, weight: .semibold))
//            } else {
//                Text("Body Fat: ")
//                    .font(.system(size: 28, weight: .semibold)) +
//                Text("No data")
//                    .font(.system(size: 28))
//            }
////                                webRTCModelSend.sendBodyData(bodyResult: bodyDataDict)
//        }
//        .onAppear{
//            let weight = qnScaleModel.finalValue?.weight
//            let bodyFat = qnScaleModel.finalValue?.bodyFat
//            
//            if weight == nil && bodyFat == nil {
//                logger.debug("No bady data needs to send to backend")
//                webRTCModel.sendBodyData(weightData: 60.32, bodyfatData: 22.3)
//            } else{
//                if bodyFat == nil{
//                    webRTCModel.sendWeightData(weightData: weight)
//                    logger.debug("No badyfat data needs to send to backend, only send weight data")
//                }
//                else{
//                    webRTCModel.sendBodyData(weightData: weight, bodyfatData: bodyFat)
//                    logger.debug("Send weight and bodyfat data to backend")
//                }
//            }
//        }
//    }
    struct HealthDataPoint: Identifiable {
        let id = UUID()
        let index: Int
        let label: String
        let value: Int
        let isImputed: Bool
        let isLatestReal: Bool
    }

    @ViewBuilder
    func SkinChartView() -> some View {
        let rawCircleData = [1, 1, 0, 2, nil, nil, 1, 0, 1, nil, nil, 1, 0, 1, 1]
        let rawPimpleData = [1, 1, 0, 2, nil, nil, 1, 0, 3, nil, nil, 2, 0, 1, 1]
//        let rawCircleData = [1]
//        let rawPimpleData = [2]
        
        if rawCircleData.count >= 2 {
            VStack {
                // Dark Circle 条形图
                HealthChartSection(
                    title: "Dark Circle Count",
                    rawData: rawCircleData,
    //                rawData: [1],
    //                rawData: [nil, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                    defaultValue: 0
                )
                Spacer().frame(height: 20)
                // Pimple 条形图
                HealthChartSection(
                    title: "Pimple Count",
                    rawData: rawPimpleData,
    //                rawData: [1],
                    defaultValue: 0
                )
            }
    //        .frame(height: 220) // 🌟 确保整体大小一致
        }
        else {
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
        }
        

    }
    @ViewBuilder
    func HealthChartSection(title: String, rawData: [Int?], defaultValue: Int) -> some View {
        let data: [HealthDataPoint] = {
            var result: [HealthDataPoint] = []
            var lastValid: Int? = defaultValue
            var lastRealIndex: Int? = nil
            let count = rawData.count
            
            for (index, val) in rawData.enumerated() {
                let label = String(index + 1)
                if var v = val {
//                    if v == 0{
//                        v = 0.02
//                    }
                    lastValid = v
                    lastRealIndex = index
                    result.append(HealthDataPoint(index: index, label: label, value: v, isImputed: false, isLatestReal: false))
                } else if let fallback = lastValid {
                    result.append(HealthDataPoint(index: index, label: label, value: fallback, isImputed: true, isLatestReal: false))
                }
            }
            
            if let realIndex = lastRealIndex, realIndex == count - 1 {
                result = result.map { point in
                    if point.index == realIndex {
                        return HealthDataPoint(index: point.index, label: point.label, value: point.value, isImputed: point.isImputed, isLatestReal: true)
                    } else {
                        return point
                    }
                }
            } else if let lastIndex = result.indices.last {
                result[lastIndex] = HealthDataPoint(
                    index: result[lastIndex].index,
                    label: result[lastIndex].label,
                    value: result[lastIndex].value,
                    isImputed: result[lastIndex].isImputed,
                    isLatestReal: true
                )
            }
            
            return result
        }()
        
        if data.count >= 2 {
            Text(title)
                .font(.headline)
            
            Chart {
                ForEach(data) { point in
                    BarMark(
                        x: .value("Measurement", point.label),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(point.isImputed ? Color.gray.opacity(0.35) : Color.blue)
                    
                    if point.isLatestReal && !point.isImputed {
                        PointMark(
                            x: .value("Measurement", point.label),
                            y: .value(title, point.value)
                        )
                        .symbolSize(100)
                        .foregroundStyle(Color.red)
                        .annotation(position: .top) {
                            Text("Latest: \(point.value.formatted(.number.precision(.fractionLength(0))))")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if point.isLatestReal && point.isImputed {
                        PointMark(
                            x: .value("Measurement", point.label),
                            y: .value(title, point.value)
                        )
                        .symbolSize(0)
                        .foregroundStyle(Color.gray.opacity(0.4))
                        .annotation(position: .top) {
                            Text("No Latest Data")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .frame(height: 100)
//            .padding(.top, -25)
        }
    }

    
//    @ViewBuilder
//    func SkinChartViewOld() -> some View {
//        VStack {
//                 let darkCircleLeft = webRTCModel.finalValue?.darkCircleLeft
//                 let darkCircleRight = webRTCModel.finalValue?.darkCircleRight
//                 let pimpleCount = webRTCModel.finalValue?.pimpleCount
//
//                 if let darkCircleLeft {
//                     Text("Dark circle (left): ")
//                         .font(.system(size: 28, weight: .semibold)) +
//                     Text(darkCircleLeft ? "Yes" : "No")
//                         .font(.system(size: 40, weight: .bold))
//                 }
//                 
//                 if let darkCircleRight {
//                     Text("Dark circle (right): ")
//                         .font(.system(size: 28, weight: .semibold)) +
//                     Text(darkCircleRight ? "Yes" : "No")
//                         .font(.system(size: 40, weight: .bold))
//                 }
//                 Spacer().frame(height: 25)
//                 if let pimpleCount {
//                     Text("Pimple count: ")
//                         .font(.system(size: 28, weight: .semibold)) +
//                     Text(pimpleCount, format: .number)
//                         .font(.system(size: 40, weight: .bold))
//                 }
//                 
//                 if darkCircleLeft == nil && darkCircleRight == nil && pimpleCount == nil {
//                     Text("No data")
//                 }
//             }
//            .padding(.top, -25)
//    }

    private func finish() {
        webRTCModel.intermediateValue = nil
//        webRTCModel.finalValue = nil
        qnScaleModel.intermediateWeight = nil
//        qnScaleModel.finalValue = nil
        
//        print("Finish result screen 1")
        
        // routeModel.pop() // 原逻辑
        routeModel.pushReplaceTop(.questionnaire) // 新逻辑：跳转到问卷
        
//        print("Finish result screen 2")
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
    HistoryResultScreen()
        .environment(RouteModel())
        .environment(WebRTCModel())
        .environment(QNScaleModel())
}
    

//    var body: some View {
//        VStack(spacing: 20) {
//            HStack(spacing: 50) {
//                Grid(horizontalSpacing: 50, verticalSpacing: 50) {
//                    GridRow {
//                        FeatureSection(feature: .hr) {
//                            VStack {
//
//                                let hrList: [Double?] = [72.0, 75.5, 78.2, 74.8, 76.0, 73.3, 77.1]
////                                let hrList: [Double?] = [72.0, 75.5, nil, 74.8, 76.0, 73.3, 77.1]
//                                
//                                // 判断一下hrList长度，长度为1的时候可以直接按照之前的样子显示
////                                if !hrList.isEmpty {
//                                if hrList.count >= 2 {
//                                    let lastIndex = hrList.count - 1
//                                    Text("HR (bpm)")
//                                        .font(.headline)
//
//                                    Chart {
//                                        ForEach(Array(hrList.enumerated()), id: \.offset) { index, value in
//                                            let label = String(index + 1)                // 横轴为 1 ~ 7
//                                            let barColor: Color = index == lastIndex ? .red : .blue
//
//                                            BarMark(
//                                                x: .value("Measurement", label),
//                                                y: .value("HR", value)
//                                            )
//                                            .foregroundStyle(barColor)
//
//                                            
//                                            // 可选：在最后一项上方加标签
//                                            if index == lastIndex {
//                                                PointMark(
//                                                    x: .value("Measurement", label),
//                                                    y: .value("HR", value)
//                                                )
////                                                .foregroundStyle(index == hrList.count - 1 ? Color.red : Color.blue)
//                                                .annotation(position: .top) {
//                                                    Text("Latest: \(Int(value))")
//                                                        .font(.caption)
//                                                        .foregroundColor(.red)
//                                                }
//                                            }
//                                        }
//                                    }
//                                    .frame(height: 220)
//                                    .padding(.top, 10)
//                                } else if (hrList.count == 1) {
//                                        let hr = webRTCModel.finalValue?.hr
//                                        let hrv = webRTCModel.finalValue?.hrv
//                                    
//                                        if let hr {
//                                             Text("HR: ")
//                                                .font(.system(size: 28, weight: .semibold)) +
//                                             Text(hr, format: .number)
//                                                .font(.system(size: 40, weight: .bold))
//                                        }
//                                    
//                                        if hr == nil {
//                                            Text("No data")
//                                        }
//                                                                    
//                                    }
//                                    else {
//                                        Text("No data")
//                                    }
//                            }
//                        }
//                        FeatureSection(feature: .mood) {
//                            VStack {
//                                let fatigueList: [Double?] = [0.5, 0.75, 0.5, 0.5, 0.75, 0.5, 1]
//                                
//                                if fatigueList.count >= 2 {
//                                    let lastIndex = fatigueList.count - 1
//                                    Text("Fatigue Level (%)")
//                                        .font(.headline)
//                                    Chart {
//                                        // 折线和描点
//                                        ForEach(Array(fatigueList.enumerated()), id: \.offset) { index, value in
//                                            let label = String(index + 1)
//                                            let isLast = index == lastIndex
//                                            
//                                            LineMark(
//                                                x: .value("Measurement", label),
//                                                y: .value("Fatigue Level", value * 100)
//                                            )
//                                            .foregroundStyle(.blue) // 整体线的颜色
//                                            
//                                            PointMark(
//                                                x: .value("Measurement", label),
//                                                y: .value("Fatigue Level", value * 100)
//                                            )
//                                            .foregroundStyle(isLast ? .red : .blue)
//                                            
//                                            if isLast {
//                                                // 为最后一个点加注释
//                                                PointMark(
//                                                    x: .value("Measurement", label),
//                                                    y: .value("Fatigue Level", value * 100)
//                                                )
//                                                .symbolSize(220) // 比默认大（默认约为 30）
//                                                .foregroundStyle(.red)
//                                                .annotation(position: .top) {
//                                                    Text("Latest: \(Int(value * 100))")
//                                                        .font(.caption)
//                                                        .foregroundColor(.red)
//                                                }
//                                                
//                                                // 再画小蓝点，覆盖在大红点上方
//                                                PointMark(
//                                                    x: .value("Measurement", label),
//                                                    y: .value("Fatigue Level", value * 100)
//                                                )
//                                                //                                            .symbolSize(30)
//                                                .foregroundStyle(.blue)
//                                            }
//                                        }
//                                    }
//                                    .frame(height: 220)
//                                    .padding(.top, 10)
//                                    .chartYScale(domain: 0...100)
//                                    //                                Chart {
//                                    //                                    ForEach(Array(fatigueList.enumerated()), id: \.offset) { index, value in
//                                    //                                        let label = String(index + 1)
//                                    //                                        let barColor: Color = index == lastIndex ? .red : .blue
//                                    //                                        BarMark(
//                                    //                                            x: .value("Measurement", label),
//                                    //                                            y: .value("Fatigue Level", value * 100)
//                                    //                                        )
//                                    //                                        .foregroundStyle(barColor)
//                                    //
//                                    //                                        // 可选：在最后一项上方加标签
//                                    //                                        if index == lastIndex  {
//                                    //                                            PointMark(
//                                    //                                                x: .value("Measurement", label),
//                                    //                                                y: .value("Fatigue Level", value * 100)
//                                    //                                            )
//                                    ////                                           .foregroundStyle(barColor)
//                                    //                                            .annotation(position: .top) {
//                                    //                                                Text("Latest: \(Int(value * 100))")
//                                    //                                                    .font(.caption)
//                                    //                                                    .foregroundColor(.red)
//                                    //                                            }
//                                    //                                        }
//                                    //                                    }
//                                    //                                }
//                                    //                                .frame(height: 220)
//                                    //                                .padding(.top, 10)
//                                } else if fatigueList.isEmpty {
//                                    Text("No data")
//                                } else {
//                                    if let fatigue = webRTCModel.finalValue?.fatigue {
//                                        VStack {
//                                            Text("Fatigue level: ")
//                                                .font(.system(size: 28, weight: .semibold))
//                                            Text(fatigue, format: .percent)
//                                                .font(.system(size: 40, weight: .bold))
//                                        }
//                                    } else {
//                                        Text("No data")
//                                    }
//                                }
//                            }
//                        }
//                    }
//                    GridRow {
//                        FeatureSection(feature: .body) {
//                            VStack {
//                                let weight = qnScaleModel.finalValue?.weight
//                                let bodyFat = qnScaleModel.finalValue?.bodyFat
//                                
////                                if weight == nil && bodyFat == nil {
////                                    logger.debug("No bady data needs to send to backend")
////                                } else{
////                                    if bodyFat == nil{
////                                        webRTCModelSend.sendWeightData(weightData: weight)
////                                        logger.debug("No badyfat data needs to send to backend, only send weight data")
////                                    }
////                                    else{
////                                        webRTCModelSend.sendBodyData(weightData: weight, bodyfatData: bodyFat)
////                                        logger.debug("Send weight and bodyfat data to backend")
////                                    }
////                                }
//                                
////                                var bodyDataDict: [String: Double] = [:]
//
////                                // Update data dictionary outside ViewBuilder
////                                updateBodyDataDict(weight: weight, bodyFat: bodyFat)
//                                
//                                if let weight {
////                                    bodyDataDict["Weight"] = weight
//                                    Text("Weight: ")
//                                        .font(.system(size: 28, weight: .semibold)) +
//                                    Text(weight, format: .number)
//                                        .font(.system(size: 40, weight: .bold)) +
//                                    Text("kg")
//                                        .font(.system(size: 28, weight: .semibold))
//                                } else {
//                                    Text("Weight: ")
//                                        .font(.system(size: 28, weight: .semibold)) +
//                                    Text("No data")
//                                        .font(.system(size: 28))
//                                }
//                                
//                                if let bodyFat {
////                                    bodyDataDict["Body Fat"] = bodyFat
//                                    Text("Body Fat: ")
//                                        .font(.system(size: 28, weight: .semibold)) +
////                                    Text(bodyFat, format: .percent)
//                                    Text(bodyFat, format: .number)
//                                        .font(.system(size: 40, weight: .bold)) +
//                                    Text("%")
//                                        .font(.system(size: 28, weight: .semibold))
//                                } else {
//                                    Text("Body Fat: ")
//                                        .font(.system(size: 28, weight: .semibold)) +
//                                    Text("No data")
//                                        .font(.system(size: 28))
//                                }
////                                webRTCModelSend.sendBodyData(bodyResult: bodyDataDict)
//                            }
//                            .onAppear{
//                                let weight = qnScaleModel.finalValue?.weight
//                                let bodyFat = qnScaleModel.finalValue?.bodyFat
//                                
//                                if weight == nil && bodyFat == nil {
//                                    logger.debug("No bady data needs to send to backend")
//                                    webRTCModel.sendBodyData(weightData: 60.32, bodyfatData: 22.3)
//                                } else{
//                                    if bodyFat == nil{
//                                        webRTCModel.sendWeightData(weightData: weight)
//                                        logger.debug("No badyfat data needs to send to backend, only send weight data")
//                                    }
//                                    else{
//                                        webRTCModel.sendBodyData(weightData: weight, bodyfatData: bodyFat)
//                                        logger.debug("Send weight and bodyfat data to backend")
//                                    }
//                                }
//                            }
//
//                        }
//                        FeatureSection(feature: .skin) {
//                            VStack {
//                                     let darkCircleLeft = webRTCModel.finalValue?.darkCircleLeft
//                                     let darkCircleRight = webRTCModel.finalValue?.darkCircleRight
//                                     let pimpleCount = webRTCModel.finalValue?.pimpleCount
//
//                                     if let darkCircleLeft {
//                                         Text("Dark circle (left): ")
//                                             .font(.system(size: 28, weight: .semibold)) +
//                                         Text(darkCircleLeft ? "Yes" : "No")
//                                             .font(.system(size: 40, weight: .bold))
//                                     }
//                                     
//                                     if let darkCircleRight {
//                                         Text("Dark circle (right): ")
//                                             .font(.system(size: 28, weight: .semibold)) +
//                                         Text(darkCircleRight ? "Yes" : "No")
//                                             .font(.system(size: 40, weight: .bold))
//                                     }
//                                     Spacer().frame(height: 25)
//                                     if let pimpleCount {
//                                         Text("Pimple count: ")
//                                             .font(.system(size: 28, weight: .semibold)) +
//                                         Text(pimpleCount, format: .number)
//                                             .font(.system(size: 40, weight: .bold))
//                                     }
//                                     
//                                     if darkCircleLeft == nil && darkCircleRight == nil && pimpleCount == nil {
//                                         Text("No data")
//                                     }
//                                 }
//                                .padding(.top, -25)
////                            VStack {
////                                let darkCirclesCount = webRTCModel.finalValue?.darkCircles?.count
////                                let pimpleCount = webRTCModel.finalValue?.pimples?.count
////
////                                if let darkCirclesCount {
////                                    Text("Dark circles around eyes: ")
////                                        .font(.system(size: 28, weight: .semibold))
////                                    Text(darkCirclesCount, format: .percent)
////                                        .font(.system(size: 40, weight: .bold))
////                                }
////
////                                if let pimpleCount {
////                                    Text("Pimples: ")
////                                        .font(.system(size: 28, weight: .semibold))
////                                    Text(pimpleCount, format: .percent)
////                                        .font(.system(size: 40, weight: .bold))
////                                }
////
////                                if darkCirclesCount == nil && pimpleCount == nil {
////                                    Text("No data")
////                                }
////                            }
//                        }
//                    }
//                }
//                .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 0)
//                
////                VStack(alignment: .center, spacing: 20) {
////                    Text("TBD: portal to historical data and long-term data analysis.")
////                }
//            }
//            
//            Button(action: finish) {
//                Text("Finish")
//                    .font(.system(size: 28, weight: .bold))
//                    .padding(.all)
//                    .foregroundStyle(.white)
//                    .containerRelativeFrame(.horizontal, count: 3, spacing: 0, alignment: .center)
//                    .background(RoundedRectangle(cornerRadius: 50).fill(.navy))
//                    .cornerRadius(50)
//            }
//        }
//        .toolbar(.hidden)
//        
//
//    }
//    
////    // Separate function to update the dictionary
////    private func updateBodyDataDict(weight: Double?, bodyFat: Double?) {
////        var newDict: [String: Double] = [:]
////        if let weight = weight {
////            newDict["Weight"] = weight
////        }
////        if let bodyFat = bodyFat {
////            newDict["Body Fat"] = bodyFat
////        }
////        bodyDataDict = newDict
////    }
////
////    private func sendBodyData() {
////        do {
////            webRTCModelSend.sendBodyData(bodyResult: bodyDataDict)
////        } catch {
////            logger.error("Failed to submit data")
////        }
////    }
    
    

