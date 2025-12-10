//
//  SubstanceSharedViews.swift
//  WellPath
//
//  Shared models and views for substance tracking
//

import SwiftUI

// MARK: - Shared Entry Model

struct SubstanceEntry: Identifiable {
    let id: UUID
    let value: Double
    let recordedAt: Date
    let source: String
    let createdAt: Date
}

// MARK: - Entry Row View

struct SubstanceEntryRow: View {
    let entry: SubstanceEntry
    let icon: String
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(entry.value))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(formatTime(entry.recordedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.95), Color(white: 0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 24, height: 24)

            Image("black_green")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
        .frame(width: 24, height: 24)
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SubstanceEntryRow(
        entry: SubstanceEntry(
            id: UUID(),
            value: 3,
            recordedAt: Date(),
            source: "manual_entry",
            createdAt: Date()
        ),
        icon: "wineglass",
        unit: "drinks"
    )
    .padding()
}
