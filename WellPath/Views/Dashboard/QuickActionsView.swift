//
//  QuickActionsView.swift
//  WellPath
//
//  Quick access menu for pinned data entry forms
//

import SwiftUI

struct QuickActionsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = QuickActionsViewModel()

    // Track which entry form to show
    @State private var showingProteinEntry = false
    @State private var showingFoodEntry = false
    @State private var showingWaterEntry = false
    @State private var showingCaffeineEntry = false

    var body: some View {
        NavigationStack {
            List {
                // Group actions by category
                ForEach(viewModel.actionsByCategory.keys.sorted(), id: \.self) { category in
                    Section(category) {
                        ForEach(viewModel.actionsByCategory[category] ?? []) { action in
                            Button(action: {
                                handleActionTap(action)
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: action.iconName)
                                        .font(.title2)
                                        .foregroundColor(action.color)
                                        .frame(width: 40, height: 40)
                                        .background(action.color.opacity(0.15))
                                        .cornerRadius(8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text(action.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(action: {
                        // TODO: Navigate to settings to manage pinned actions
                    }) {
                        HStack {
                            Image(systemName: "pin.fill")
                            Text("Manage Quick Actions")
                            Spacer()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingProteinEntry) {
            ProteinEntryView()
        }
        .sheet(isPresented: $showingFoodEntry) {
            FoodEntryView()
        }
        .sheet(isPresented: $showingWaterEntry) {
            WaterEntryView()
        }
        .sheet(isPresented: $showingCaffeineEntry) {
            CaffeineEntryView()
        }
    }

    private func handleActionTap(_ action: QuickAction) {
        dismiss()  // Close quick actions menu first

        // Small delay to allow menu to dismiss before showing new sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch action.id {
            case "protein_entry":
                showingProteinEntry = true
            case "food_entry":
                showingFoodEntry = true
            case "water_entry":
                showingWaterEntry = true
            case "caffeine_entry":
                showingCaffeineEntry = true
            default:
                break
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class QuickActionsViewModel: ObservableObject {
    @Published var pinnedActions: [QuickAction] = []
    @Published var actionsByCategory: [String: [QuickAction]] = [:]

    init() {
        loadPinnedActions()
    }

    private func loadPinnedActions() {
        // For now, hardcoded. Later can load from UserDefaults or database
        pinnedActions = [
            QuickAction(
                id: "food_entry",
                title: "Log Food",
                subtitle: "Track meals and snacks",
                iconName: "fork.knife",
                color: Color.green,
                category: "Nutrition"
            ),
            QuickAction(
                id: "protein_entry",
                title: "Log Protein",
                subtitle: "Record protein intake",
                iconName: "fish.fill",
                color: Color(red: 0.2, green: 0.7, blue: 0.4),
                category: "Nutrition"
            ),
            QuickAction(
                id: "water_entry",
                title: "Log Water",
                subtitle: "Track hydration",
                iconName: "drop.fill",
                color: Color(red: 0.3, green: 0.6, blue: 0.9),
                category: "Nutrition"
            ),
            QuickAction(
                id: "caffeine_entry",
                title: "Log Caffeine",
                subtitle: "Coffee, tea, energy drinks",
                iconName: "cup.and.saucer.fill",
                color: Color(red: 0.5, green: 0.3, blue: 0.2),
                category: "Nutrition"
            )
        ]

        // Group actions by category
        actionsByCategory = Dictionary(grouping: pinnedActions, by: { $0.category })
    }
}

// MARK: - Models

struct QuickAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    let category: String
}

#Preview {
    QuickActionsView()
}
