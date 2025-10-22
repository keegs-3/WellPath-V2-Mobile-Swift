//
//  MainTabView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showTrackedMetricsEntry = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.pie.fill")
                    }
                    .tag(0)

                ChallengesView()
                    .tabItem {
                        Label("Challenges", systemImage: "flame.fill")
                    }
                    .tag(1)

                // Placeholder for center + button
                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }
                    .tag(2)

                MetricsView()
                    .tabItem {
                        Label("Metrics", systemImage: "chart.bar.fill")
                    }
                    .tag(3)

                EducationView()
                    .tabItem {
                        Label("Education", systemImage: "book.fill")
                    }
                    .tag(4)
            }
            .accentColor(.blue)

            // Custom + button overlay
            Button(action: {
                showTrackedMetricsEntry = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .systemBackground))
                            .frame(width: 50, height: 50)
                    )
            }
            .offset(y: -25)
            .sheet(isPresented: $showTrackedMetricsEntry) {
                TrackedMetricsEntryView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
