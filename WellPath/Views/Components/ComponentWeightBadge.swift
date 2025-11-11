//
//  ComponentWeightBadge.swift
//  WellPath
//
//  Displays component weight percentage and points earned
//

import SwiftUI

struct ComponentWeightBadge: View {
    let weight: Double // 0.0-1.0
    let pointsEarned: Int
    let maxPoints: Int
    let displayStyle: DisplayStyle

    enum DisplayStyle {
        case percentage  // "72%"
        case points      // "38 points"
        case both        // "72% • 38 points"
    }

    init(weight: Double, pointsEarned: Int, maxPoints: Int, displayStyle: DisplayStyle = .percentage) {
        self.weight = weight
        self.pointsEarned = pointsEarned
        self.maxPoints = maxPoints
        self.displayStyle = displayStyle
    }

    private var weightPercentage: Int {
        Int((weight * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 4) {
            switch displayStyle {
            case .percentage:
                Text("\(weightPercentage)%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

            case .points:
                Text("\(pointsEarned) points")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

            case .both:
                Text("\(weightPercentage)%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("\(pointsEarned) points")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// Compact version for under rings
struct ComponentWeightLabel: View {
    let weight: Double // 0.0-1.0
    let pointsEarned: Int
    let maxPoints: Int

    private var weightPercentage: Int {
        Int((weight * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(weightPercentage)%")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text("\(pointsEarned) of \(maxPoints) pts")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ComponentWeightBadge(weight: 0.72, pointsEarned: 38, maxPoints: 53, displayStyle: .percentage)

        ComponentWeightBadge(weight: 0.72, pointsEarned: 38, maxPoints: 53, displayStyle: .points)

        ComponentWeightBadge(weight: 0.72, pointsEarned: 38, maxPoints: 53, displayStyle: .both)

        Divider()

        ComponentWeightLabel(weight: 0.72, pointsEarned: 38, maxPoints: 53)
    }
    .padding()
}
