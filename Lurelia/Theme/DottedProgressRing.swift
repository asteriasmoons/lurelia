//
//  DottedProgressRing.swift
//  Lurelia
//

import SwiftUI

struct DottedProgressRing<Center: View>: View {
    let progress: Double
    let size: CGFloat
    let dotCount: Int
    let dotDiameter: CGFloat
    let trackColor: Color
    let fillColor: Color
    @ViewBuilder let center: () -> Center
    
    init(
        progress: Double,
        size: CGFloat = 44,
        dotCount: Int = 24,
        dotDiameter: CGFloat = 3.5,
        trackColor: Color = .white.opacity(0.18),
        fillColor: Color = .white,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.progress = progress
        self.size = size
        self.dotCount = dotCount
        self.dotDiameter = dotDiameter
        self.trackColor = trackColor
        self.fillColor = fillColor
        self.center = center
    }
    
    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
    
    private var filledDotCount: Int {
        Int((clampedProgress * Double(dotCount)).rounded())
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(index < filledDotCount ? fillColor : trackColor)
                    .frame(width: dotDiameter, height: dotDiameter)
                    .offset(y: -(size / 2) + dotDiameter / 2)
                    .rotationEffect(.degrees(Double(index) / Double(dotCount) * 360))
            }
            
            center()
        }
        .frame(width: size, height: size)
    }
}
