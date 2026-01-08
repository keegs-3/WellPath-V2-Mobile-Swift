//
//  CaffeineTimingDistributionCard.swift
//  WellPath
//
//  Card for setting caffeine timing distribution percentages across 4 time windows.
//  Uses text fields for entry. Enforces that percentages sum to 100%.
//

import SwiftUI

struct CaffeineTimingDistributionCard: View {
    @Binding var morningPct: Double
    @Binding var earlyAfternoonPct: Double
    @Binding var lateAfternoonPct: Double
    @Binding var eveningPct: Double
    let color: Color

    private var totalPercentage: Double {
        morningPct + earlyAfternoonPct + lateAfternoonPct + eveningPct
    }

    private var isValid: Bool {
        abs(totalPercentage - 100) < 0.01
    }

    private var validationMessage: String? {
        guard !isValid else { return nil }
        let total = Int(totalPercentage.rounded())
        let diff = 100 - total
        if diff > 0 {
            return "Total: \(total)% (need \(diff)% more)"
        } else {
            return "Total: \(total)% (reduce by \(abs(diff))%)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("When do you typically consume caffeine?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Enter what percentage of your daily caffeine you consume in each time window (must total 100%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Time window entries
            VStack(spacing: 10) {
                TimingTextFieldRow(
                    label: "Morning",
                    timeRange: "4 AM - 12 PM",
                    percentage: $morningPct,
                    color: .green,
                    icon: "sunrise.fill"
                )

                TimingTextFieldRow(
                    label: "Early Afternoon",
                    timeRange: "12 PM - 2 PM",
                    percentage: $earlyAfternoonPct,
                    color: .yellow,
                    icon: "sun.max.fill"
                )

                TimingTextFieldRow(
                    label: "Late Afternoon",
                    timeRange: "2 PM - 6 PM",
                    percentage: $lateAfternoonPct,
                    color: .orange,
                    icon: "sun.haze.fill"
                )

                TimingTextFieldRow(
                    label: "Evening",
                    timeRange: "6 PM - 4 AM",
                    percentage: $eveningPct,
                    color: .red,
                    icon: "moon.fill"
                )
            }

            // Total indicator
            HStack {
                // Sleep impact legend
                HStack(spacing: 12) {
                    impactIndicator(color: .green, label: "Ideal")
                    impactIndicator(color: .yellow, label: "OK")
                    impactIndicator(color: .orange, label: "Avoid")
                    impactIndicator(color: .red, label: "Poor")
                }

                Spacer()

                HStack(spacing: 6) {
                    if isValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }

                    Text(validationMessage ?? "Total: 100%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isValid ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func impactIndicator(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Timing Text Field Row

private struct TimingTextFieldRow: View {
    let label: String
    let timeRange: String
    @Binding var percentage: Double
    let color: Color
    let icon: String

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon with color indicator
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            // Label and time range
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(timeRange)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Text field for percentage entry
            HStack(spacing: 2) {
                TextField("0", text: $textValue)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 40)
                    .focused($isFocused)
                    .onChange(of: textValue) { _, newValue in
                        // Filter to only digits
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            textValue = filtered
                        }
                        // Update binding
                        if let value = Double(filtered) {
                            percentage = min(100, max(0, value))
                        } else if filtered.isEmpty {
                            percentage = 0
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused && textValue.isEmpty {
                            textValue = "0"
                        }
                    }

                Text("%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            textValue = String(Int(percentage.rounded()))
        }
        .onChange(of: percentage) { _, newValue in
            // Only update text if not focused (to avoid interfering with user input)
            if !isFocused {
                textValue = String(Int(newValue.rounded()))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CaffeineTimingDistributionCard(
        morningPct: .constant(80),
        earlyAfternoonPct: .constant(10),
        lateAfternoonPct: .constant(5),
        eveningPct: .constant(5),
        color: .brown
    )
    .padding()
}
