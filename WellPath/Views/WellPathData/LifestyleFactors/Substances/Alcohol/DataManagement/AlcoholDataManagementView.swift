//
//  AlcoholDataManagementView.swift
//  WellPath
//
//  Data management view for Alcohol entries
//

import SwiftUI

struct AlcoholDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .alcohol(color: color))
    }
}

#Preview {
    AlcoholDataManagementView(color: .orange)
}
