//
//  ProteinScreen.swift
//  WellPath
//
//  Card-based layout for Protein metric.
//  Shows 4 cards: Amount, Timing, Type, Ratio.
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct ProteinScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components
                ProteinAmountCard(color: color, pillar: pillar)
                ProteinTimingCard(color: color, pillar: pillar)
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

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .screen,
                    itemId: "SCREEN_PROTEIN",
                    displayName: "Protein",
                    pillar: pillar,
                    cardId: nil,
                    sectionId: "NAV_NUTRITION"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            ProteinEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            ProteinDataManagementView(color: color)
        }
    }
}

#Preview {
    NavigationStack {
        ProteinScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
