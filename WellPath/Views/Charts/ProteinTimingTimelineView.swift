//
//  ProteinTimingTimelineView.swift
//  WellPath
//
//  Protein-specific timing view (uses generic NutrientTimingTimelineView)
//

import SwiftUI

struct ProteinTimingTimelineView: View {
    let color: Color
    @Binding var showAbout: Bool

    var body: some View {
        NutrientTimingTimelineView(
            nutrientType: .protein,
            color: color,
            showAbout: $showAbout
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showAbout = false

        var body: some View {
            ProteinTimingTimelineView(
                color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"),
                showAbout: $showAbout
            )
        }
    }

    return PreviewWrapper()
}
