//
//  ProteinScreen.swift
//  WellPath
//
//  Card-based layout for Protein metric.
//  Shows 3 cards: Amount, Type, Ratio.
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct ProteinScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components
                ProteinAmountCard(color: color, pillar: pillar)
                ProteinTypeCard(color: color, pillar: pillar)
                ProteinRatioCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Protein")
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
                HStack(spacing: 12) {
                    Button {
                        showingBaseline = true
                    } label: {
                        Image(systemName: "book.fill")
                    }

                    Button {
                        showingEntryForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            FoodEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .protein)
        }
        .sheet(isPresented: $showingBaseline) {
            ProteinBaselineView(color: color)
        }
    }
}

#Preview {
    NavigationStack {
        ProteinScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
