//
//  SleepDurationDataManagementView.swift
//  WellPath
//
//  Data management view wrapper for Sleep Duration.
//  Delegates to shared SleepDataManagementView.
//

import SwiftUI

struct SleepDurationDataManagementView: View {
    let color: Color

    var body: some View {
        SleepDataManagementView(color: color)
    }
}

#Preview {
    SleepDurationDataManagementView(color: .purple)
}
