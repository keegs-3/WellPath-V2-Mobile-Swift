//
//  GripStrengthDataManagementView.swift
//  WellPath
//
//  Data management view for Grip Strength entries
//

import SwiftUI

struct GripStrengthDataManagementView: View {
    let color: Color

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "Grip Strength",
            biometricName: "Grip Strength",
            unit: "kg",
            color: color
        )
    }
}

#Preview {
    GripStrengthDataManagementView(color: .orange)
}
