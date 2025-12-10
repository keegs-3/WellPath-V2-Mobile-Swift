//
//  PatternOverlay.swift
//  WellPath
//
//  Topographic wave pattern overlay for screen backgrounds.
//  Layer this over gradients for visual interest.
//

import SwiftUI

// MARK: - Topographic Pattern (Wavy Lines)

struct TopographicPattern: View {
    let color: Color
    let opacity: Double
    let lineSpacing: CGFloat
    var fadeStart: CGFloat
    var fadeEnd: CGFloat

    init(
        color: Color = .white,
        opacity: Double = 0.08,
        lineSpacing: CGFloat = 20,
        fadeStart: CGFloat = 0.0,
        fadeEnd: CGFloat = 1.0
    ) {
        self.color = color
        self.opacity = opacity
        self.lineSpacing = lineSpacing
        self.fadeStart = fadeStart
        self.fadeEnd = fadeEnd
    }

    var body: some View {
        Canvas { context, size in
            let totalHeight = size.height * 2
            let lineCount = Int(totalHeight / lineSpacing) + 2

            for i in 0..<lineCount {
                var path = Path()
                let baseY = CGFloat(i) * lineSpacing

                path.move(to: CGPoint(x: 0, y: baseY))

                let segments = Int(size.width / 10)
                for segment in 0...segments {
                    let x = CGFloat(segment) * 10
                    let waveOffset = sin(Double(segment) * 0.3 + Double(i) * 0.5) * 8
                    let y = baseY + CGFloat(waveOffset)
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                let normalizedY = baseY / size.height
                let fadeProgress: Double
                if normalizedY <= fadeStart {
                    fadeProgress = 1.0
                } else if normalizedY >= fadeEnd {
                    fadeProgress = 0.0
                } else {
                    fadeProgress = 1.0 - ((normalizedY - fadeStart) / (fadeEnd - fadeStart))
                }

                let easedFade = fadeProgress * fadeProgress * (3 - 2 * fadeProgress)
                let lineOpacity = opacity * easedFade

                if lineOpacity > 0.001 {
                    context.stroke(path, with: .color(color.opacity(lineOpacity)), lineWidth: 1)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        TopographicPattern(color: .white, opacity: 0.12, fadeStart: 0.2, fadeEnd: 0.85)
    }
    .frame(height: 200)
    .cornerRadius(12)
    .padding()
}
