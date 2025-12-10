//
//  BodyFatDataManagementView.swift
//  WellPath
//
//  Data management view for Body Fat entries
//

import SwiftUI

struct BodyFatDataManagementView: View {
    let color: Color
    private let metricId = "DISP_BODYFAT"

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "Body Fat",
            biometricName: BiometricDisplayNames.displayName(for: metricId),
            unit: "%",
            color: color
        )
    }
}

#Preview {
    BodyFatDataManagementView(color: .cyan)
}
