//
//  SleepConsistencyDataManagementView.swift
//  WellPath
//
//  Data management view wrapper for Sleep Consistency.
//  Delegates to shared SleepDataManagementView.
//

import SwiftUI

struct SleepConsistencyDataManagementView: View {
    let color: Color

    var body: some View {
        SleepDataManagementView(color: color)
    }
}

#Preview {
    SleepConsistencyDataManagementView(color: .purple)
}
