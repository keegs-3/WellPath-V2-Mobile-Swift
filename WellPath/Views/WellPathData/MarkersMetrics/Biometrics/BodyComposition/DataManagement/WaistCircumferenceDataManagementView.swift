//
//  WaistCircumferenceDataManagementView.swift
//  WellPath
//
//  Data management view for Waist Circumference entries
//

import SwiftUI

struct WaistCircumferenceDataManagementView: View {
    let color: Color

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "Waist Circumference",
            biometricName: "Waist Circumference",
            unit: "cm",
            color: color
        )
    }
}

#Preview {
    WaistCircumferenceDataManagementView(color: .orange)
}
