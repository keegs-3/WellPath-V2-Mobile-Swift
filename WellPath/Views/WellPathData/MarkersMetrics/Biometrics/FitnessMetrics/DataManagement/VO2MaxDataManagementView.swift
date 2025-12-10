//
//  VO2MaxDataManagementView.swift
//  WellPath
//
//  Data management view for VO2 Max entries
//

import SwiftUI

struct VO2MaxDataManagementView: View {
    let color: Color

    var body: some View {
        SimpleBiometricDataManagementView(
            title: "VO2 Max",
            biometricName: "VO2 Max",
            unit: "mL/kg/min",
            color: color
        )
    }
}

#Preview {
    VO2MaxDataManagementView(color: .green)
}
