//
//  FeatureSection.swift
//  HKSI Booth
//
//  Created by 黄泽宇 on 13/4/2024.
//

import SwiftUI

struct FeatureSection<Content: View>: View {
    private let feature: FeatureType
    private let content: (() -> Content)?
    
    init(feature: FeatureType) where Content == EmptyView {
        self.feature = feature
        self.content = nil
    }
    
    init(feature: FeatureType, @ViewBuilder content: @escaping () -> Content) {
        self.feature = feature
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                FeatureIcon(feature: feature, variant: .noBorder)
                    .frame(width: 80, height: 80)
                Text(feature.title)
                    .font(.title)
            }
            
            if (content != nil) {
                content!()
                    .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(feature.lightColor)
        .cornerRadius(50)
    }
}


#Preview("FeatureSecion", traits: .fixedLayout(width: 400, height: 500)) {
    FeatureSection(feature: .hr)
}
