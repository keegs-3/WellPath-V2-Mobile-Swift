//
//  BiometricModels.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation

// MARK: - Biomarker Reading
struct BiomarkerReading: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let biomarkerName: String
    let value: Double
    let unit: String
    let testDate: String
    let source: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case biomarkerName = "biomarker_name"
        case value
        case unit
        case testDate = "test_date"
        case source
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Biometric Reading
struct BiometricReading: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let biometricName: String
    let value: Double
    let unit: String
    let recordedAt: String
    let source: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case biometricName = "biometric_name"
        case value
        case unit
        case recordedAt = "recorded_at"
        case source
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Biomarker Detail (Range Information)
struct BiomarkerDetail: Codable, Identifiable {
    let id: UUID
    let biomarker: String?
    let rangeName: String
    let rangeNameBackend: String
    let rangeLow: Double?
    let rangeHigh: Double?
    let frontendDisplay: String?
    let gender: String?
    let directionality: String?
    let rangeBucket: String?

    enum CodingKeys: String, CodingKey {
        case id
        case biomarker
        case rangeName = "range_name"
        case rangeNameBackend = "range_name_backend"
        case rangeLow = "range_low"
        case rangeHigh = "range_high"
        case frontendDisplay = "frontend_display"
        case gender
        case directionality
        case rangeBucket = "range_bucket"
    }
}

// MARK: - Biometric Detail (Range Information)
struct BiometricDetail: Codable, Identifiable {
    let id: UUID
    let biometric: String?
    let rangeName: String?
    let rangeNameBackend: String?
    let rangeLow: Double?
    let rangeHigh: Double?
    let frontendDisplaySpecific: String?
    let gender: String?
    let ageMin: Int?
    let ageMax: Int?
    let directionality: String?
    let rangeBucket: String?

    enum CodingKeys: String, CodingKey {
        case id
        case biometric
        case rangeName = "range_name"
        case rangeNameBackend = "range_name_backend"
        case rangeLow = "range_low"
        case rangeHigh = "range_high"
        case frontendDisplaySpecific = "frontend_display_specific"
        case gender
        case ageMin = "age_min"
        case ageMax = "age_max"
        case directionality
        case rangeBucket = "range_bucket"
    }
}

// MARK: - Biomarker Base
struct BiomarkerBase: Codable, Identifiable {
    let id: UUID
    let markerId: String
    let biomarkerName: String
    let category: String?
    let units: String?
    let unitDisplay: String?
    let format: String?
    let isActive: Bool?
    let aboutWhy: String?
    let aboutOptimalTarget: String?
    let aboutQuickTips: String?
    let education: String?

    enum CodingKeys: String, CodingKey {
        case id
        case markerId = "marker_id"
        case biomarkerName = "biomarker_name"
        case category
        case units
        case unitDisplay = "unit_display"
        case format
        case isActive = "is_active"
        case aboutWhy = "about_why"
        case aboutOptimalTarget = "about_optimal_target"
        case aboutQuickTips = "about_quick_tips"
        case education
    }
}

// MARK: - Biometrics Base
struct BiometricsBase: Codable, Identifiable {
    let id: UUID
    let metricId: String
    let biometricName: String
    let nameBackend: String
    let category: String?
    let unit: String?
    let unitDisplay: String?
    let format: String?
    let isActive: Bool?
    let aboutWhy: String?
    let aboutOptimalRange: String?
    let aboutQuickTips: String?
    let education: String?

    enum CodingKeys: String, CodingKey {
        case id
        case metricId = "metric_id"
        case biometricName = "biometric_name"
        case nameBackend = "name_backend"
        case category
        case unit
        case unitDisplay = "unit_display"
        case format
        case isActive = "is_active"
        case aboutWhy = "about_why"
        case aboutOptimalRange = "about_optimal_range"
        case aboutQuickTips = "about_quick_tips"
        case education
    }
}

// MARK: - Biomarker Education Section
struct BiomarkerEducationSection: Codable, Identifiable {
    let id: UUID
    let biomarkerName: String
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case biomarkerName = "biomarker_name"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Biometric Education Section
struct BiometricEducationSection: Codable, Identifiable {
    let id: UUID
    let biometricName: String
    let sectionTitle: String
    let sectionContent: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case biometricName = "biometric_name"
        case sectionTitle = "section_title"
        case sectionContent = "section_content"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Biometrics/Biomarkers Category
struct BiometricsBiomarkersCategory: Codable, Identifiable {
    let id: UUID
    let categoryName: String
    let biomarkers: String?
    let biometrics: String?
    let description: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryName = "category_name"
        case biomarkers
        case biometrics
        case description
        case updatedAt = "updated_at"
    }
}

// MARK: - Unit Conversion
struct UnitConversion: Codable, Identifiable {
    let id: UUID
    let fromUnit: String
    let toUnit: String
    let conversionFactor: Double
    let conversionOffset: Double?
    let conversionFormula: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fromUnit = "from_unit"
        case toUnit = "to_unit"
        case conversionFactor = "conversion_factor"
        case conversionOffset = "conversion_offset"
        case conversionFormula = "conversion_formula"
    }
}

// MARK: - View Models for UI
struct BiomarkerCardData: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let status: String
    let rangeName: String
    let optimalRange: String
    let trend: String
    let trendData: [Double]
    let unit: String
    let category: String?
}

struct BiometricCardData: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let status: String
    let rangeName: String
    let optimalRange: String
    let trend: String
    let trendData: [Double]
    let unit: String
    let category: String?
}
