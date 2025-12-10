//
//  LegumesDataManagementView.swift
//  WellPath
//
//  Data management view for Legumes.
//  Uses shared MetricDataManagementView with legumes configuration.
//

import SwiftUI

struct LegumesDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .legumes(color: color))
    }
}

#Preview {
    LegumesDataManagementView(color: .green)
}
