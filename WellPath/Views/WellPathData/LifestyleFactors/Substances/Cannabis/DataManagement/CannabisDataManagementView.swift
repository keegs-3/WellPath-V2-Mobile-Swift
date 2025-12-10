//
//  CannabisDataManagementView.swift
//  WellPath
//
//  Data management view for Cannabis entries
//

import SwiftUI

struct CannabisDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .cannabis(color: color))
    }
}

#Preview {
    CannabisDataManagementView(color: .green)
}
