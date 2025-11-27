//
//  MarkerContainerRow.swift
//  WellPath
//
//  Container row for displaying biomarker/biometric items
//

import SwiftUI

struct MarkerContainerRow: View {
    let marker: MarkerItem

    private var markerColor: Color {
        marker.isBiometric ? Color(red: 0.2, green: 0.7, blue: 0.95) : Color(red: 0.74, green: 0.56, blue: 0.94)
    }

    private var markerIcon: String {
        marker.isBiometric ? "waveform.path.ecg" : "testtube.2"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left - Score ring with icon
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(CGFloat(marker.itemPercentage) / 100, 0.995))
                    .stroke(markerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Icon in center
                Image(systemName: markerIcon)
                    .font(.system(size: 20))
                    .foregroundColor(markerColor)
            }

            // Middle - Name and score
            VStack(alignment: .leading, spacing: 4) {
                Text(marker.itemDisplayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text("\(Int(marker.itemPercentage.rounded())) / 100")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Right - Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 12) {
        MarkerContainerRow(marker: MarkerItem(
            pillarName: "Healthful Nutrition",
            itemType: "biomarker",
            biomarkerName: "Vitamin D",
            biometricName: nil,
            itemDisplayName: "Vitamin D",
            itemPercentage: 100,
            itemWeightInPillar: 0.05,
            scoreBand: "Optimal"
        ))

        MarkerContainerRow(marker: MarkerItem(
            pillarName: "Movement + Exercise",
            itemType: "biometric",
            biomarkerName: nil,
            biometricName: "VO2 Max",
            itemDisplayName: "VO2 Max",
            itemPercentage: 75,
            itemWeightInPillar: 0.08,
            scoreBand: "In-Range"
        ))
    }
    .padding()
}
