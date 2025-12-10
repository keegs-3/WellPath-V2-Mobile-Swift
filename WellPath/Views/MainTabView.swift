//
//  MainTabView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var searchState = WellPathDataSearchState.shared

    var body: some View {
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

            // Quick entry page
            NavigationStack {
                TrackedMetricsEntryView()
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .tag(2)

            NavigationStack {
                TrackedMetricsListView()
            }
            .environmentObject(searchState)
            .tabItem {
                Label("Data", systemImage: "list.bullet.clipboard.fill")
            }
            .tag(3)

            EducationView()
                .tabItem {
                    Label("Education", systemImage: "book.fill")
                }
                .tag(4)
        }
        .tint(.blue)
        .onChange(of: selectedTab) { _, newTab in
            // Deactivate search when leaving Data tab
            if newTab != 3 && searchState.isSearchActive {
                searchState.deactivateSearch()
            }
        }
    }
}

#Preview {
    MainTabView()
}
