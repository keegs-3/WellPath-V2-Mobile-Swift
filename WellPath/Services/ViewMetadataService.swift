//
//  ViewMetadataService.swift
//  WellPath
//
//  Loads view metadata from database:
//  - Title from display_views.view_name
//  - Subtitle from display_views.view_name_long
//  - Unit from display_views_dependencies → sample_quantity_types → units_base.ui_display
//

import Foundation
import Supabase

struct ViewMetadata {
    let viewId: String
    let title: String
    let subtitle: String?
    let unit: String?
    let iconName: String?
    let pillar: String?
    let description: String?
}

@MainActor
class ViewMetadataService: ObservableObject {
    static let shared = ViewMetadataService()

    @Published var metadata: ViewMetadata?
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client
    private var cache: [String: ViewMetadata] = [:]

    private init() {}

    /// Load metadata for a view_id
    func loadMetadata(for viewId: String) async -> ViewMetadata? {
        // Check cache first
        if let cached = cache[viewId] {
            await MainActor.run {
                self.metadata = cached
            }
            return cached
        }

        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            // Query display_views with unit from chain
            let query = """
            view_id,
            view_name,
            view_name_long,
            icon_name,
            pillar,
            description,
            display_views_dependencies!inner(
                sample_quantity_type,
                sample_quantity_types!inner(
                    canonical_unit,
                    units_base!inner(
                        ui_display
                    )
                )
            )
            """

            let results: [ViewMetadataResponse] = try await supabase
                .from("display_views")
                .select(query)
                .eq("view_id", value: viewId)
                .limit(1)
                .execute()
                .value

            if let result = results.first {
                let unitDisplay = result.displayViewsDependencies?.first?
                    .sampleQuantityTypes?.unitsBase?.uiDisplay

                let metadata = ViewMetadata(
                    viewId: result.viewId,
                    title: result.viewName,
                    subtitle: result.viewNameLong,
                    unit: unitDisplay,
                    iconName: result.iconName,
                    pillar: result.pillar,
                    description: result.description
                )

                cache[viewId] = metadata

                await MainActor.run {
                    self.metadata = metadata
                    self.isLoading = false
                }

                return metadata
            } else {
                // Fallback: try without the unit chain
                return await loadMetadataFallback(for: viewId)
            }

        } catch {
            print("❌ ViewMetadataService: Error loading metadata for \(viewId): \(error)")
            // Try fallback without unit
            return await loadMetadataFallback(for: viewId)
        }
    }

    /// Fallback loader without unit chain (for views without sample_quantity_type)
    private func loadMetadataFallback(for viewId: String) async -> ViewMetadata? {
        do {
            struct SimpleViewResponse: Codable {
                let viewId: String
                let viewName: String
                let viewNameLong: String?
                let iconName: String?
                let pillar: String?
                let description: String?

                enum CodingKeys: String, CodingKey {
                    case viewId = "view_id"
                    case viewName = "view_name"
                    case viewNameLong = "view_name_long"
                    case iconName = "icon_name"
                    case pillar
                    case description
                }
            }

            let results: [SimpleViewResponse] = try await supabase
                .from("display_views")
                .select("view_id, view_name, view_name_long, icon_name, pillar, description")
                .eq("view_id", value: viewId)
                .limit(1)
                .execute()
                .value

            if let result = results.first {
                let metadata = ViewMetadata(
                    viewId: result.viewId,
                    title: result.viewName,
                    subtitle: result.viewNameLong,
                    unit: nil,
                    iconName: result.iconName,
                    pillar: result.pillar,
                    description: result.description
                )

                cache[viewId] = metadata

                await MainActor.run {
                    self.metadata = metadata
                    self.isLoading = false
                }

                return metadata
            }
        } catch {
            print("❌ ViewMetadataService fallback error: \(error)")
        }

        await MainActor.run {
            self.error = "Could not load metadata"
            self.isLoading = false
        }

        return nil
    }

    /// Get cached metadata synchronously (returns nil if not loaded)
    func getCached(for viewId: String) -> ViewMetadata? {
        return cache[viewId]
    }

    /// Clear cache
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Response Models

private struct ViewMetadataResponse: Codable {
    let viewId: String
    let viewName: String
    let viewNameLong: String?
    let iconName: String?
    let pillar: String?
    let description: String?
    let displayViewsDependencies: [DependencyResponse]?

    enum CodingKeys: String, CodingKey {
        case viewId = "view_id"
        case viewName = "view_name"
        case viewNameLong = "view_name_long"
        case iconName = "icon_name"
        case pillar
        case description
        case displayViewsDependencies = "display_views_dependencies"
    }
}

private struct DependencyResponse: Codable {
    let sampleQuantityType: String?
    let sampleQuantityTypes: QuantityTypeResponse?

    enum CodingKeys: String, CodingKey {
        case sampleQuantityType = "sample_quantity_type"
        case sampleQuantityTypes = "sample_quantity_types"
    }
}

private struct QuantityTypeResponse: Codable {
    let canonicalUnit: String?
    let unitsBase: UnitResponse?

    enum CodingKeys: String, CodingKey {
        case canonicalUnit = "canonical_unit"
        case unitsBase = "units_base"
    }
}

private struct UnitResponse: Codable {
    let uiDisplay: String?

    enum CodingKeys: String, CodingKey {
        case uiDisplay = "ui_display"
    }
}
