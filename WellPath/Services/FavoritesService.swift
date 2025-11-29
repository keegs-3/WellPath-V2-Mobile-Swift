//
//  FavoritesService.swift
//  WellPath
//
//  Manages user favorites for quick access in Data tab
//

import Foundation
import SwiftUI

// MARK: - Models

struct PatientFavorite: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let itemType: String
    let itemId: String
    let displayName: String?
    let pillar: String?
    let displayOrder: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case itemType = "item_type"
        case itemId = "item_id"
        case displayName = "display_name"
        case pillar
        case displayOrder = "display_order"
        case createdAt = "created_at"
    }
}

struct FavoriteInsert: Codable {
    let patientId: UUID
    let itemType: String
    let itemId: String
    let displayName: String?
    let pillar: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case itemType = "item_type"
        case itemId = "item_id"
        case displayName = "display_name"
        case pillar
    }
}

enum FavoriteItemType: String {
    case screen = "screen"
    case biomarker = "biomarker"
    case biometric = "biometric"
    case metric = "metric"
}

// MARK: - Service

@MainActor
class FavoritesService: ObservableObject {
    static let shared = FavoritesService()

    @Published var favorites: [PatientFavorite] = []
    @Published var isLoading = false
    @Published var favoriteIds: Set<String> = []  // Quick lookup: "type:id"

    private let supabase = SupabaseManager.shared.client

    private init() {}

    // MARK: - Load Favorites

    func loadFavorites() async {
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id

            let results: [PatientFavorite] = try await supabase
                .from("patient_favorites")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .order("display_order", ascending: true)
                .execute()
                .value

            favorites = results

            // Build quick lookup set
            favoriteIds = Set(results.map { "\($0.itemType):\($0.itemId)" })

            print("✅ Loaded \(favorites.count) favorites")

        } catch {
            print("❌ Error loading favorites: \(error)")
        }

        isLoading = false
    }

    // MARK: - Check if Favorited

    func isFavorite(type: FavoriteItemType, id: String) -> Bool {
        return favoriteIds.contains("\(type.rawValue):\(id)")
    }

    // MARK: - Add Favorite

    func addFavorite(type: FavoriteItemType, id: String, displayName: String?, pillar: String?) async -> Bool {
        do {
            let userId = try await supabase.auth.session.user.id

            let insert = FavoriteInsert(
                patientId: userId,
                itemType: type.rawValue,
                itemId: id,
                displayName: displayName,
                pillar: pillar
            )

            try await supabase
                .from("patient_favorites")
                .insert(insert)
                .execute()

            // Refresh favorites
            await loadFavorites()

            print("✅ Added favorite: \(type.rawValue):\(id)")
            return true

        } catch {
            print("❌ Error adding favorite: \(error)")
            return false
        }
    }

    // MARK: - Remove Favorite

    func removeFavorite(type: FavoriteItemType, id: String) async -> Bool {
        do {
            let userId = try await supabase.auth.session.user.id

            try await supabase
                .from("patient_favorites")
                .delete()
                .eq("patient_id", value: userId.uuidString)
                .eq("item_type", value: type.rawValue)
                .eq("item_id", value: id)
                .execute()

            // Refresh favorites
            await loadFavorites()

            print("✅ Removed favorite: \(type.rawValue):\(id)")
            return true

        } catch {
            print("❌ Error removing favorite: \(error)")
            return false
        }
    }

    // MARK: - Toggle Favorite

    func toggleFavorite(type: FavoriteItemType, id: String, displayName: String?, pillar: String?) async -> Bool {
        if isFavorite(type: type, id: id) {
            return await removeFavorite(type: type, id: id)
        } else {
            return await addFavorite(type: type, id: id, displayName: displayName, pillar: pillar)
        }
    }
}
