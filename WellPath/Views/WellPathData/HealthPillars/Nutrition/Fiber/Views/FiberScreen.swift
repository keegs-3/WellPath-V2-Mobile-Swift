//
//  FiberScreen.swift
//  WellPath
//
//  Card-based layout for Fiber metric.
//  Fiber is simple - direct path to chart without type breakdown.
//

import SwiftUI

struct FiberScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Fiber")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card component
                FiberAmountCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Fiber")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            FoodEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .fiber)
        }
    }
}

#Preview {
    NavigationStack {
        FiberScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
