//
//  WellPathAboutModels.swift
//  WellPath
//
//  Database models for WellPath Score and Pillar about content
//

import Foundation

// MARK: - WellPath Score About Content

struct WellPathScoreAbout: Codable, Identifiable {
    let id: UUID
    let sectionNumber: Int
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sectionNumber = "section_number"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Computed property for icon based on section number
    var sectionIcon: String {
        switch sectionNumber {
        case 1: return "info.circle.fill"
        case 2: return "chart.bar.fill"
        case 3: return "target"
        case 4: return "equal.circle.fill"
        default: return "doc.text.fill"
        }
    }
}

// MARK: - Pillar About Content

struct PillarAbout: Codable, Identifiable {
    let id: UUID
    let pillarName: String
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pillarName = "pillar_name"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Pillar Markers (Biomarkers) About

struct PillarMarkersAbout: Codable, Identifiable {
    let id: UUID
    let pillarName: String
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pillarName = "pillar_name"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Pillar Behaviors About

struct PillarBehaviorsAbout: Codable, Identifiable {
    let id: UUID
    let pillarName: String
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pillarName = "pillar_name"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Pillar Education About

struct PillarEducationAbout: Codable, Identifiable {
    let id: UUID
    let pillarName: String
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pillarName = "pillar_name"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
