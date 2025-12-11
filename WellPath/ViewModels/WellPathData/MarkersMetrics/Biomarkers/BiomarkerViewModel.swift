//
//  BiomarkerViewModel.swift
//  WellPath
//
//  Single, generic ViewModel for ALL biomarkers
//  Loads from backend display config tables + patient_samples
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class BiomarkerViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The biomarker section from display_category_sections
    @Published var section: BiomarkerSection?

    /// Categories within the biomarker section
    @Published var categories: [BiomarkerCategory] = []

    /// View cards (individual biomarkers) by category
    @Published var cardsByCategory: [String: [BiomarkerViewCard]] = [:]

    /// Mapping of cardId -> sample_clinical_type (from display_views_dependencies)
    /// Biomarkers use clinical_type, NOT quantity_type
    private var cardClinicalTypes: [String: String] = [:]

    /// Complete biomarker display data with values
    @Published var biomarkerData: [String: BiomarkerDisplayData] = [:]

    /// Patient context for range filtering
    @Published var patientContext: BiomarkerPatientContext = BiomarkerPatientContext()

    /// Loading states
    @Published var isLoadingConfig = false
    @Published var isLoadingData = false
    @Published var error: String?

    // MARK: - Private Properties

    private let supabase = SupabaseManager.shared.client
    private let sectionId = "NAV_BIOMARKERS"

    // MARK: - Computed Properties

    var isLoading: Bool {
        isLoadingConfig || isLoadingData
    }

    var sectionColor: Color {
        section?.color ?? Color(hex: "#FF8C00") ?? .orange
    }

    /// All biomarkers sorted by status (out-of-range first)
    var allBiomarkersSorted: [BiomarkerDisplayData] {
        biomarkerData.values.sorted { $0.status.priority < $1.status.priority }
    }

    /// Biomarkers for a specific category
    func biomarkers(for categoryId: String) -> [BiomarkerDisplayData] {
        biomarkerData.values
            .filter { $0.categoryId == categoryId }
            .sorted { $0.status.priority < $1.status.priority }
    }

    /// Count of biomarkers in a category
    func count(for categoryId: String) -> Int {
        biomarkerData.values.filter { $0.categoryId == categoryId }.count
    }

    /// Count of out-of-range biomarkers in a category
    func outOfRangeCount(for categoryId: String) -> Int {
        biomarkerData.values
            .filter { $0.categoryId == categoryId && $0.status == .outOfRange }
            .count
    }

    // MARK: - Load Configuration

    /// Load the display configuration (section, categories, cards)
    func loadConfiguration() async {
        isLoadingConfig = true
        error = nil

        do {
            // Load section
            let sections: [BiomarkerSection] = try await supabase
                .from("display_category_sections")
                .select()
                .eq("section_id", value: sectionId)
                .limit(1)
                .execute()
                .value

            section = sections.first

            // Load categories for this section
            let cats: [BiomarkerCategory] = try await supabase
                .from("display_card_categories")
                .select()
                .eq("section_id", value: sectionId)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            categories = cats

            // Load cards for all biomarker categories
            let categoryIds = cats.map { $0.categoryId }
            let cards: [BiomarkerViewCard] = try await supabase
                .from("display_view_cards")
                .select()
                .in("category_id", values: categoryIds)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Group cards by category
            cardsByCategory = Dictionary(grouping: cards) { $0.categoryId }

            // Load sample_clinical_types from display_views_dependencies via view_id
            // Biomarkers use clinical_type (not quantity_type)
            let viewIds = cards.compactMap { $0.viewId }
            struct ViewDependency: Codable {
                let viewId: String
                let sampleClinicalType: String?
                enum CodingKeys: String, CodingKey {
                    case viewId = "view_id"
                    case sampleClinicalType = "sample_clinical_type"
                }
            }

            let dependencies: [ViewDependency] = try await supabase
                .from("display_views_dependencies")
                .select("view_id, sample_clinical_type")
                .in("view_id", values: viewIds)
                .eq("is_primary", value: true)
                .execute()
                .value

            // Build viewId -> sample_clinical_type mapping
            let viewToClinicalType = Dictionary(uniqueKeysWithValues:
                dependencies.compactMap { dep -> (String, String)? in
                    guard let cType = dep.sampleClinicalType else { return nil }
                    return (dep.viewId, cType)
                }
            )

            // Build cardId -> sample_clinical_type mapping via viewId
            cardClinicalTypes = Dictionary(uniqueKeysWithValues:
                cards.compactMap { card -> (String, String)? in
                    guard let viewId = card.viewId,
                          let cType = viewToClinicalType[viewId] else { return nil }
                    return (card.cardId, cType)
                }
            )

        } catch {
            self.error = "Failed to load configuration: \(error.localizedDescription)"
            print("Error loading biomarker config: \(error)")
        }

        isLoadingConfig = false
    }

    // MARK: - Load Patient Data

    /// Load patient context and all biomarker values
    func loadPatientData() async {
        isLoadingData = true
        error = nil

        do {
            let patientId = try await supabase.auth.session.user.id

            // Load patient context in parallel with samples
            async let contextTask = loadPatientContext(patientId: patientId)
            async let samplesTask = loadAllBiomarkerSamples(patientId: patientId)

            let (context, samplesByClinicalType) = try await (contextTask, samplesTask)
            patientContext = context

            // Load ranges using clinical_type (direct join, no URL length issues)
            await loadBiomarkerDetails(
                clinicalTypes: Array(samplesByClinicalType.keys),
                samplesByClinicalType: samplesByClinicalType
            )

        } catch {
            self.error = "Failed to load patient data: \(error.localizedDescription)"
            print("Error loading patient data: \(error)")
        }

        isLoadingData = false
    }

    /// Convenience method to load everything
    func loadAll() async {
        await loadConfiguration()
        await loadPatientData()
    }

    // MARK: - Private Helpers

    private func loadPatientContext(patientId: UUID) async -> BiomarkerPatientContext {
        do {
            struct CharacteristicResult: Codable {
                let characteristicTypeName: String
                let valueText: String?
                let valueDate: String?
                let valueBoolean: Bool?

                enum CodingKeys: String, CodingKey {
                    case characteristicTypeName = "characteristic_type_name"
                    case valueText = "value_text"
                    case valueDate = "value_date"
                    case valueBoolean = "value_boolean"
                }
            }

            let results: [CharacteristicResult] = try await supabase
                .from("patient_characteristics")
                .select("characteristic_type_name, value_text, value_date, value_boolean")
                .eq("patient_id", value: patientId.uuidString)
                .in("characteristic_type_name", values: [
                    "biological_sex",
                    "date_of_birth",
                    "menopausal_status",
                    "athlete_status"
                ])
                .execute()
                .value

            var gender: String?
            var age: Int?
            var menopausalStatus: String?
            var isAthlete = false

            for char in results {
                switch char.characteristicTypeName {
                case "biological_sex":
                    gender = char.valueText?.lowercased()
                case "date_of_birth":
                    if let dobString = char.valueDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let birthDate = formatter.date(from: dobString) {
                            age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
                        }
                    }
                case "menopausal_status":
                    menopausalStatus = char.valueText
                case "athlete_status":
                    isAthlete = char.valueBoolean ?? false
                default:
                    break
                }
            }

            return BiomarkerPatientContext(
                gender: gender,
                age: age,
                menopausalStatus: menopausalStatus,
                isAthlete: isAthlete
            )
        } catch {
            print("Could not load patient context: \(error)")
            return BiomarkerPatientContext()
        }
    }

    private func loadAllBiomarkerSamples(patientId: UUID) async throws -> [String: [BiomarkerSample]] {
        // Get all cards
        let allCards = cardsByCategory.values.flatMap { $0 }

        // Collect clinical_types from cardClinicalTypes mapping
        let clinicalTypes = allCards.compactMap { cardClinicalTypes[$0.cardId] }

        guard !clinicalTypes.isEmpty else {
            print("⚠️ No sample_clinical_type mappings found for biomarker cards")
            return [:]
        }

        print("📊 Loading biomarker samples for \(clinicalTypes.count) clinical types")

        // Fetch all samples from patient_clinical_samples using clinical_types
        let samples: [BiomarkerSample] = try await supabase
            .from("patient_clinical_samples")
            .select("id, patient_id, clinical_type, value, unit, sample_time, source")
            .eq("patient_id", value: patientId)
            .in("clinical_type", values: clinicalTypes)
            .order("sample_time", ascending: false)
            .execute()
            .value

        print("📊 Loaded \(samples.count) biomarker samples")

        // Group by clinical_type (the canonical key)
        let result = Dictionary(grouping: samples) { $0.clinicalType }
        return result
    }

    private func loadBiomarkerDetails(
        clinicalTypes: [String],
        samplesByClinicalType: [String: [BiomarkerSample]]
    ) async {
        guard !clinicalTypes.isEmpty else { return }

        do {
            // Fetch all ranges from sample_scoring_ranges using clinical_type
            let allRanges: [BiomarkerRange] = try await supabase
                .from("sample_scoring_ranges")
                .select()
                .in("clinical_type", values: clinicalTypes)
                .order("range_low", ascending: true)
                .execute()
                .value

            // Group ranges by clinical_type (the canonical key)
            let rangesByClinicalType = Dictionary(grouping: allRanges) { $0.clinicalType ?? "" }


            // Find card info by clinical_type (using cardClinicalTypes mapping)
            let cardByClinicalType = Dictionary(uniqueKeysWithValues:
                cardsByCategory.values.flatMap { $0 }
                    .compactMap { card -> (String, BiomarkerViewCard)? in
                        guard let cType = cardClinicalTypes[card.cardId] else { return nil }
                        return (cType, card)
                    }
            )

            // Build display data for each biomarker
            var newBiomarkerData: [String: BiomarkerDisplayData] = [:]

            for clinicalType in clinicalTypes {
                guard let samples = samplesByClinicalType[clinicalType],
                      let latestSample = samples.first,
                      let card = cardByClinicalType[clinicalType] else { continue }

                let ranges = rangesByClinicalType[clinicalType] ?? []
                let filteredRanges = patientContext.filterRanges(ranges)


                let formattedValue = BiomarkerDisplayData.formatValue(
                    latestSample.value,
                    format: nil // format comes from ranges if needed
                )

                let unitDisplay = BiomarkerDisplayData.formatUnit(latestSample.unit)

                let displayData = BiomarkerDisplayData(
                    cardId: card.cardId,
                    viewId: card.viewId,  // For loading education sections
                    name: card.cardName,
                    value: latestSample.value,
                    formattedValue: formattedValue,
                    unit: latestSample.unit,
                    unitDisplay: unitDisplay,
                    lastUpdated: latestSample.sampleTime,
                    ranges: filteredRanges,
                    category: nil,
                    categoryId: card.categoryId,
                    historicalValues: samples  // All samples for infinite scroll
                )

                // Key by card name for UI lookups
                newBiomarkerData[card.cardName] = displayData
            }

            biomarkerData = newBiomarkerData

        } catch {
            print("Error loading biomarker details: \(error)")
        }
    }

    // MARK: - Single Biomarker Loading

    /// Load data for a single biomarker (for detail view refresh)
    func loadSingleBiomarker(name: String) async -> BiomarkerDisplayData? {
        do {
            let patientId = try await supabase.auth.session.user.id

            // Find the card for this biomarker to get sample_clinical_type
            let card = cardsByCategory.values.flatMap { $0 }.first { $0.cardName == name }

            var clinicalType: String?
            var cardId: String?
            var viewId: String?
            var categoryId: String?

            // Try cache first
            if let foundCard = card {
                cardId = foundCard.cardId
                viewId = foundCard.viewId
                categoryId = foundCard.categoryId
                clinicalType = cardClinicalTypes[foundCard.cardId]
            }

            // If no clinical type from cache, query database directly by display_name
            // This makes favorites work even if cards haven't been loaded yet
            if clinicalType == nil {
                struct ClinicalTypeResult: Codable {
                    let clinicalType: String
                    enum CodingKeys: String, CodingKey {
                        case clinicalType = "clinical_type"
                    }
                }

                let results: [ClinicalTypeResult] = try await supabase
                    .from("sample_clinical_types")
                    .select("clinical_type")
                    .eq("display_name", value: name)
                    .limit(1)
                    .execute()
                    .value

                clinicalType = results.first?.clinicalType
            }

            guard let clinicalType = clinicalType else {
                print("⚠️ No clinical_type found for biomarker: \(name)")
                return nil
            }

            // Load all samples from patient_clinical_samples (biomarkers are sparse - quarterly max)
            // No limit needed for infinite scroll - 10 years = ~40 samples max
            let samples: [BiomarkerSample] = try await supabase
                .from("patient_clinical_samples")
                .select("id, patient_id, clinical_type, value, unit, sample_time, source")
                .eq("patient_id", value: patientId)
                .eq("clinical_type", value: clinicalType)
                .order("sample_time", ascending: false)
                .execute()
                .value

            guard let latestSample = samples.first else { return nil }

            // Load ranges from sample_scoring_ranges using clinical_type
            let ranges: [BiomarkerRange] = try await supabase
                .from("sample_scoring_ranges")
                .select()
                .eq("clinical_type", value: clinicalType)
                .order("range_low", ascending: true)
                .execute()
                .value

            let filteredRanges = patientContext.filterRanges(ranges)

            let formattedValue = BiomarkerDisplayData.formatValue(
                latestSample.value,
                format: nil
            )

            let unitDisplay = BiomarkerDisplayData.formatUnit(latestSample.unit)

            return BiomarkerDisplayData(
                cardId: cardId ?? clinicalType,
                viewId: viewId,  // For loading education sections
                name: name,
                value: latestSample.value,
                formattedValue: formattedValue,
                unit: latestSample.unit,
                unitDisplay: unitDisplay,
                lastUpdated: latestSample.sampleTime,
                ranges: filteredRanges,
                category: nil,
                categoryId: categoryId ?? "",
                historicalValues: samples
            )

        } catch {
            print("Error loading single biomarker \(name): \(error)")
            return nil
        }
    }
}
