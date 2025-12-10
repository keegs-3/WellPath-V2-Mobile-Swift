//
//  TabEducationViewModel.swift
//  WellPath
//
//  Shared view model for loading education content (about, health impact, quick tips)
//  from education_static_content table for detail screen tabs (Nutrition, Sleep, etc.)
//
//  Personalized content available via chat (EducationQAModal).
//

import SwiftUI
import Supabase

// MARK: - Tab Education ViewModel

@MainActor
class TabEducationViewModel: ObservableObject {
    @Published var education: MetricEducation?

    private let viewId: String
    private let supabase = SupabaseManager.shared.client

    init(viewId: String) {
        self.viewId = viewId
    }

    /// Load static education content from education_static_content table
    func loadEducation() async {
        do {
            // Query education_static_content table (JSONB columns)
            let results: [EducationStaticContent] = try await supabase
                .from("education_static_content")
                .select("*")
                .eq("view_id", value: viewId)
                .eq("is_published", value: true)
                .limit(1)
                .execute()
                .value

            if let result = results.first {
                // Parse JSONB columns into display-friendly format
                education = MetricEducation(
                    aboutContent: result.aboutContentShort ?? extractText(from: result.aboutContent),
                    longevityImpact: result.longevityImpactShort ?? extractText(from: result.longevityImpact),
                    quickTips: extractTips(from: result.quickTips)
                )
            } else {
                // Fallback: try display_views for legacy content
                await loadLegacyEducation()
            }

        } catch {
            print("❌ Error loading education for \(viewId): \(error)")
            // Fallback to legacy table on error
            await loadLegacyEducation()
        }
    }

    // MARK: - Private Helpers

    /// Fallback to legacy display_views table
    private func loadLegacyEducation() async {
        do {
            struct LegacyEducationResponse: Codable {
                let aboutContent: String?
                let longevityImpact: String?
                let quickTips: [String]?

                enum CodingKeys: String, CodingKey {
                    case aboutContent = "about_content"
                    case longevityImpact = "longevity_impact"
                    case quickTips = "quick_tips"
                }
            }

            let results: [LegacyEducationResponse] = try await supabase
                .from("display_views")
                .select("about_content, longevity_impact, quick_tips")
                .eq("view_id", value: viewId)
                .limit(1)
                .execute()
                .value

            if let result = results.first {
                education = MetricEducation(
                    aboutContent: result.aboutContent,
                    longevityImpact: result.longevityImpact,
                    quickTips: result.quickTips
                )
            }
        } catch {
            print("❌ Error loading legacy education for \(viewId): \(error)")
        }
    }

    /// Extract text from AnyJSON that can be a string, object, or null
    private func extractText(from anyJson: AnyJSON?) -> String? {
        guard let anyJson = anyJson else { return nil }

        // Case 1: Direct string (most common in current DB)
        if case .string(let text) = anyJson {
            return text.isEmpty ? nil : text
        }

        // Case 2: Object with various keys
        if case .object(let json) = anyJson {
            // Try "text" key
            if case .string(let text) = json["text"] {
                return text.isEmpty ? nil : text
            }

            // Try "paragraphs" array
            if case .array(let paragraphs) = json["paragraphs"] {
                let text = paragraphs.compactMap { paragraph -> String? in
                    if case .string(let text) = paragraph { return text }
                    return nil
                }.joined(separator: "\n\n")
                return text.isEmpty ? nil : text
            }

            // Try "content" key
            if case .string(let text) = json["content"] {
                return text.isEmpty ? nil : text
            }
        }

        // Case 3: Array of strings (join them)
        if case .array(let items) = anyJson {
            let text = items.compactMap { item -> String? in
                if case .string(let text) = item { return text }
                return nil
            }.joined(separator: "\n\n")
            return text.isEmpty ? nil : text
        }

        return nil
    }

    /// Extract tips from AnyJSON that can be an array or object with array
    private func extractTips(from anyJson: AnyJSON?) -> [String]? {
        guard let anyJson = anyJson else { return nil }

        // Case 1: Direct array of strings (most common in current DB)
        if case .array(let items) = anyJson {
            let strings = items.compactMap { item -> String? in
                if case .string(let text) = item { return text }
                return nil
            }
            return strings.isEmpty ? nil : strings
        }

        // Case 2: Object with "tips" or "items" array
        if case .object(let json) = anyJson {
            // Try "tips" array
            if case .array(let tips) = json["tips"] {
                let strings = tips.compactMap { tip -> String? in
                    if case .string(let text) = tip { return text }
                    return nil
                }
                return strings.isEmpty ? nil : strings
            }

            // Try "items" array
            if case .array(let items) = json["items"] {
                let strings = items.compactMap { item -> String? in
                    if case .string(let text) = item { return text }
                    return nil
                }
                return strings.isEmpty ? nil : strings
            }
        }

        return nil
    }
}

// MARK: - Metric Education Model

struct MetricEducation {
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
}
