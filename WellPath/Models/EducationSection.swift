//
//  EducationSection.swift
//  WellPath
//
//  Models for education content
//  Static content comes from education_static_content (via view_id FK)
//  Personalized content comes from generate-education edge function
//

import Foundation
import Supabase  // For AnyJSON type

// MARK: - Static Education Content

/// Static education content from education_static_content table
/// Each view has one education entry with about, longevity impact, tips, etc.
/// JSONB columns can be strings, objects, or arrays - use AnyJSON to handle mixed types
struct EducationStaticContent: Codable, Identifiable {
    let id: UUID
    let viewId: String
    let aboutContent: AnyJSON?           // JSONB - can be string, object {"text": "..."}, or null
    let longevityImpact: AnyJSON?        // JSONB - can be string, object, or null
    let optimalRangesExplanation: AnyJSON?
    let commonMisconceptions: AnyJSON?
    let quickTips: AnyJSON?              // JSONB - typically an array of strings
    let relatedMarkers: [String]?
    let isPublished: Bool
    let aboutContentShort: String?       // Plain TEXT column
    let longevityImpactShort: String?    // Plain TEXT column
    let suggestedQuestions: [String]?    // JSONB array of suggested questions for Chiron AI chat
    let aiContext: String?               // Text context/instructions for Chiron per metric

    enum CodingKeys: String, CodingKey {
        case id
        case viewId = "view_id"
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case optimalRangesExplanation = "optimal_ranges_explanation"
        case commonMisconceptions = "common_misconceptions"
        case quickTips = "quick_tips"
        case relatedMarkers = "related_markers"
        case isPublished = "is_published"
        case aboutContentShort = "about_content_short"
        case longevityImpactShort = "longevity_impact_short"
        case suggestedQuestions = "suggested_questions"
        case aiContext = "ai_context"
    }
}

// MARK: - Personalized Education Content

/// Personalized education content from generate-education edge function
/// Cached in education_personalized_cache table
struct EducationPersonalizedContent: Codable, Identifiable {
    let id: UUID?
    let patientId: UUID
    let viewId: String
    let userValue: Double?
    let userRangeStatus: String?
    let statusSummary: String?
    let personalizedTips: String?
    let trendAnalysis: String?
    let nextSteps: String?
    let generatedBy: String?
    let tokensUsed: Int?
    let expiresAt: Date?
    let isStale: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case viewId = "view_id"
        case userValue = "user_value"
        case userRangeStatus = "user_range_status"
        case statusSummary = "status_summary"
        case personalizedTips = "personalized_tips"
        case trendAnalysis = "trend_analysis"
        case nextSteps = "next_steps"
        case generatedBy = "generated_by"
        case tokensUsed = "tokens_used"
        case expiresAt = "expires_at"
        case isStale = "is_stale"
    }
}

// MARK: - Education API Request/Response

/// Request body for generate-education edge function
struct EducationRequest: Codable {
    let action: EducationAction
    let viewId: String
    let patientId: UUID?
    let question: String?
    let forceRefresh: Bool?

    enum CodingKeys: String, CodingKey {
        case action
        case viewId = "view_id"
        case patientId = "patient_id"
        case question
        case forceRefresh = "force_refresh"
    }
}

enum EducationAction: String, Codable {
    case getStatic = "get_static"
    case getPersonalized = "get_personalized"
    case askQuestion = "ask_question"
}

/// Response from generate-education edge function
struct EducationResponse: Codable {
    let success: Bool
    let content: EducationStaticContent?
    let personalizedContent: EducationPersonalizedContent?
    let answer: String?
    let source: String?
    let tokensUsed: Int?
    let responseTimeMs: Int?
    let expiresAt: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case content
        case personalizedContent = "personalized_content"
        case answer
        case source
        case tokensUsed = "tokens_used"
        case responseTimeMs = "response_time_ms"
        case expiresAt = "expires_at"
        case error
    }
}

// MARK: - Legacy Education Section Model

/// Legacy education section for biomarkers and biometrics
/// Each marker has multiple sections (Overview, Longevity Connection, Optimal Ranges, etc.)
/// Note: Consider migrating to education_static_content table
struct EducationSection: Codable, Identifiable {
    let id: UUID
    let viewId: String
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case viewId = "view_id"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
    }
}

/// Type of education section source
enum EducationSourceType {
    case biomarker
    case biometric
    case trackedMetric

    var tableName: String {
        switch self {
        case .biomarker: return "biomarkers_education_sections"
        case .biometric: return "biometrics_education_sections"
        case .trackedMetric: return "education_static_content"  // New unified table
        }
    }
}

// MARK: - Combined Education Display Model

/// Combined education data for display (static + personalized)
struct EducationDisplayData {
    let viewId: String
    let viewName: String

    // Static content
    let aboutShort: String?
    let aboutFull: String?
    let longevityImpactShort: String?
    let longevityImpactFull: String?
    let quickTips: [String]?

    // Personalized content (optional, loaded on-demand)
    var personalizedSummary: String?
    var personalizedTips: String?
    var trendAnalysis: String?
    var nextSteps: String?
    var isPersonalized: Bool { personalizedSummary != nil }

    init(
        viewId: String,
        viewName: String,
        staticContent: EducationStaticContent?
    ) {
        self.viewId = viewId
        self.viewName = viewName
        self.aboutShort = staticContent?.aboutContentShort
        self.longevityImpactShort = staticContent?.longevityImpactShort

        // Extract full content from JSONB
        // These are typically stored as {"text": "..."} or {"paragraphs": [...]}
        self.aboutFull = Self.extractText(from: staticContent?.aboutContent)
        self.longevityImpactFull = Self.extractText(from: staticContent?.longevityImpact)
        self.quickTips = Self.extractTips(from: staticContent?.quickTips)
    }

    private static func extractText(from anyJson: AnyJSON?) -> String? {
        guard let anyJson = anyJson else { return nil }

        // Case 1: Direct string (most common)
        if case .string(let text) = anyJson {
            return text.isEmpty ? nil : text
        }

        // Case 2: Object with keys
        if case .object(let json) = anyJson {
            if case .string(let text) = json["text"] {
                return text.isEmpty ? nil : text
            }
            if case .array(let paragraphs) = json["paragraphs"] {
                let text = paragraphs.compactMap { paragraph -> String? in
                    if case .string(let text) = paragraph { return text }
                    return nil
                }.joined(separator: "\n\n")
                return text.isEmpty ? nil : text
            }
        }

        // Case 3: Array of strings
        if case .array(let items) = anyJson {
            let text = items.compactMap { item -> String? in
                if case .string(let text) = item { return text }
                return nil
            }.joined(separator: "\n\n")
            return text.isEmpty ? nil : text
        }

        return nil
    }

    private static func extractTips(from anyJson: AnyJSON?) -> [String]? {
        guard let anyJson = anyJson else { return nil }

        // Case 1: Direct array of strings
        if case .array(let items) = anyJson {
            let strings = items.compactMap { item -> String? in
                if case .string(let text) = item { return text }
                return nil
            }
            return strings.isEmpty ? nil : strings
        }

        // Case 2: Object with "tips" array
        if case .object(let json) = anyJson {
            if case .array(let tips) = json["tips"] {
                let strings = tips.compactMap { tip -> String? in
                    if case .string(let text) = tip { return text }
                    return nil
                }
                return strings.isEmpty ? nil : strings
            }
        }

        return nil
    }

    mutating func addPersonalizedContent(_ personalized: EducationPersonalizedContent) {
        self.personalizedSummary = personalized.statusSummary
        self.personalizedTips = personalized.personalizedTips
        self.trendAnalysis = personalized.trendAnalysis
        self.nextSteps = personalized.nextSteps
    }
}
