//
//  TobaccoDataManagementView.swift
//  WellPath
//
//  Data management view for Tobacco entries
//

import SwiftUI

struct TobaccoDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .tobacco(color: color))
    }
}

#Preview {
    TobaccoDataManagementView(color: .mint)
}
