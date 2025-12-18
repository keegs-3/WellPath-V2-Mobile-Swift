//
//  AllRecentFoodsView.swift
//  WellPath
//
//  Shows all recent foods with option to select or favorite
//

import SwiftUI

struct AllRecentFoodsView: View {
    @Environment(\.dismiss) var dismiss

    let foods: [FoodSearchResult]
    let isFavorite: (FoodSearchResult) -> Bool
    let onSelect: (FoodSearchResult) -> Void
    let onToggleFavorite: (FoodSearchResult) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if foods.isEmpty {
                    emptyState
                } else {
                    foodsList
                }
            }
            .navigationTitle("Recent Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Recent Foods")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Foods you log will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var foodsList: some View {
        List {
            ForEach(foods) { food in
                RecentFoodRow(
                    food: food,
                    isFavorite: isFavorite(food),
                    onSelect: { onSelect(food) },
                    onToggleFavorite: { onToggleFavorite(food) }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Recent Food Row

private struct RecentFoodRow: View {
    let food: FoodSearchResult
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.displayName)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(food.displayCategory)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let calories = food.calories {
                                Text("• \(Int(calories)) cal/100g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(isFavorite ? .yellow : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AllRecentFoodsView(
        foods: [],
        isFavorite: { _ in false },
        onSelect: { _ in },
        onToggleFavorite: { _ in }
    )
}
