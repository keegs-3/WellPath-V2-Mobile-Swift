//
//  VegetablesDataManagementView.swift
//  WellPath
//
//  Data management view for Vegetables.
//  Uses shared MetricDataManagementView with vegetables configuration.
//

import SwiftUI

struct VegetablesDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .vegetables(color: color))
    }
}

#Preview {
    VegetablesDataManagementView(color: .green)
}
