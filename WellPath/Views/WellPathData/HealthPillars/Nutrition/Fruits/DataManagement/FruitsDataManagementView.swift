//
//  FruitsDataManagementView.swift
//  WellPath
//
//  Data management view for Fruits.
//  Uses shared MetricDataManagementView with fruits configuration.
//

import SwiftUI

struct FruitsDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .fruits(color: color))
    }
}

#Preview {
    FruitsDataManagementView(color: .red)
}
