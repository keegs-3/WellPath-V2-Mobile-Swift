//
//  MealClockIcon.swift
//  WellPath
//
//  Clock icon with shaded portion based on typical meal timing
//  Note: This is based on general meal patterns, not specific user data
//

import SwiftUI

struct MealClockIcon: View {
    let mealName: String
    let color: Color
    let size: CGFloat = 32

    // Approximate typical meal times (as fractions of 24-hour day)
    // These are rough estimates, not user-specific
    private var shadedPortion: (start: Double, end: Double) {
        let lowercased = mealName.lowercased()

        if lowercased.contains("breakfast") {
            return (6.0/24.0, 10.0/24.0) // 6am-10am
        } else if lowercased.contains("morning") && lowercased.contains("snack") {
            return (9.0/24.0, 11.0/24.0) // 9am-11am
        } else if lowercased.contains("lunch") {
            return (11.0/24.0, 14.0/24.0) // 11am-2pm
        } else if lowercased.contains("afternoon") && lowercased.contains("snack") {
            return (14.0/24.0, 16.0/24.0) // 2pm-4pm
        } else if lowercased.contains("dinner") {
            return (17.0/24.0, 20.0/24.0) // 5pm-8pm
        } else if lowercased.contains("evening") && lowercased.contains("snack") {
            return (19.0/24.0, 22.0/24.0) // 7pm-10pm
        } else {
            return (0.0, 1.0) // Full day for "Other" or "Unassigned"
        }
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(uiColor: .tertiarySystemGroupedBackground), lineWidth: 2)
                .frame(width: size, height: size)

            // Shaded arc for meal time
            Circle()
                .trim(from: shadedPortion.start, to: shadedPortion.end)
                .stroke(color, lineWidth: 3)
                .frame(width: size - 4, height: size - 4)
                .rotationEffect(.degrees(-90)) // Start from top (12 o'clock)

            // Clock hands (just decorative, not showing actual time)
            Path { path in
                // Hour hand (short)
                path.move(to: CGPoint(x: size/2, y: size/2))
                path.addLine(to: CGPoint(x: size/2, y: size/2 - 6))

                // Minute hand (longer)
                path.move(to: CGPoint(x: size/2, y: size/2))
                path.addLine(to: CGPoint(x: size/2 + 8, y: size/2))
            }
            .stroke(Color.secondary, lineWidth: 1.5)

            // Center dot
            Circle()
                .fill(Color.secondary)
                .frame(width: 3, height: 3)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 20) {
            VStack {
                MealClockIcon(mealName: "Breakfast", color: .green)
                Text("Breakfast")
                    .font(.caption)
            }

            VStack {
                MealClockIcon(mealName: "Lunch", color: .green.opacity(0.7))
                Text("Lunch")
                    .font(.caption)
            }

            VStack {
                MealClockIcon(mealName: "Dinner", color: .green.opacity(0.5))
                Text("Dinner")
                    .font(.caption)
            }
        }
    }
    .padding()
}
