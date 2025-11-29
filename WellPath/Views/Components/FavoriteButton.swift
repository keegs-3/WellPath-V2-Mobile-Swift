//
//  FavoriteButton.swift
//  WellPath
//
//  Reusable favorite/pin button for toolbar
//

import SwiftUI

struct FavoriteButton: View {
    let itemType: FavoriteItemType
    let itemId: String
    let displayName: String
    let pillar: String

    @ObservedObject private var favoritesService = FavoritesService.shared
    @State private var isToggling = false

    private var isFavorite: Bool {
        favoritesService.isFavorite(type: itemType, id: itemId)
    }

    var body: some View {
        Button {
            guard !isToggling else { return }
            isToggling = true

            Task {
                await favoritesService.toggleFavorite(
                    type: itemType,
                    id: itemId,
                    displayName: displayName,
                    pillar: pillar
                )
                isToggling = false
            }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundColor(isFavorite ? .yellow : .primary)
                .font(.system(size: 18))
        }
        .disabled(isToggling)
        .opacity(isToggling ? 0.5 : 1.0)
    }
}

// MARK: - View Extension for easy toolbar addition

extension View {
    /// Add a favorite button to the toolbar
    func favoriteToolbar(
        itemType: FavoriteItemType,
        itemId: String,
        displayName: String,
        pillar: String
    ) -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: itemType,
                    itemId: itemId,
                    displayName: displayName,
                    pillar: pillar
                )
            }
        }
    }
}
