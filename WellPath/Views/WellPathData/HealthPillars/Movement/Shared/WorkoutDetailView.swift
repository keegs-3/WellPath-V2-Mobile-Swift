//
//  WorkoutDetailView.swift
//  WellPath
//
//  Detail view for a single workout entry
//  Shows all available data: duration, calories, distance, source, etc.
//

import SwiftUI

struct WorkoutDetailView: View {
    let entry: WorkoutEntry
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var unitService = UnitConversionService.shared
    @State private var showingDeleteAlert = false

    private var categoryColor: Color {
        switch entry.quantityType {
        case "cardio": return .red
        case "strength_training": return .orange
        case "hiit": return .purple
        case "mobility": return .teal
        default: return .blue
        }
    }

    private var categoryIcon: String {
        switch entry.quantityType {
        case "cardio": return "figure.run"
        case "strength_training": return "dumbbell.fill"
        case "hiit": return "bolt.heart.fill"
        case "mobility": return "figure.flexibility"
        default: return "figure.mixed.cardio"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: categoryIcon)
                            .font(.system(size: 36))
                            .foregroundColor(categoryColor)
                    }

                    Text(entry.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(formatDate(entry.startTime))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Main metrics
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    if let duration = entry.durationMinutes {
                        WorkoutMetricCard(
                            value: formatDuration(duration),
                            label: "Duration",
                            icon: "clock.fill",
                            color: categoryColor
                        )
                    }

                    if let calories = entry.caloriesBurned, calories > 0 {
                        WorkoutMetricCard(
                            value: "\(Int(calories))",
                            label: "Calories",
                            icon: "flame.fill",
                            color: .orange
                        )
                    }

                    if let distance = entry.distanceMeters, distance > 0 {
                        WorkoutMetricCard(
                            value: formatDistance(distance),
                            label: "Distance",
                            icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                            color: .green
                        )
                    }
                }
                .padding(.horizontal)

                // Details section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Details")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        WorkoutDetailRow(label: "Type", value: entry.displayName)

                        if let intensity = entry.intensity {
                            WorkoutDetailRow(label: "Intensity", value: intensity.capitalized)
                        }

                        WorkoutDetailRow(label: "Start", value: formatTime(entry.startTime))

                        if let endTime = entry.endTime {
                            WorkoutDetailRow(label: "End", value: formatTime(endTime))
                        }

                        WorkoutDetailRow(label: "Source", value: entry.source?.capitalized ?? "Unknown")
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Workout", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this workout?")
        }
    }

    // MARK: - Formatters

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins) min"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        switch unitService.preferredDistanceUnit {
        case .mi:
            let miles = meters / 1609.344
            if miles >= 0.1 {
                return String(format: "%.1f mi", miles)
            } else {
                let feet = meters * 3.28084
                return String(format: "%.0f ft", feet)
            }
        case .km:
            let km = meters / 1000
            if km >= 0.1 {
                return String(format: "%.1f km", km)
            } else {
                return String(format: "%.0f m", meters)
            }
        }
    }
}

// MARK: - Supporting Views

private struct WorkoutMetricCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

private struct WorkoutDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
