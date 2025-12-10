//
//  DisplayConfigService.swift
//  WellPath
//
//  Service for looking up display configuration info from the database
//  Resolves view_id → card → category → section hierarchy
//

import Foundation
import Supabase

// MARK: - Section Info

struct SectionInfo: Codable {
    let sectionId: String
    let sectionName: String
    let categoryId: String?
    let categoryName: String?
    let cardId: String?

    enum CodingKeys: String, CodingKey {
        case sectionId = "section_id"
        case sectionName = "section_name"
        case categoryId = "category_id"
        case categoryName = "category_name"
        case cardId = "card_id"
    }
}

// MARK: - Service

@MainActor
class DisplayConfigService: ObservableObject {
    static let shared = DisplayConfigService()

    private let supabase = SupabaseManager.shared.client

    // Cache for section lookups (view_id → SectionInfo)
    private var sectionCache: [String: SectionInfo] = [:]

    private init() {}

    /// Look up section info for a view_id (DISP_* metric ID)
    /// Chain: view_id → display_view_cards → display_card_categories → display_category_sections
    func sectionInfo(for viewId: String) async -> SectionInfo? {
        // Check cache first
        if let cached = sectionCache[viewId] {
            return cached
        }

        do {
            // Query through the hierarchy with joins
            // Using a raw query since we need multiple joins
            struct QueryResult: Codable {
                let cardId: String
                let categoryId: String
                let categoryName: String
                let sectionId: String
                let sectionName: String

                enum CodingKeys: String, CodingKey {
                    case cardId = "card_id"
                    case categoryId = "category_id"
                    case categoryName = "category_name"
                    case sectionId = "section_id"
                    case sectionName = "section_name"
                }
            }

            // First get the card's category_id
            struct CardCategory: Codable {
                let cardId: String
                let categoryId: String
                enum CodingKeys: String, CodingKey {
                    case cardId = "card_id"
                    case categoryId = "category_id"
                }
            }

            let cards: [CardCategory] = try await supabase
                .from("display_view_cards")
                .select("card_id, category_id")
                .eq("view_id", value: viewId)
                .limit(1)
                .execute()
                .value

            guard let card = cards.first else {
                print("DisplayConfigService: No card found for view_id \(viewId)")
                return nil
            }

            // Get category's section_id and name
            struct CategorySection: Codable {
                let name: String
                let sectionId: String
                enum CodingKeys: String, CodingKey {
                    case name
                    case sectionId = "section_id"
                }
            }

            let categories: [CategorySection] = try await supabase
                .from("display_card_categories")
                .select("name, section_id")
                .eq("category_id", value: card.categoryId)
                .limit(1)
                .execute()
                .value

            guard let category = categories.first else {
                print("DisplayConfigService: No category found for category_id \(card.categoryId)")
                return nil
            }

            // Get section name
            struct SectionName: Codable {
                let sectionName: String
                enum CodingKeys: String, CodingKey {
                    case sectionName = "section_name"
                }
            }

            let sections: [SectionName] = try await supabase
                .from("display_category_sections")
                .select("section_name")
                .eq("section_id", value: category.sectionId)
                .limit(1)
                .execute()
                .value

            let sectionName = sections.first?.sectionName ?? category.sectionId

            let info = SectionInfo(
                sectionId: category.sectionId,
                sectionName: sectionName,
                categoryId: card.categoryId,
                categoryName: category.name,
                cardId: card.cardId
            )

            // Cache the result
            sectionCache[viewId] = info

            return info

        } catch {
            print("DisplayConfigService: Error looking up section for \(viewId): \(error)")
            return nil
        }
    }

    /// Preload section info for multiple view IDs (batch optimization)
    func preloadSectionInfo(for viewIds: [String]) async {
        // Filter out already cached
        let uncached = viewIds.filter { sectionCache[$0] == nil }
        guard !uncached.isEmpty else { return }

        // Load each one (could optimize with batch query later)
        for viewId in uncached {
            _ = await sectionInfo(for: viewId)
        }
    }

    /// Clear the cache (useful for testing or after DB updates)
    func clearCache() {
        sectionCache.removeAll()
    }
}
