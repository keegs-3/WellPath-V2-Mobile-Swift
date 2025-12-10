//
//  HeightDataManagementView.swift
//  WellPath
//
//  Data management view for Height entries
//

import SwiftUI

struct HeightDataManagementView: View {
    let color: Color

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "Height",
            biometricName: "Height",
            unit: "cm",
            color: color
        )
    }
}

#Preview {
    HeightDataManagementView(color: .blue)
}
