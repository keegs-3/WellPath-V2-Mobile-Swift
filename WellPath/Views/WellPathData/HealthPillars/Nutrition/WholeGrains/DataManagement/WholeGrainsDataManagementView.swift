//
//  WholeGrainsDataManagementView.swift
//  WellPath
//
//  Data management view for Whole Grains.
//  Uses shared MetricDataManagementView with whole grains configuration.
//

import SwiftUI

struct WholeGrainsDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .wholeGrains(color: color))
    }
}

#Preview {
    WholeGrainsDataManagementView(color: .orange)
}
