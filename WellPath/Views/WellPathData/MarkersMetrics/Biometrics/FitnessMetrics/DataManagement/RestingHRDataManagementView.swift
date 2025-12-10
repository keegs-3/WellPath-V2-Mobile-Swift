//
//  RestingHRDataManagementView.swift
//  WellPath
//
//  Data management view for Resting Heart Rate entries
//

import SwiftUI

struct RestingHRDataManagementView: View {
    let color: Color

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "Resting Heart Rate",
            biometricName: "Resting Heart Rate",
            unit: "BPM",
            color: color
        )
    }
}

#Preview {
    RestingHRDataManagementView(color: .red)
}
