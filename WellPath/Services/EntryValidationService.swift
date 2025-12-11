//
//  EntryValidationService.swift
//  WellPath
//
//  Shared validation service for data entry views
//  Fetches soft/hard thresholds from sample_quantity_types
//

import Foundation
import Supabase

// MARK: - Validation Result

enum ValidationResult: Equatable {
    case valid
    case warning(String)  // Outside soft limits - prompt user to confirm
    case invalid(String)  // Outside hard limits - blocked

    var isAllowed: Bool {
        switch self {
        case .valid, .warning: return true
        case .invalid: return false
        }
    }

    var requiresConfirmation: Bool {
        if case .warning = self { return true }
        return false
    }
}

// MARK: - Validation Thresholds

struct ValidationThresholds {
    let quantityType: String
    let softMin: Double?
    let softMax: Double?
    let hardMin: Double?
    let hardMax: Double?
    let validationUnit: String?
    let canonicalUnit: String

    /// Validate a value (should be in canonical units)
    func validate(_ value: Double, displayUnit: String? = nil) -> ValidationResult {
        let unitLabel = displayUnit ?? validationUnit ?? canonicalUnit

        // Check hard limits first (blocked)
        if let hardMin = hardMin, value < hardMin {
            return .invalid("Value must be at least \(formatValue(hardMin)) \(unitLabel)")
        }
        if let hardMax = hardMax, value > hardMax {
            return .invalid("Value cannot exceed \(formatValue(hardMax)) \(unitLabel)")
        }

        // Check soft limits (warning)
        if let softMin = softMin, value < softMin {
            return .warning("This value seems low (\(formatValue(value)) \(unitLabel)). Are you sure?")
        }
        if let softMax = softMax, value > softMax {
            return .warning("This value seems high (\(formatValue(value)) \(unitLabel)). Are you sure?")
        }

        return .valid
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Validation Service

@MainActor
class EntryValidationService: ObservableObject {
    static let shared = EntryValidationService()

    private let supabase = SupabaseManager.shared.client
    private var cache: [String: ValidationThresholds] = [:]

    private init() {}

    /// Get validation thresholds for a quantity type
    func getThresholds(for quantityType: String) async -> ValidationThresholds? {
        // Check cache first
        if let cached = cache[quantityType] {
            return cached
        }

        do {
            struct ThresholdRow: Codable {
                let quantityType: String
                let canonicalUnit: String
                let softMin: Double?
                let softMax: Double?
                let hardMin: Double?
                let hardMax: Double?
                let validationUnit: String?

                enum CodingKeys: String, CodingKey {
                    case quantityType = "quantity_type"
                    case canonicalUnit = "canonical_unit"
                    case softMin = "soft_min"
                    case softMax = "soft_max"
                    case hardMin = "hard_min"
                    case hardMax = "hard_max"
                    case validationUnit = "validation_unit"
                }
            }

            let results: [ThresholdRow] = try await supabase
                .from("sample_quantity_types")
                .select("quantity_type, canonical_unit, soft_min, soft_max, hard_min, hard_max, validation_unit")
                .eq("quantity_type", value: quantityType)
                .limit(1)
                .execute()
                .value

            guard let row = results.first else { return nil }

            let thresholds = ValidationThresholds(
                quantityType: row.quantityType,
                softMin: row.softMin,
                softMax: row.softMax,
                hardMin: row.hardMin,
                hardMax: row.hardMax,
                validationUnit: row.validationUnit,
                canonicalUnit: row.canonicalUnit
            )

            // Cache for future use
            cache[quantityType] = thresholds
            return thresholds

        } catch {
            print("Error loading validation thresholds for \(quantityType): \(error)")
            return nil
        }
    }

    /// Validate a value for a quantity type (value should be in canonical units)
    func validate(_ value: Double, for quantityType: String, displayUnit: String? = nil) async -> ValidationResult {
        guard let thresholds = await getThresholds(for: quantityType) else {
            // No thresholds defined - allow any value
            return .valid
        }
        return thresholds.validate(value, displayUnit: displayUnit)
    }

    /// Clear the cache (useful if thresholds are updated)
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Validation Alert Modifier

import SwiftUI

struct ValidationAlertModifier: ViewModifier {
    @Binding var validationResult: ValidationResult?
    @Binding var showingWarning: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Confirm Entry", isPresented: $showingWarning) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Button("Save Anyway") {
                    onConfirm()
                }
            } message: {
                if case .warning(let message) = validationResult {
                    Text(message)
                }
            }
    }
}

extension View {
    func validationAlert(
        result: Binding<ValidationResult?>,
        showingWarning: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(ValidationAlertModifier(
            validationResult: result,
            showingWarning: showingWarning,
            onConfirm: onConfirm,
            onCancel: onCancel
        ))
    }
}
