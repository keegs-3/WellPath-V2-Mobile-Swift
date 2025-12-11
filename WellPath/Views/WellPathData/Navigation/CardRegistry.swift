//
//  CardRegistry.swift
//  WellPath
//
//  Central registry that maps metric IDs to their card components.
//  Used by favorites to display the same cards as category screens.
//  Database provides hierarchy/names, Swift defines cards & views.
//

import SwiftUI

/// Registry that provides card views for metric IDs
/// Cards are the same components used in category screens
enum CardRegistry {

    /// Returns a card view for the given metric ID
    /// Falls back to GenericMetricCard for metrics without custom cards
    /// sectionId: links to display_category_sections for colors/icons in favorites
    /// NOTE: Routing uses sectionId (database-driven) rather than deprecated pillar field
    @MainActor @ViewBuilder
    static func card(for metricId: String, color: Color, pillar: String, displayName: String? = nil, sectionId: String? = nil) -> some View {
        // Route based on sectionId (database-driven) or fall back to pillar for backwards compatibility
        let isBiomarker = sectionId == "NAV_BIOMARKERS" || metricId.hasPrefix("CARD_BIO_") || pillar == "Biomarker"
        let isBiometric = sectionId == "NAV_BIOMETRICS" || pillar == "Biometrics"

        // Handle biomarker cards
        if isBiomarker {
            BiomarkerFavoriteCard(
                cardId: metricId,
                displayName: displayName ?? metricId,
                color: color,
                sectionId: sectionId ?? "NAV_BIOMARKERS"
            )
        }
        // Handle biometric cards - use individual card files for explicit routing
        else if isBiometric {
            switch metricId {
            case "CARD_BMI", "DISP_BMI":
                BMICard(color: color, pillar: pillar)
            case "CARD_BODYWEIGHT", "DISP_BODYWEIGHT":
                BodyWeightCard(color: color, pillar: pillar)
            case "CARD_BODYFAT", "CARD_BODY_FAT", "DISP_BODYFAT":
                BodyFatCard(color: color, pillar: pillar)
            case "CARD_VISCERAL_FAT", "DISP_VISCERAL_FAT":
                VisceralFatCard(color: color, pillar: pillar)
            case "CARD_ASMI", "DISP_ASMI":
                ASMICard(color: color, pillar: pillar)
            case "CARD_BLOOD_PRESSURE", "DISP_BLOOD_PRESSURE":
                BloodPressureCard(color: color, pillar: pillar)
            case "CARD_HRV", "DISP_HRV":
                HRVCard(color: color, pillar: pillar)
            case "CARD_RESTING_HR", "DISP_RESTING_HR":
                RestingHRCard(color: color, pillar: pillar)
            case "CARD_GRIP_STRENGTH", "DISP_GRIP_STRENGTH":
                GripStrengthCard(color: color, pillar: pillar)
            case "CARD_WAIST_HIP", "CARD_WAIST_TO_HIP", "DISP_WAIST_HIP":
                WaistHipRatioCard(color: color, pillar: pillar)
            case "CARD_VO2_MAX", "CARD_VO2MAX", "DISP_VO2_MAX":
                VO2MaxCard(color: color, pillar: pillar)
            default:
                // Fallback for unknown biometrics
                BiometricFavoriteCard(
                    cardId: metricId,
                    displayName: displayName ?? metricId,
                    color: color,
                    sectionId: sectionId ?? "NAV_BIOMETRICS"
                )
            }
        }
        else {
        switch metricId {
        // MARK: - Protein Cards
        case "DISP_PROTEIN_GRAMS":
            ProteinAmountCard(color: color, pillar: pillar)
        case "DISP_PROTEIN_TIMING":
            ProteinTimingCard(color: color, pillar: pillar)
        case "DISP_PROTEIN_TYPE":
            ProteinTypeCard(color: color, pillar: pillar)
        case "DISP_PROTEIN_RATIO":
            ProteinRatioCard(color: color, pillar: pillar)

        // MARK: - Vegetable Cards
        case "DISP_VEGETABLES_SERVINGS":
            VegetablesServingsCard(color: color, pillar: pillar)
        case "DISP_VEGETABLES_TIMING":
            VegetablesTimingCard(color: color, pillar: pillar)
        case "DISP_VEGETABLES_TYPE":
            VegetablesTypeCard(color: color, pillar: pillar)

        // MARK: - Legume Cards
        case "DISP_LEGUMES_SERVINGS":
            LegumesServingsCard(color: color, pillar: pillar)
        case "DISP_LEGUMES_TIMING":
            LegumesTimingCard(color: color, pillar: pillar)
        case "DISP_LEGUMES_TYPE":
            LegumesTypeCard(color: color, pillar: pillar)

        // MARK: - Fruit Cards
        case "DISP_FRUITS_SERVINGS":
            FruitsServingsCard(color: color, pillar: pillar)
        case "DISP_FRUITS_TIMING":
            FruitsTimingCard(color: color, pillar: pillar)
        case "DISP_FRUITS_TYPE":
            FruitsTypeCard(color: color, pillar: pillar)

        // MARK: - Whole Grain Cards
        case "DISP_WHOLE_GRAINS_SERVINGS":
            WholeGrainsServingsCard(color: color, pillar: pillar)
        case "DISP_WHOLE_GRAINS_TIMING":
            WholeGrainsTimingCard(color: color, pillar: pillar)
        case "DISP_WHOLE_GRAINS_TYPE":
            WholeGrainsTypeCard(color: color, pillar: pillar)

        // MARK: - Sleep Analysis Cards (database-driven viewId)
        case "DISP_SLEEP_STAGES":
            SleepStagesCard(color: color, pillar: pillar, viewId: metricId)
        case "DISP_SLEEP_AMOUNTS":
            SleepAmountsCard(color: color, pillar: pillar, viewId: metricId)
        case "DISP_SLEEP_PERCENTAGES":
            SleepPercentagesCard(color: color, pillar: pillar, viewId: metricId)
        case "DISP_SLEEP_COMPARISONS":
            SleepComparisonsCard(color: color, pillar: pillar, viewId: metricId)

        // MARK: - Sleep Duration & Consistency (simple cards)
        case "CARD_SLEEP_DURATION", "DISP_SLEEP_DURATION":
            SleepDurationCard(color: color, pillar: pillar, sectionId: sectionId ?? "NAV_SLEEP")
        case "CARD_SLEEP_CONSISTENCY", "DISP_SLEEP_CONSISTENCY":
            SleepConsistencyCard(color: color, pillar: pillar, sectionId: sectionId ?? "NAV_SLEEP")

        // MARK: - Steps (direct-to-view metric)
        case "CARD_STEPS", "DISP_STEPS":
            StepsCard(color: color, pillar: pillar, sectionId: sectionId ?? "NAV_STEPS")

        // MARK: - Default (Generic Card)
        default:
            GenericMetricCard(metricId: metricId, color: color, pillar: pillar)
        }
        }
    }


    /// Check if a custom card exists for the metric
    static func hasCustomCard(for metricId: String) -> Bool {
        switch metricId {
        // Protein
        case "DISP_PROTEIN_GRAMS", "DISP_PROTEIN_TIMING", "DISP_PROTEIN_TYPE", "DISP_PROTEIN_RATIO":
            return true
        // Vegetables
        case "DISP_VEGETABLES_SERVINGS", "DISP_VEGETABLES_TIMING", "DISP_VEGETABLES_TYPE":
            return true
        // Legumes
        case "DISP_LEGUMES_SERVINGS", "DISP_LEGUMES_TIMING", "DISP_LEGUMES_TYPE":
            return true
        // Fruits
        case "DISP_FRUITS_SERVINGS", "DISP_FRUITS_TIMING", "DISP_FRUITS_TYPE":
            return true
        // Whole Grains
        case "DISP_WHOLE_GRAINS_SERVINGS", "DISP_WHOLE_GRAINS_TIMING", "DISP_WHOLE_GRAINS_TYPE":
            return true
        // Sleep Analysis
        case "DISP_SLEEP_STAGES", "DISP_SLEEP_AMOUNTS", "DISP_SLEEP_PERCENTAGES", "DISP_SLEEP_COMPARISONS":
            return true
        // Sleep Duration & Consistency
        case "DISP_SLEEP_DURATION", "DISP_SLEEP_CONSISTENCY",
             "CARD_SLEEP_DURATION", "CARD_SLEEP_CONSISTENCY":
            return true
        // Steps
        case "DISP_STEPS", "CARD_STEPS":
            return true
        default:
            return false
        }
    }
}

// MARK: - Generic Metric Card (fallback for unknown metrics)

struct GenericMetricCard: View {
    let metricId: String
    let color: Color
    let pillar: String

    @StateObject private var viewModel: StandardMetricViewModel

    init(metricId: String, color: Color, pillar: String) {
        self.metricId = metricId
        self.color = color
        self.pillar = pillar
        _viewModel = StateObject(wrappedValue: StandardMetricViewModel(metricId: metricId))
    }

    var body: some View {
        MetricCardView(
            title: viewModel.displayMetric?.metricName ?? metricId,
            color: color,
            metricId: metricId,
            pillar: pillar
        ) {
            GenericMiniCard(viewId: metricId, color: color)
        } fullScreen: {
            MetricDetailByIdView(viewId: metricId, pillar: pillar, color: color)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// Note: SleepDurationCard is in Sleep/SleepDuration/Cards/SleepDurationCard.swift
// Note: SleepConsistencyCard is in Sleep/SleepConsistency/Cards/SleepConsistencyCard.swift

// MARK: - Biomarker Favorite Card

struct BiomarkerFavoriteCard: View {
    let cardId: String
    let displayName: String
    let color: Color
    let sectionId: String  // For favorites: NAV_BIOMARKERS

    @StateObject private var viewModel = BiomarkerViewModel()

    private var biomarkerData: BiomarkerDisplayData? {
        viewModel.biomarkerData[displayName]
    }

    var body: some View {
        MetricCardView(
            title: displayName,
            color: color,
            metricId: cardId,
            pillar: "Biomarker",
            cardId: cardId,
            sectionId: sectionId
        ) {
            // Mini card content
            if let data = biomarkerData {
                BiomarkerMiniCard(biomarker: data, color: color)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 50)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 50)
            }
        } fullScreen: {
            GenericBiomarkerDetailView(
                biomarkerName: displayName,
                viewModel: viewModel
            )
        }
        .task {
            await viewModel.loadAll()
        }
    }
}

// MARK: - Biometric Favorite Card

struct BiometricFavoriteCard: View {
    let cardId: String
    let displayName: String
    let color: Color
    let sectionId: String  // For favorites: NAV_BIOMETRICS

    @StateObject private var viewModel = BiometricFavoriteViewModel()

    var body: some View {
        MetricCardView(
            title: displayName,
            color: color,
            metricId: cardId,
            pillar: "Biometrics",
            cardId: cardId,
            sectionId: sectionId
        ) {
            // Mini card content
            if let cardData = viewModel.cardData {
                BiometricFavoriteMiniCard(data: cardData, color: color)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 50)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 50)
            }
        } fullScreen: {
            BiometricDetailRouter(cardId: cardId, displayName: displayName, color: color)
        }
        .task {
            await viewModel.loadByCardId(cardId)
        }
    }
}

/// Mini card content for biometrics (for favorites)
struct BiometricFavoriteMiniCard: View {
    let data: BiometricFavoriteData
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "waveform.path.ecg")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(data.formattedValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    if !data.unit.isEmpty {
                        Text(data.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if !data.optimalRange.isEmpty {
                    Text("Optimal: \(data.optimalRange)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(data.status.uppercased())
                .font(.caption2)
                .foregroundColor(statusColor(data.status))
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "optimal": return .green
        case "in-range", "in range": return .yellow
        case "out-of-range", "out of range": return .red
        default: return .secondary
        }
    }
}

/// Lightweight data for biometric favorite cards
struct BiometricFavoriteData {
    let name: String
    let value: Double
    let formattedValue: String
    let unit: String
    let status: String
    let optimalRange: String
}

/// Routes to the appropriate biometric detail view based on cardId
struct BiometricDetailRouter: View {
    let cardId: String
    let displayName: String
    let color: Color

    @StateObject private var viewModel = BiometricDetailRouterViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                routedView
            }
        }
        .metricScreenBackground(color: color)
        .task {
            await viewModel.loadMetricForCard(cardId: cardId, displayName: displayName)
        }
    }

    @ViewBuilder
    private var routedView: some View {
        // Route to specific biometric views based on card ID
        switch cardId {
        case "CARD_BMI", "DISP_BMI":
            BMIView(color: color)
        case "CARD_BODYWEIGHT", "DISP_BODYWEIGHT":
            BodyWeightView(color: color)
        case "CARD_BODYFAT", "CARD_BODY_FAT", "DISP_BODYFAT":
            BodyFatView(color: color)
        case "CARD_VISCERAL_FAT", "DISP_VISCERAL_FAT":
            VisceralFatView(color: color)
        case "CARD_SKELETAL_MUSCLE", "CARD_ASMM", "DISP_SMM_FFM":
            ASMIView(color: color)
        case "CARD_BLOOD_PRESSURE", "CARD_SYSTOLIC_BP", "CARD_DIASTOLIC_BP", "DISP_BLOOD_PRESSURE":
            BloodPressureView(color: color)
        case "CARD_HRV", "DISP_HRV":
            HRVView(color: color)
        case "CARD_HEART_RATE", "CARD_RESTING_HEART_RATE", "CARD_RESTING_HR", "DISP_RESTING_HR":
            if let metric = viewModel.metric {
                RestingHRView(metric: metric, color: color)
            } else {
                GenericBiometricDetailView(name: displayName, color: color)
            }
        case "CARD_GRIP_STRENGTH", "DISP_GRIP_STRENGTH":
            GripStrengthView(color: color)
        case "CARD_WAIST_CIRCUMFERENCE", "DISP_WAIST_CIRCUMFERENCE":
            WaistCircumferenceView(color: color)
        case "CARD_HIP_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE":
            HipCircumferenceView(color: color)
        case "CARD_WAIST_TO_HIP", "CARD_WAIST_HIP", "DISP_WAIST_HIP":
            WaistHipRatioView(color: color)
        case "CARD_VO2MAX", "CARD_VO2_MAX", "DISP_VO2_MAX":
            if let metric = viewModel.metric {
                VO2MaxView(metric: metric, color: color)
            } else {
                GenericBiometricDetailView(name: displayName, color: color)
            }
        default:
            // Fallback to generic biometric detail
            GenericBiometricDetailView(name: displayName, color: color)
        }
    }
}

/// ViewModel to load DisplayMetric for biometric detail views
@MainActor
class BiometricDetailRouterViewModel: ObservableObject {
    @Published var metric: DisplayMetric?
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadMetricForCard(cardId: String, displayName: String) async {
        isLoading = true

        do {
            // Look up the view_id from display_view_cards
            // Try by card_id first, then by view_id (favorites may pass either)
            struct CardInfo: Codable {
                let viewId: String?

                enum CodingKeys: String, CodingKey {
                    case viewId = "view_id"
                }
            }

            var cards: [CardInfo] = try await supabase
                .from("display_view_cards")
                .select("view_id")
                .eq("card_id", value: cardId)
                .limit(1)
                .execute()
                .value

            // If not found by card_id, try by view_id (DISP_* ids)
            if cards.isEmpty {
                cards = try await supabase
                    .from("display_view_cards")
                    .select("view_id")
                    .eq("view_id", value: cardId)
                    .limit(1)
                    .execute()
                    .value
            }

            if let viewId = cards.first?.viewId {
                // Load the display metric from display_views
                let metrics: [DisplayMetric] = try await supabase
                    .from("display_views")
                    .select()
                    .eq("view_id", value: viewId)
                    .limit(1)
                    .execute()
                    .value

                metric = metrics.first
            }

            // Create a fallback metric if not found
            if metric == nil {
                metric = DisplayMetric(
                    id: cardId,
                    metricId: cardId,
                    metricName: displayName,
                    description: nil,
                    pillar: "Biometrics",
                    chartTypeId: nil,
                    isActive: true,
                    aboutContent: nil,
                    longevityImpact: nil,
                    quickTips: nil
                )
            }

        } catch {
            print("Error loading metric for card: \(error)")
            // Create fallback metric on error
            metric = DisplayMetric(
                id: cardId,
                metricId: cardId,
                metricName: displayName,
                description: nil,
                pillar: "Biometrics",
                chartTypeId: nil,
                isActive: true,
                aboutContent: nil,
                longevityImpact: nil,
                quickTips: nil
            )
        }

        isLoading = false
    }
}

/// Generic biometric detail view fallback - uses existing BiometricFavoriteDetailView
struct GenericBiometricDetailView: View {
    let name: String
    let color: Color

    var body: some View {
        // Reuse existing detail view that handles loading biometric data
        BiometricFavoriteDetailView(biometricName: name)
    }
}

// MARK: - Biometric Favorite ViewModel

@MainActor
class BiometricFavoriteViewModel: ObservableObject {
    @Published var cardData: BiometricFavoriteData?
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadByCardId(_ cardId: String) async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // Get card name and view_id from display_view_cards
            struct CardInfo: Codable {
                let cardName: String
                let viewId: String?
                enum CodingKeys: String, CodingKey {
                    case cardName = "card_name"
                    case viewId = "view_id"
                }
            }

            var cards: [CardInfo] = try await supabase
                .from("display_view_cards")
                .select("card_name, view_id")
                .eq("card_id", value: cardId)
                .limit(1)
                .execute()
                .value

            var viewIdForDeps: String? = nil

            // If not found by card_id, try by view_id (DISP_* ids)
            if cards.isEmpty {
                cards = try await supabase
                    .from("display_view_cards")
                    .select("card_name, view_id")
                    .eq("view_id", value: cardId)
                    .limit(1)
                    .execute()
                    .value
                // If we found by view_id, use that directly
                viewIdForDeps = cardId
            } else {
                // Found by card_id, use the card's view_id
                viewIdForDeps = cards.first?.viewId
            }

            guard let card = cards.first, let viewId = viewIdForDeps else {
                isLoading = false
                return
            }

            // Get primary sample_quantity_type from display_views_dependencies via view_id
            struct DependencyInfo: Codable {
                let sampleQuantityType: String?
                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let deps: [DependencyInfo] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type")
                .eq("view_id", value: viewId)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value

            guard let quantityType = deps.first?.sampleQuantityType else {
                isLoading = false
                return
            }

            // Load the latest sample value
            struct SampleResult: Codable {
                let quantityValue: Double
                let quantityUnit: String?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                }
            }

            let samples: [SampleResult] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, quantity_unit, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: false)
                .limit(1)
                .execute()
                .value

            if let sample = samples.first {
                cardData = BiometricFavoriteData(
                    name: card.cardName,
                    value: sample.quantityValue,
                    formattedValue: String(format: "%.1f", sample.quantityValue),
                    unit: sample.quantityUnit ?? "",
                    status: "Optimal", // Would need range lookup for accurate status
                    optimalRange: ""
                )
            }

        } catch {
            print("Error loading biometric card: \(error)")
        }

        isLoading = false
    }
}
