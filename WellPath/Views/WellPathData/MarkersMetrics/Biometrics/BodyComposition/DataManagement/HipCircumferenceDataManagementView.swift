//
//  HipCircumferenceDataManagementView.swift
//  WellPath
//
//  Data management view for Hip Circumference entries
//

import SwiftUI

struct HipCircumferenceDataManagementView: View {
    let color: Color

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "Hip Circumference",
            biometricName: "Hip Circumference",
            unit: "cm",
            color: color
        )
    }
}

#Preview {
    HipCircumferenceDataManagementView(color: .orange)
}
