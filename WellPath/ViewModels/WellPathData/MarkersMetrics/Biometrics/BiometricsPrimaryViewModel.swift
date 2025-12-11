//
//  BiometricsPrimaryViewModel.swift
//  WellPath
//
//  ViewModel for loading Biometrics primary screen with all biometric display_view_cards
//

import Foundation
import Supabase

/// Card data from display_view_cards with joined view info
/// Named BiometricViewCardData to avoid conflict with BiometricCardData in BiometricModels.swift
struct BiometricViewCardData: Codable, Identifiable {
    let id: String
    let cardId: String
    let cardName: String
    let description: String?
    let viewId: String
    let displayOrder: Int?
    let isActive: Bool?
    // Note: sample_quantity_type is in display_views_dependencies junction table (via view_id)

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case cardName = "card_name"
        case description
        case viewId = "view_id"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }
}

/// Combined biometric metric data for display (bridges old DisplayMetric interface)
struct BiometricPrimaryMetric: Identifiable {
    let id: String
    let card: BiometricViewCardData

    var displayName: String {
        card.cardName
    }

    var displayDescription: String? {
        card.description
    }

    // Bridge to DisplayMetric for existing views
    var asDisplayMetric: DisplayMetric {
        DisplayMetric(
            id: card.id,
            metricId: card.viewId,
            metricName: card.cardName,
            description: card.description,
            pillar: nil,
            chartTypeId: nil,
            isActive: card.isActive,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
        )
    }
}

@MainActor
class BiometricsPrimaryViewModel: ObservableObject {
    @Published var biometricMetrics: [BiometricPrimaryMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    // Individual metric references for card titles
    @Published var bmiMetric: DisplayMetric?
    @Published var bodyFatMetric: DisplayMetric?
    @Published var gripStrengthMetric: DisplayMetric?
    @Published var hrvMetric: DisplayMetric?
    @Published var smmFfmMetric: DisplayMetric?
    @Published var restingHrMetric: DisplayMetric?
    @Published var visceralFatMetric: DisplayMetric?
    @Published var vo2MaxMetric: DisplayMetric?
    @Published var waistHipMetric: DisplayMetric?
    @Published var weightMetric: DisplayMetric?
    @Published var bloodPressureMetric: DisplayMetric?
    @Published var waistCircumferenceMetric: DisplayMetric?
    @Published var hipCircumferenceMetric: DisplayMetric?

    private let supabase = SupabaseManager.shared.client

    // Biometric view IDs we want to display (cards link via view_id)
    private let biometricViewIds = [
        "DISP_BMI",
        "DISP_BODYFAT",
        "DISP_GRIP_STRENGTH",
        "DISP_HRV",
        "DISP_SMM_FFM",
        "DISP_RESTING_HR",
        "DISP_VISCERAL_FAT",
        "DISP_VO2_MAX",
        "DISP_WAIST_HIP",
        "DISP_BODYWEIGHT",
        "DISP_BLOOD_PRESSURE",
        "DISP_WAIST_CIRCUMFERENCE",
        "DISP_HIP_CIRCUMFERENCE"
    ]

    init() {}

    /// Load all biometric cards from display_view_cards
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading Biometrics primary screen from display_view_cards")

            // Query biometric cards from display_view_cards
            let results: [BiometricViewCardData] = try await supabase
                .from("display_view_cards")
                .select("id, card_id, card_name, description, view_id, display_order, is_active")
                .in("view_id", values: biometricViewIds)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Map results to individual metrics (bridge to DisplayMetric for existing views)
            for card in results {
                let metric = BiometricPrimaryMetric(id: card.viewId, card: card).asDisplayMetric
                switch card.viewId {
                case "DISP_BMI":
                    bmiMetric = metric
                case "DISP_BODYFAT":
                    bodyFatMetric = metric
                case "DISP_GRIP_STRENGTH":
                    gripStrengthMetric = metric
                case "DISP_HRV":
                    hrvMetric = metric
                case "DISP_SMM_FFM":
                    smmFfmMetric = metric
                case "DISP_RESTING_HR":
                    restingHrMetric = metric
                case "DISP_VISCERAL_FAT":
                    visceralFatMetric = metric
                case "DISP_VO2_MAX":
                    vo2MaxMetric = metric
                case "DISP_WAIST_HIP":
                    waistHipMetric = metric
                case "DISP_BODYWEIGHT":
                    weightMetric = metric
                case "DISP_BLOOD_PRESSURE":
                    bloodPressureMetric = metric
                case "DISP_WAIST_CIRCUMFERENCE":
                    waistCircumferenceMetric = metric
                case "DISP_HIP_CIRCUMFERENCE":
                    hipCircumferenceMetric = metric
                default:
                    break
                }
            }

            // Create array of metrics for iteration
            biometricMetrics = results.map { BiometricPrimaryMetric(id: $0.viewId, card: $0) }

            print("✅ Loaded \(biometricMetrics.count) biometric cards")
            for metric in biometricMetrics {
                print("   - \(metric.displayName): \(metric.displayDescription ?? "no description")")
            }

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load biometrics: \(errorMessage)"
            print("❌ Error loading biometrics: \(error)")
        }

        isLoading = false
    }
}
