//
//  SleepDurationDetail.swift
//  WellPath
//
//  Detail view for Sleep Duration metric
//  Shows Percentages/Amounts/Comparisons tabs
//

import SwiftUI
import Charts

struct SleepDurationDetail: View {
    let screenId: String
    @State private var selectedTab: DurationTab = .percentages

    enum DurationTab: String, CaseIterable {
        case percentages = "Percentages"
        case amounts = "Amounts"
        case comparisons = "Comparisons"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Tab", selection: $selectedTab) {
                ForEach(DurationTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            ScrollView {
                switch selectedTab {
                case .percentages:
                    Text("Sleep stage percentages by day/week/month - TODO")
                        .padding()
                case .amounts:
                    Text("Time in bed / Time asleep amounts - TODO")
                        .padding()
                case .comparisons:
                    Text("Sleep comparisons over time - TODO")
                        .padding()
                }
            }
        }
        .navigationTitle("Sleep Duration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SleepDurationDetail(screenId: "SCREEN_SLEEP")
    }
}
