//
//  SleepAnalysisDataManagementView.swift
//  WellPath
//
//  Data management view wrapper for Sleep Analysis.
//  Delegates to shared SleepDataManagementView.
//

import SwiftUI

struct SleepAnalysisDataManagementView: View {
    let color: Color

    var body: some View {
        SleepDataManagementView(color: color)
    }
}

#Preview {
    SleepAnalysisDataManagementView(color: .purple)
}
