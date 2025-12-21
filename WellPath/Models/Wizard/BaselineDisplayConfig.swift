//
//  BaselineDisplayConfig.swift
//  WellPath
//
//  Database-driven configuration for baseline wizards.
//  - display_baseline_view_cards: launcher cards shown on category screens
//  - display_baseline_views: wizard steps/views
//

import Foundation
import SwiftUI

// MARK: - Baseline View Card (Launcher)

/// The card shown on category screens to launch the baseline wizard
/// e.g., "Get Started with Protein"
struct BaselineViewCard: Identifiable, Codable {
    let id: UUID
    let cardId: String
    let categoryId: String
    let cardTitle: String
    let cardSubtitle: String?
    let cardIcon: String?
    let cardStyle: String?
    let wizardIosView: String?
    let displayOrder: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case categoryId = "category_id"
        case cardTitle = "card_title"
        case cardSubtitle = "card_subtitle"
        case cardIcon = "card_icon"
        case cardStyle = "card_style"
        case wizardIosView = "wizard_ios_view"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }
}

// MARK: - Baseline View (Wizard Step)

/// A step in the baseline wizard (intro, card_tour, questions, summary)
struct BaselineView: Identifiable, Codable {
    let id: UUID
    let viewId: String
    let cardId: String?
    let stepType: String  // 'intro', 'card_tour', 'questions', 'summary'
    let stepOrder: Int
    let title: String?
    let subtitle: String?
    let icon: String?

    // For intro/summary - array of benefit/step items
    let contentItems: [BaselineContentItem]?

    // For card_tour steps
    let displayViewId: String?
    let tourExplanation: String?
    let tourHighlightPoints: [String]?

    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case viewId = "view_id"
        case cardId = "card_id"
        case stepType = "step_type"
        case stepOrder = "step_order"
        case title, subtitle, icon
        case contentItems = "content_items"
        case displayViewId = "display_view_id"
        case tourExplanation = "tour_explanation"
        case tourHighlightPoints = "tour_highlight_points"
        case isActive = "is_active"
    }
}

// MARK: - Content Item (for JSONB arrays)

struct BaselineContentItem: Codable, Identifiable {
    var id: String { icon + title }
    let icon: String
    let title: String
    let description: String
}

// MARK: - Baseline View Subpage

/// Content within a wizard view step
/// Types: 'overview', 'card', 'questions', 'summary_card', 'next_steps'
struct BaselineViewSubpage: Identifiable, Codable {
    let id: UUID
    let subpageId: String
    let baselineViewId: String?
    let subpageType: String
    var displayOrder: Int

    // Content fields
    let title: String?
    let subtitle: String?
    let icon: String?

    // For 'overview' / 'next_steps' types
    let contentItems: [BaselineContentItem]?

    // For 'card' type
    let displayCardId: String?
    let cardExplanation: String?
    let highlightPoints: [String]?

    // For 'questions' type
    let questionCategoryId: String?

    // For 'summary_card' type
    let baselineType: String?
    let valueUnit: String?

    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case subpageId = "subpage_id"
        case baselineViewId = "baseline_view_id"
        case subpageType = "subpage_type"
        case displayOrder = "display_order"
        case title, subtitle, icon
        case contentItems = "content_items"
        case displayCardId = "display_card_id"
        case cardExplanation = "card_explanation"
        case highlightPoints = "highlight_points"
        case questionCategoryId = "question_category_id"
        case baselineType = "baseline_type"
        case valueUnit = "value_unit"
        case isActive = "is_active"
    }
}
