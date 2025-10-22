//
//  DashboardView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Pillar Chart Section
                    PillarChartCard()

                    // Quick Stats
                    Text("Quick Stats")
                        .font(.headline)

                    // Recent Activity
                    Text("Recent Activity")
                        .font(.headline)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
