//
//  WorkoutMiniCard.swift
//  WellPath
//
//  Mini card view for workout duration metrics
//  Shows last workout value with date, and 7-day spark chart with day labels
//  Matches ProteinAmountMiniCard style
//

import SwiftUI

struct WorkoutMiniCard: View {
    let category: String
    let color: Color
    let icon: String

    @StateObject private var loader: WorkoutDurationLoader

    private let calendar = Calendar.current

    init(category: String, color: Color, icon: String) {
        self.category = category
        self.color = color
        self.icon = icon
        _loader = StateObject(wrappedValue: WorkoutDurationLoader(category: category))
    }

    // Max value for bar height normalization
    private var maxValue: Double {
        let values = loader.sparklinePoints.map { $0.durationMinutes }
        let max = values.max() ?? 60
        return max > 0 ? max : 60  // Default to 60 min if no data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if loader.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if loader.totalDuration != nil {
                HStack(spacing: 12) {
                    // Last workout value on left
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loader.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(loader.formattedDuration)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                        }
                    }

                    Spacer()

                    // Mini bar chart on right - 7 calendar days with day labels
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(loader.sparklinePoints, id: \.id) { point in
                            VStack(spacing: 2) {
                                if point.durationMinutes > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(point.isLatest ? color : color.opacity(0.4))
                                        .frame(width: 8, height: barHeight(for: point.durationMinutes))
                                } else {
                                    // Empty indicator for days with no data
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 8, height: 4)
                                }
                                Text(dayInitial(for: point.date))
                                    .font(.system(size: 7))
                                    .foregroundColor(point.isLatest ? color : .secondary)
                            }
                        }
                    }
                    .frame(height: 45)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(categoryName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("No data yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await loader.loadData()
        }
    }

    private var categoryName: String {
        switch category {
        case "cardio": return "Cardio"
        case "strength": return "Strength"
        case "hiit": return "HIIT"
        case "mobility": return "Mobility"
        default: return "Workout"
        }
    }

    private func barHeight(for value: Double) -> CGFloat {
        let normalized = min(value / max(maxValue, 1), 1)
        return 15 + normalized * 25  // 15-40pt range
    }

    private func dayInitial(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
}

#Preview {
    VStack(spacing: 20) {
        WorkoutMiniCard(category: "cardio", color: .red, icon: "figure.run")
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

        WorkoutMiniCard(category: "strength", color: .orange, icon: "dumbbell.fill")
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
    }
    .padding()
}
