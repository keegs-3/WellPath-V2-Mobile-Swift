//
//  TherapeuticModels.swift
//  WellPath
//
//  Models for patient therapeutics (medications, supplements, peptides).
//  Represents the regimen/prescription data stored in patient_therapeutics.
//  Adherence tracking goes through patient_samples.
//

import Foundation
import SwiftUI

// MARK: - Therapeutic Type

enum TherapeuticType: String, Codable, CaseIterable, Identifiable {
    case medication = "MED"
    case supplement = "SUP"
    case peptide = "PEP"
    case hormone = "HOR"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .medication: return "Medication"
        case .supplement: return "Supplement"
        case .peptide: return "Peptide"
        case .hormone: return "Hormone"
        case .other: return "Other"
        }
    }

    var displayNamePlural: String {
        switch self {
        case .medication: return "Medications"
        case .supplement: return "Supplements"
        case .peptide: return "Peptides"
        case .hormone: return "Hormones"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .medication: return "pills.fill"
        case .supplement: return "leaf.fill"
        case .peptide: return "syringe.fill"
        case .hormone: return "waveform.path.ecg"
        case .other: return "cross.vial.fill"
        }
    }

    var color: Color {
        switch self {
        case .medication: return .blue
        case .supplement: return .green
        case .peptide: return .purple
        case .hormone: return .orange
        case .other: return .gray
        }
    }

    /// Primary types shown in picker (excludes "other")
    static var primaryCases: [TherapeuticType] {
        [.medication, .supplement, .peptide, .hormone]
    }
}

// MARK: - Patient Therapeutic

struct PatientTherapeutic: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let therapeuticBaseId: UUID?
    let therapeuticName: String
    let therapeuticType: String
    let category: String?

    // Dosing
    let doseAmount: Double?
    let doseUnit: String?
    let dosesPerDay: Int?

    // Timing
    let timingMorning: Bool?
    let timingMidday: Bool?
    let timingEvening: Bool?
    let timingBedtime: Bool?
    let timingWithFood: Bool?
    let timingInstructions: String?

    // Dates
    let startDate: String?
    let endDate: String?

    // Prescription info
    let prescriberName: String?
    let prescriptionNumber: String?
    let pharmacyName: String?
    let refillsRemaining: Int?

    // Tracking
    let trackAdherence: Bool?
    let reminderEnabled: Bool?
    let reminderTimes: [String]?

    // Notes
    let reasonForTaking: String?
    let notes: String?

    // Status
    let isActive: Bool?
    let discontinuedReason: String?
    let discontinuedDate: String?

    // Metadata
    let dataSource: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case therapeuticBaseId = "therapeutic_base_id"
        case therapeuticName = "therapeutic_name"
        case therapeuticType = "therapeutic_type"
        case category
        case doseAmount = "dose_amount"
        case doseUnit = "dose_unit"
        case dosesPerDay = "doses_per_day"
        case timingMorning = "timing_morning"
        case timingMidday = "timing_midday"
        case timingEvening = "timing_evening"
        case timingBedtime = "timing_bedtime"
        case timingWithFood = "timing_with_food"
        case timingInstructions = "timing_instructions"
        case startDate = "start_date"
        case endDate = "end_date"
        case prescriberName = "prescriber_name"
        case prescriptionNumber = "prescription_number"
        case pharmacyName = "pharmacy_name"
        case refillsRemaining = "refills_remaining"
        case trackAdherence = "track_adherence"
        case reminderEnabled = "reminder_enabled"
        case reminderTimes = "reminder_times"
        case reasonForTaking = "reason_for_taking"
        case notes
        case isActive = "is_active"
        case discontinuedReason = "discontinued_reason"
        case discontinuedDate = "discontinued_date"
        case dataSource = "data_source"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var type: TherapeuticType {
        TherapeuticType(rawValue: therapeuticType) ?? .other
    }

    var doseDescription: String {
        guard let amount = doseAmount else { return "As directed" }
        let unit = doseUnit ?? ""
        return "\(amount.formatted()) \(unit)"
    }

    var frequencyDescription: String {
        guard let doses = dosesPerDay else { return "" }
        switch doses {
        case 1: return "Once daily"
        case 2: return "Twice daily"
        case 3: return "Three times daily"
        case 4: return "Four times daily"
        default: return "\(doses)x daily"
        }
    }

    var timingDescription: String {
        var times: [String] = []
        if timingMorning == true { times.append("Morning") }
        if timingMidday == true { times.append("Midday") }
        if timingEvening == true { times.append("Evening") }
        if timingBedtime == true { times.append("Bedtime") }

        if times.isEmpty { return timingInstructions ?? "" }

        var result = times.joined(separator: ", ")
        if timingWithFood == true {
            result += " (with food)"
        }
        return result
    }

    var statusDescription: String {
        if isActive == false {
            if let reason = discontinuedReason {
                return "Discontinued: \(reason)"
            }
            return "Discontinued"
        }
        return "Active"
    }

    var parsedStartDate: Date? {
        guard let startDate = startDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: startDate)
    }

    var parsedEndDate: Date? {
        guard let endDate = endDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: endDate)
    }
}

// MARK: - Therapeutics Base (Reference Table)

struct TherapeuticsBase: Codable, Identifiable {
    let id: UUID
    let therapeuticName: String
    let therapeuticType: String?
    let category: String?
    let overview: String?
    let recommendationText: String?
    let therapeuticOperator: String?
    let therapeuticDoseMin: Double?
    let therapeuticDoseMax: Double?
    let therapeuticUnit: String?
    let therapeuticUnitSymbol: String?
    let therapeuticDoseRollup: String?
    let therapeuticFrequencyDays: Int?
    let therapeuticTiming: String?
    let linkedEvidence: String?
    let ageMin: Double?
    let ageMax: Double?
    let gender: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?

    // Education fields
    let mechanismOfAction: String?
    let benefits: [[String: String]]?
    let risksWarnings: [[String: String]]?
    let contraindications: [[String: String]]?
    let dosingGuidance: String?
    let timingGuidance: String?
    let longevityRelevance: String?
    let researchSummary: String?
    let commonBrands: [String]?
    let aiContext: String?

    enum CodingKeys: String, CodingKey {
        case id
        case therapeuticName = "therapeutic_name"
        case therapeuticType = "therapeutic_type"
        case category
        case overview
        case recommendationText = "recommendation_text"
        case therapeuticOperator = "therapeutic_operator"
        case therapeuticDoseMin = "therapeutic_dose_min"
        case therapeuticDoseMax = "therapeutic_dose_max"
        case therapeuticUnit = "therapeutic_unit"
        case therapeuticUnitSymbol = "therapeutic_unit_symbol"
        case therapeuticDoseRollup = "therapeutic_dose_rollup"
        case therapeuticFrequencyDays = "therapeutic_frequency_days"
        case therapeuticTiming = "therapeutic_timing"
        case linkedEvidence = "linked_evidence"
        case ageMin = "age_min"
        case ageMax = "age_max"
        case gender
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case mechanismOfAction = "mechanism_of_action"
        case benefits
        case risksWarnings = "risks_warnings"
        case contraindications
        case dosingGuidance = "dosing_guidance"
        case timingGuidance = "timing_guidance"
        case longevityRelevance = "longevity_relevance"
        case researchSummary = "research_summary"
        case commonBrands = "common_brands"
        case aiContext = "ai_context"
    }

    var type: TherapeuticType {
        TherapeuticType(rawValue: therapeuticType ?? "") ?? .other
    }

    /// Generate view_id matching display_views pattern: DISP_{TYPE}_{SANITIZED_NAME}
    var viewId: String {
        let typeCode = therapeuticType ?? "UNK"
        let sanitizedName = therapeuticName
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return "DISP_\(typeCode)_\(sanitizedName)"
    }

    var doseRangeDescription: String {
        guard let min = therapeuticDoseMin else { return "" }
        let unit = therapeuticUnitSymbol ?? therapeuticUnit ?? ""
        if let max = therapeuticDoseMax, max != min {
            return "\(min.formatted())-\(max.formatted()) \(unit)"
        }
        return "\(min.formatted()) \(unit)"
    }
}

// MARK: - Therapeutic Log (Daily Dose Tracking)

struct TherapeuticLog: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let patientTherapeuticId: UUID
    let loggedAt: String
    let doseAmount: Double?
    let doseUnit: String?
    let timing: String?  // morning, midday, evening, bedtime
    let taken: Bool
    let skipReason: String?
    let notes: String?
    let source: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case patientTherapeuticId = "patient_therapeutic_id"
        case loggedAt = "logged_at"
        case doseAmount = "dose_amount"
        case doseUnit = "dose_unit"
        case timing
        case taken
        case skipReason = "skip_reason"
        case notes
        case source
        case createdAt = "created_at"
    }

    var parsedLoggedAt: Date? {
        ISO8601DateFormatter().date(from: loggedAt)
    }

    var logDate: Date {
        parsedLoggedAt ?? Date()
    }
}

// MARK: - Drug Interaction

struct DrugInteraction: Codable, Identifiable {
    let id: UUID
    let drug1Name: String
    let drug1Rxcui: String?
    let drug2Name: String
    let drug2Rxcui: String?
    let severity: String?
    let level: String?
    let mechanism: String?
    let clinicalEffect: String?
    let management: String?
    let alternativeDrugs: String?
    let evidenceLevel: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id
        case drug1Name = "drug_1_name"
        case drug1Rxcui = "drug_1_rxcui"
        case drug2Name = "drug_2_name"
        case drug2Rxcui = "drug_2_rxcui"
        case severity
        case level
        case mechanism
        case clinicalEffect = "clinical_effect"
        case management
        case alternativeDrugs = "alternative_drugs"
        case evidenceLevel = "evidence_level"
        case source
    }

    var severityColor: Color {
        switch severity?.lowercased() {
        case "major": return .red
        case "moderate": return .orange
        case "minor": return .yellow
        case "info": return .blue
        default: return .gray
        }
    }

    var severityIcon: String {
        switch severity?.lowercased() {
        case "major": return "exclamationmark.octagon.fill"
        case "moderate": return "exclamationmark.triangle.fill"
        case "minor": return "info.circle.fill"
        case "info": return "checkmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Time of Day

enum TimeOfDay: String, CaseIterable, Identifiable {
    case morning
    case midday
    case evening
    case bedtime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        case .bedtime: return "Bedtime"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .midday: return "sun.min.fill"
        case .evening: return "sunset.fill"
        case .bedtime: return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .morning: return .orange
        case .midday: return .yellow
        case .evening: return .blue
        case .bedtime: return .purple
        }
    }
}

// MARK: - Therapeutic Dose Entry (for adherence tracking via patient_samples)

struct TherapeuticDoseEntry: Codable {
    let therapeuticId: UUID
    let therapeuticType: String
    let therapeuticName: String
    let doseAmount: Double?
    let doseUnit: String?
    let timeOfDay: String?  // morning, midday, evening, bedtime
    let takenWithFood: Bool?
    let skipped: Bool?
    let skipReason: String?
    let takenAt: Date

    enum CodingKeys: String, CodingKey {
        case therapeuticId = "therapeutic_id"
        case therapeuticType = "therapeutic_type"
        case therapeuticName = "therapeutic_name"
        case doseAmount = "dose_amount"
        case doseUnit = "dose_unit"
        case timeOfDay = "time_of_day"
        case takenWithFood = "taken_with_food"
        case skipped
        case skipReason = "skip_reason"
        case takenAt = "taken_at"
    }
}

// MARK: - Common Dose Units (Legacy - prefer TherapeuticUnitOption from DB)

enum DoseUnit: String, CaseIterable, Identifiable {
    case mg = "mg"
    case mcg = "mcg"
    case g = "g"
    case iu = "IU"
    case ml = "ml"
    case drops = "drops"
    case tablets = "tablets"
    case capsules = "capsules"
    case sprays = "sprays"
    case patches = "patches"
    case units = "units"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Therapeutic Unit Option (from therapeutic_unit_options table)

/// Represents a substance-specific unit option from the database.
/// Loaded via JOIN with units_base to get display info.
struct TherapeuticUnitOption: Codable, Identifiable, Hashable {
    let id: UUID
    let therapeuticName: String
    let unitId: String
    let conversionToBaseFactor: Double?
    let isDefault: Bool
    let isAvailable: Bool
    let baseUnitId: String?
    let notes: String?

    /// Joined from units_base table
    let unitsBase: UnitsBaseInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case therapeuticName = "therapeutic_name"
        case unitId = "unit_id"
        case conversionToBaseFactor = "conversion_to_base_factor"
        case isDefault = "is_default"
        case isAvailable = "is_available"
        case baseUnitId = "base_unit_id"
        case notes
        case unitsBase = "units_base"
    }

    // MARK: - Computed Properties

    /// Display symbol (e.g., "mg", "mcg", "IU")
    var symbol: String {
        unitsBase?.symbol ?? unitId
    }

    /// Full display name (e.g., "milligrams", "micrograms")
    var displayName: String {
        unitsBase?.uiDisplay ?? unitId
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TherapeuticUnitOption, rhs: TherapeuticUnitOption) -> Bool {
        lhs.id == rhs.id
    }
}

/// Nested struct for units_base join data
struct UnitsBaseInfo: Codable, Hashable {
    let symbol: String?
    let uiDisplay: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case uiDisplay = "ui_display"
    }
}

// MARK: - Suggested Therapeutic (from patient_suggested_therapeutics view)

/// A therapeutic suggestion based on patient scores and biomarkers.
/// Generated dynamically from score_therapeutic_links junction table.
struct SuggestedTherapeutic: Codable, Identifiable {
    let patientId: UUID
    let therapeuticName: String
    let therapeuticType: String?
    let category: String?
    let triggeringScore: String?
    let scoreValue: Double?
    let rawValue: Double?
    let rawUnit: String?
    let relevance: Int?
    let direction: String?
    let rationale: String?
    let viewId: String?

    var id: String { "\(patientId)-\(therapeuticName)" }

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case therapeuticName = "therapeutic_name"
        case therapeuticType = "therapeutic_type"
        case category
        case triggeringScore = "triggering_score"
        case scoreValue = "score_value"
        case rawValue = "raw_value"
        case rawUnit = "raw_unit"
        case relevance
        case direction
        case rationale
        case viewId = "view_id"
    }

    var type: TherapeuticType {
        TherapeuticType(rawValue: therapeuticType ?? "") ?? .other
    }

    /// Display-friendly triggering score name
    var triggeringScoreDisplay: String {
        guard let score = triggeringScore else { return "Health Score" }
        return score
            .replacingOccurrences(of: "_score", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// Score status description
    var scoreStatusDescription: String {
        guard let value = scoreValue else { return "" }
        let intValue = Int(value)
        if intValue < 40 { return "Low" }
        else if intValue < 60 { return "Below Target" }
        else { return "Suboptimal" }
    }
}

// MARK: - Common Therapeutic Categories

struct TherapeuticCategory {
    static let medicationCategories = [
        "Cardiovascular",
        "Diabetes",
        "Thyroid",
        "Mental Health",
        "Pain Management",
        "Allergy",
        "Gastrointestinal",
        "Respiratory",
        "Hormone",
        "Antibiotic",
        "Other"
    ]

    static let supplementCategories = [
        "Vitamin",
        "Mineral",
        "Amino Acid",
        "Herbal",
        "Probiotic",
        "Omega/Fish Oil",
        "Antioxidant",
        "Adaptogen",
        "Enzyme",
        "Other"
    ]

    static let peptideCategories = [
        "Growth Hormone",
        "Repair/Recovery",
        "Cognitive",
        "Metabolic",
        "Immune",
        "Anti-Aging",
        "Other"
    ]

    static let hormoneCategories = [
        "Testosterone",
        "Estrogen",
        "Progesterone",
        "Thyroid",
        "Growth Hormone",
        "DHEA",
        "Cortisol",
        "Insulin",
        "Melatonin",
        "Other"
    ]
}
