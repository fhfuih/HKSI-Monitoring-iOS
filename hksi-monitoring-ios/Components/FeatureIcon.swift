//
//  FeatureIcon.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 7/4/2024.
//

import SwiftUI

struct FeatureIcon: View {
    var feature: FeatureType
    
    var variant: FeatureIconVariant
    
    
    var body: some View {
        ZStack {
            IconCircle(variant: variant, color: feature.lightColor)
//                .containerRelativeFrame([.horizontal, .vertical])
                .padding(.all, 5)
            feature.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(feature.fgColor)
                .padding(.all, 15)
//                .containerRelativeFrame([.horizontal, .vertical]) { dim, _ in
//                    dim * 0.7
//                }
        }
        .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, maxHeight: .infinity)
    }
}

#Preview("HR", traits: .fixedLayout(width: 120, height: 120)) {
    FeatureIcon(feature: .hr, variant: .still)
}
#Preview("Mood", traits: .fixedLayout(width: 120, height: 120)) {
    FeatureIcon(feature: .mood, variant: .still)
}
#Preview("Body", traits: .fixedLayout(width: 120, height: 120)) {
    FeatureIcon(feature: .body, variant: .still)
}
#Preview("Skin", traits: .fixedLayout(width: 120, height: 120)) {
    FeatureIcon(feature: .skin, variant: .still)
}
#Preview("Revolving", traits: .fixedLayout(width: 120, height: 120)) {
    FeatureIcon(feature: .body, variant: .rotating)
}
#Preview("NoBorder", traits: .fixedLayout(width: 120, height: 120)) {
    FeatureIcon(feature: .body, variant: .noBorder)
}

struct IconCircle: View {
    var variant: FeatureIconVariant
    var color: Color

    @State var isRotated = false

    var body: some View {
        switch variant {
        case .still:
            Circle()
                .fill(Color(UIColor.systemBackground))
                .stroke(color, lineWidth: 10)
        case .rotating:
//            TimelineView(.animation) { contenxt in
//                let period = 5.0 // seconds per full rotation
//                let degrees = context.date
//                    .timeIntervalSinceReferenceDate
//                    .remainder(dividingBy: period) * 360 / period
//                Circle()
//                    .fill(Color(UIColor.systemBackground))
//                    .stroke(
//                        AngularGradient(gradient: Gradient(
//                            colors: [color, color.opacity(0)]),
//                            center: .center,
//                            startAngle: .zero,
//                            endAngle: .degrees(360)
//                        ),
//                        lineWidth: 10
//                    )
//            }
            Circle()
                .fill(Color(UIColor.systemBackground))
                .stroke(
                    AngularGradient(gradient: Gradient(
                        colors: [color, color.opacity(0)]),
                                    center: .center,
                                    startAngle: .zero,
                                    endAngle: .degrees(360)
                    ),
                    lineWidth: 10
                )
                .rotationEffect(.degrees(isRotated ? 360 : 0))
                .animation(
                    .linear(duration: 5)
                        .repeatForever(autoreverses: false),
                    value: isRotated
                )
                .onAppear {
                    self.isRotated.toggle()
                }
        case .noBorder:
            Circle()
                .fill(Color(UIColor.systemBackground))
        }
    }
}

