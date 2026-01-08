//
//  TherapeuticTimingCard.swift
//  WellPath
//
//  Clean grouped timing toggles in a 2x2 grid layout.
//  Includes "with food" toggle and special instructions.
//  Displays timing guidance pre-fill from database.
//

import SwiftUI

struct TherapeuticTimingCard: View {
    @Binding var morning: Bool
    @Binding var midday: Bool
    @Binding var evening: Bool
    @Binding var bedtime: Bool
    @Binding var withFood: Bool
    @Binding var instructions: String
    let color: Color
    let timingGuidance: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("When to Take")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Time of day grid (2x2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                TimingToggleButton(
                    label: "Morning",
                    icon: "sun.max.fill",
                    isOn: $morning,
                    color: .orange
                )
                TimingToggleButton(
                    label: "Midday",
                    icon: "sun.min.fill",
                    isOn: $midday,
                    color: .yellow
                )
                TimingToggleButton(
                    label: "Evening",
                    icon: "sunset.fill",
                    isOn: $evening,
                    color: .blue
                )
                TimingToggleButton(
                    label: "Bedtime",
                    icon: "moon.fill",
                    isOn: $bedtime,
                    color: .purple
                )
            }

            // With food toggle (styled row)
            HStack {
                Image(systemName: "fork.knife")
                    .font(.system(size: 16))
                    .foregroundColor(withFood ? color : .secondary)
                    .frame(width: 24)

                Text("Take with food")
                    .font(.subheadline)

                Spacer()

                Toggle("", isOn: $withFood)
                    .labelsHidden()
                    .tint(color)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)

            // Special instructions
            TextField("Special instructions (optional)", text: $instructions, axis: .vertical)
                .lineLimit(2...3)
                .font(.subheadline)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)

            // Pre-fill hint from DB
            if let guidance = timingGuidance, !guidance.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text(guidance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Timing Toggle Button

struct TimingToggleButton: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isOn ? color : .secondary)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .foregroundColor(isOn ? .primary : .secondary)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isOn ? color : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isOn ? color.opacity(0.1) : Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        TherapeuticTimingCard(
            morning: .constant(true),
            midday: .constant(false),
            evening: .constant(false),
            bedtime: .constant(false),
            withFood: .constant(false),
            instructions: .constant(""),
            color: .green,
            timingGuidance: nil
        )

        TherapeuticTimingCard(
            morning: .constant(true),
            midday: .constant(true),
            evening: .constant(false),
            bedtime: .constant(false),
            withFood: .constant(true),
            instructions: .constant("Take 30 minutes before meals"),
            color: .purple,
            timingGuidance: "Best absorbed on an empty stomach. Take at least 30 minutes before breakfast."
        )
    }
    .padding()
}
