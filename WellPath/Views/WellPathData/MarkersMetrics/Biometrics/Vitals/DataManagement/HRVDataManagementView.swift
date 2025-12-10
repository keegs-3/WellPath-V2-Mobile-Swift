//
//  HRVDataManagementView.swift
//  WellPath
//
//  Data management view for HRV entries
//

import SwiftUI

struct HRVDataManagementView: View {
    let color: Color

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "HRV",
            biometricName: "HRV",
            unit: "ms",
            color: color
        )
    }
}

#Preview {
    HRVDataManagementView(color: .purple)
}
