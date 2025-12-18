//
//  MyFoodsManagementView.swift
//  WellPath
//
//  View for managing user's custom foods - edit and delete
//

import SwiftUI

struct MyFoodsManagementView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var foods: [CustomFood]
    let onDelete: (CustomFood) -> Void
    let onEdit: (CustomFood) -> Void

    @State private var showingDeleteConfirmation = false
    @State private var foodToDelete: CustomFood?

    var body: some View {
        NavigationStack {
            Group {
                if foods.isEmpty {
                    emptyState
                } else {
                    foodsList
                }
            }
            .navigationTitle("My Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Food?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    foodToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let food = foodToDelete {
                        onDelete(food)
                        foodToDelete = nil
                    }
                }
            } message: {
                if let food = foodToDelete {
                    Text("Are you sure you want to delete \"\(food.name)\"? This cannot be undone.")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Custom Foods")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Foods you create will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var foodsList: some View {
        List {
            ForEach(foods) { food in
                CustomFoodRow(
                    food: food,
                    onEdit: { onEdit(food); dismiss() },
                    onDelete: {
                        foodToDelete = food
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Custom Food Row

private struct CustomFoodRow: View {
    let food: CustomFood
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Food info
            VStack(alignment: .leading, spacing: 4) {
                Text(food.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let calories = food.calories {
                        Text("\(Int(calories)) cal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let servingDesc = food.servingDescription {
                        Text("• \(servingDesc)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let grams = food.defaultServingGrams {
                        Text("• \(Int(grams))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Macros row
                if food.proteinG != nil || food.carbsG != nil || food.fatTotalG != nil {
                    HStack(spacing: 8) {
                        if let protein = food.proteinG {
                            Text("P: \(Int(protein))g")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.8))
                        }
                        if let carbs = food.carbsG {
                            Text("C: \(Int(carbs))g")
                                .font(.caption2)
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        if let fat = food.fatTotalG {
                            Text("F: \(Int(fat))g")
                                .font(.caption2)
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MyFoodsManagementView(
        foods: .constant([]),
        onDelete: { _ in },
        onEdit: { _ in }
    )
}
