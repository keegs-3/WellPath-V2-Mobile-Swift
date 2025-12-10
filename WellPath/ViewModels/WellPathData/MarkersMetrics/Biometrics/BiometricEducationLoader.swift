//
//  BiometricEducationLoader.swift
//  WellPath
//
//  Loads education content from education_static_content table for biometrics/biomarkers
//  Also loads AI-generated personalized content via EducationService
//

import Foundation
import Supabase

/// Unified education loader for all metrics (biometrics, biomarkers, etc.)
/// Uses education_static_content for static content. Personalized content available via chat.
@MainActor
class BiometricEducationLoader: ObservableObject {
    @Published var sections: [EducationSection] = []
    @Published var staticContent: EducationStaticContent?
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    /// Load static education content from education_static_content table
    func loadSections(for viewId: String) async {
        isLoading = true
        error = nil

        do {
            // Query education_static_content by view_id
            let results: [EducationStaticContent] = try await supabase
                .from("education_static_content")
                .select()
                .eq("view_id", value: viewId)
                .eq("is_published", value: true)
                .limit(1)
                .execute()
                .value

            guard let content = results.first else {
                print("⚠️ No education content found for \(viewId)")
                sections = []
                isLoading = false
                return
            }

            staticContent = content

            // Transform static content into sections for BiometricAboutView
            var displaySections: [EducationSection] = []

            // 1. About/Overview section
            if let aboutShort = content.aboutContentShort, !aboutShort.isEmpty {
                displaySections.append(EducationSection(
                    id: UUID(),
                    viewId: viewId,
                    sectionTitle: "Overview",
                    sectionContent: aboutShort,
                    displayOrder: 1
                ))
            } else if let aboutFull = extractText(from: content.aboutContent) {
                displaySections.append(EducationSection(
                    id: UUID(),
                    viewId: viewId,
                    sectionTitle: "Overview",
                    sectionContent: aboutFull,
                    displayOrder: 1
                ))
            }

            // 2. Longevity Impact section
            if let longevityShort = content.longevityImpactShort, !longevityShort.isEmpty {
                displaySections.append(EducationSection(
                    id: UUID(),
                    viewId: viewId,
                    sectionTitle: "Longevity Impact",
                    sectionContent: longevityShort,
                    displayOrder: 2
                ))
            } else if let longevityFull = extractText(from: content.longevityImpact) {
                displaySections.append(EducationSection(
                    id: UUID(),
                    viewId: viewId,
                    sectionTitle: "Longevity Impact",
                    sectionContent: longevityFull,
                    displayOrder: 2
                ))
            }

            // 3. Optimal Ranges section (if available)
            if let rangeText = extractText(from: content.optimalRangesExplanation) {
                displaySections.append(EducationSection(
                    id: UUID(),
                    viewId: viewId,
                    sectionTitle: "Optimal Ranges",
                    sectionContent: rangeText,
                    displayOrder: 3
                ))
            }

            // 4. Quick Tips section (if available)
            if let tips = extractTips(from: content.quickTips), !tips.isEmpty {
                let tipsText = tips.enumerated().map { _, tip in
                    "• \(tip)"
                }.joined(separator: "\n")

                displaySections.append(EducationSection(
                    id: UUID(),
                    viewId: viewId,
                    sectionTitle: "Quick Tips",
                    sectionContent: tipsText,
                    displayOrder: 4
                ))
            }

            // 5. Common Misconceptions section (if available)
            if let misconceptionsText = extractText(from: content.commonMisconceptions) {
                displaySections.append(EducationSection(
                    id: UUID(),
                    viewId: viewId,
                    sectionTitle: "Common Misconceptions",
                    sectionContent: misconceptionsText,
                    displayOrder: 5
                ))
            }

            sections = displaySections
            print("✅ Loaded \(displaySections.count) education sections for \(viewId)")

        } catch {
            self.error = error.localizedDescription
            print("❌ Error loading education content: \(error)")
        }

        isLoading = false
    }

    // MARK: - JSONB Extraction Helpers

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

            // Try "description" key
            if case .string(let text) = json["description"] {
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

/// Alias for backwards compatibility - same class handles both
typealias BiomarkerEducationLoader = BiometricEducationLoader
