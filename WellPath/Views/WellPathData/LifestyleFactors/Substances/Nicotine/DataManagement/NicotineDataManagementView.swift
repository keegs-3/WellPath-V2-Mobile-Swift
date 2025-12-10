//
//  NicotineDataManagementView.swift
//  WellPath
//
//  Data management view for Nicotine entries
//

import SwiftUI

struct NicotineDataManagementView: View {
    let color: Color

    var body: some View {
        MetricDataManagementView(config: .nicotine(color: color))
    }
}

#Preview {
    NicotineDataManagementView(color: .indigo)
}
