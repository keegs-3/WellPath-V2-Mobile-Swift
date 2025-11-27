//
//  MetricsViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

@MainActor
class MetricsViewModel: ObservableObject {
    @Published var biomarkerCards: [BiomarkerCardData] = []
    @Published var biometricCards: [BiometricCardData] = []
    @Published var categories: [String] = []
    @Published var isLoading = false
    @Published var error: String?

    private let service = BiometricsService()
    private let supabase = SupabaseManager.shared.client
    private var patientGender: String = "all"
    private var patientAge: Int = 0

    // MARK: - Range Models (from biomarkers_detail / biometrics_detail)

    struct SimplifiedRange: Codable {
        let biomarker: String
        let rangeName: String      // This IS the bucket: "OPTIMAL", "IN RANGE", "OUT OF RANGE"
        let rangeLow: Double
        let rangeHigh: Double
        let directionality: String?
        let gender: String?

        enum CodingKeys: String, CodingKey {
            case biomarker
            case rangeName = "range_name"
            case rangeLow = "range_low"
            case rangeHigh = "range_high"
            case directionality
            case gender
        }

        // Computed property to match old interface
        var rangeBucket: String { rangeName }
        var bucketMin: Double { rangeLow }
        var bucketMax: Double { rangeHigh }
    }

    struct SimplifiedBiometricRange: Codable {
        let biometric: String
        let rangeName: String      // This IS the bucket: "OPTIMAL", "IN RANGE", "OUT OF RANGE"
        let rangeLow: Double
        let rangeHigh: Double
        let directionality: String?
        let ageLow: Double?
        let ageHigh: Double?
        let gender: String?

        enum CodingKeys: String, CodingKey {
            case biometric
            case rangeName = "range_name"
            case rangeLow = "range_low"
            case rangeHigh = "range_high"
            case directionality
            case ageLow = "age_low"
            case ageHigh = "age_high"
            case gender
        }

        // Computed property to match old interface
        var rangeBucket: String { rangeName }
        var bucketMin: Double { rangeLow }
        var bucketMax: Double { rangeHigh }
    }

    func loadBiomarkers() async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch patient gender and age
            let patientDetails: [PatientDetails] = try await supabase
                .from("patients")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let patient = patientDetails.first {
                if let gender = patient.biologicalSex {
                    patientGender = gender
                }
                // Calculate age from date of birth (format: "YYYY-MM-DD")
                if let dobString = patient.dateOfBirth {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let dob = formatter.date(from: dobString) {
                        let calendar = Calendar.current
                        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
                        patientAge = ageComponents.year ?? 0
                    }
                }
            }

            // Fetch all biomarker readings for user
            let readings = try await service.fetchBiomarkerReadings(for: userId)

            // Group by biomarker name and get latest reading for each
            let grouped = Dictionary(grouping: readings, by: { $0.biomarkerName })

            // Get unique biomarker names
            let biomarkerNames = Array(grouped.keys)

            // BATCH FETCH: Get ALL ranges for patient gender in ONE query from biomarkers_detail
            var allSimplifiedRanges: [SimplifiedRange] = try await supabase
                .from("biomarkers_detail")
                .select()
                .eq("gender", value: patientGender)
                .order("range_low", ascending: true)
                .execute()
                .value

            // Also fetch "all" gender ranges as fallback (single query)
            let allGenderRanges: [SimplifiedRange] = try await supabase
                .from("biomarkers_detail")
                .select()
                .eq("gender", value: "all")
                .order("range_low", ascending: true)
                .execute()
                .value

            // Group simplified ranges by biomarker name for quick lookup
            let rangesByBiomarker = Dictionary(grouping: allSimplifiedRanges, by: { $0.biomarker })
            let fallbackRangesByBiomarker = Dictionary(grouping: allGenderRanges, by: { $0.biomarker })

            // Batch fetch all biomarker details and bases in parallel
            async let detailsTask = withThrowingTaskGroup(of: (String, [BiomarkerDetail]).self) { group -> [String: [BiomarkerDetail]] in
                for name in biomarkerNames {
                    group.addTask {
                        let details = try await self.service.fetchBiomarkerDetails(for: name)
                        return (name, details)
                    }
                }
                var detailsDict: [String: [BiomarkerDetail]] = [:]
                for try await (name, details) in group {
                    detailsDict[name] = details
                }
                return detailsDict
            }

            async let basesTask = withThrowingTaskGroup(of: (String, BiomarkerBase?).self) { group -> [String: BiomarkerBase] in
                for name in biomarkerNames {
                    group.addTask {
                        let base = try await self.service.fetchBiomarkerBase(for: name)
                        return (name, base)
                    }
                }
                var basesDict: [String: BiomarkerBase] = [:]
                for try await (name, base) in group {
                    if let base = base {
                        basesDict[name] = base
                    }
                }
                return basesDict
            }

            let (allBiomarkerDetails, allBiomarkerBases) = try await (detailsTask, basesTask)

            var cards: [BiomarkerCardData] = []

            for biomarkerName in biomarkerNames {
                guard let biomarkerReadings = grouped[biomarkerName],
                      let latestReading = biomarkerReadings.first else { continue }

                let ranges = allBiomarkerDetails[biomarkerName] ?? []
                let biomarkerBase = allBiomarkerBases[biomarkerName]

                // Determine status using patient gender
                let status = await service.determineStatus(value: latestReading.value, ranges: ranges, gender: patientGender)

                // Get detailed range name (not bucket)
                let rangeName = await service.getRangeName(value: latestReading.value, ranges: ranges, gender: patientGender)

                // Get optimal range display
                let optimalRange = service.getOptimalRangeDisplay(from: ranges, gender: patientGender)

                // Calculate trend
                let trend = service.calculateTrend(from: biomarkerReadings)

                // Get trend data (last 6 readings)
                let trendData = biomarkerReadings.prefix(6).reversed().map { $0.value }

                // Format value based on format field
                let formattedValue = formatValue(latestReading.value, format: biomarkerBase?.format)
                let valueWithUnit: String
                if let unitDisplay = biomarkerBase?.unitDisplay, !unitDisplay.isEmpty {
                    valueWithUnit = "\(formattedValue) \(unitDisplay)"
                } else if biomarkerBase?.units == nil {
                    // No units means it's a ratio
                    valueWithUnit = formattedValue
                } else {
                    valueWithUnit = "\(formattedValue) \(formatUnit(latestReading.unit))"
                }

                // Get directionality from the pre-fetched ranges (it's the same for all ranges of a biomarker)
                let simplifiedRanges = rangesByBiomarker[biomarkerName] ?? fallbackRangesByBiomarker[biomarkerName] ?? []
                let directionality = simplifiedRanges.first?.directionality ?? "optimal_range"

                // Filter to show only relevant segments using directionality
                let visibleSegments = filterVisibleSegmentsWithDirectionality(
                    allSegments: simplifiedRanges,
                    patientValue: latestReading.value,
                    patientBucket: status,
                    directionality: directionality
                )

                // Build range segments - don't skip card if no segments found
                let rangeSegments: [RangeSegment] = buildDisplaySegments(
                    visibleSegments: visibleSegments,
                    patientValue: latestReading.value,
                    status: status,
                    directionality: directionality
                )

                let card = BiomarkerCardData(
                    name: biomarkerName,
                    value: valueWithUnit,
                    numericValue: latestReading.value,
                    status: status,
                    rangeName: rangeName,
                    optimalRange: optimalRange,
                    trend: trend,
                    trendData: trendData,
                    unit: latestReading.unit,
                    category: biomarkerBase?.category,
                    rangeSegments: rangeSegments
                )

                cards.append(card)
            }

            // Sort by status (Out-of-Range first, then In-Range, then Optimal)
            biomarkerCards = cards.sorted { card1, card2 in
                let priority1 = getStatusPriority(card1.status)
                let priority2 = getStatusPriority(card2.status)
                return priority1 < priority2
            }

        } catch {
            self.error = "Failed to load biomarkers: \(error.localizedDescription)"
            print("Error loading biomarkers: \(error)")
        }

        isLoading = false
    }

    func loadBiometrics() async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch patient gender and date of birth
            let patientDetails: [PatientDetails] = try await supabase
                .from("patients")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            var patientAge: Int? = nil
            if let patient = patientDetails.first {
                if let gender = patient.biologicalSex {
                    patientGender = gender
                }
                // Calculate age from date of birth
                if let dobString = patient.dateOfBirth {
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withFullDate]
                    if let dob = dateFormatter.date(from: dobString) {
                        let calendar = Calendar.current
                        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
                        patientAge = ageComponents.year
                    }
                }
            }

            // Fetch all biometric readings for user
            let readings = try await service.fetchBiometricReadings(for: userId)

            // Group by biometric name and get latest reading for each
            let grouped = Dictionary(grouping: readings, by: { $0.biometricName })

            // Get unique biometric names
            let biometricNames = Array(grouped.keys)

            // Batch fetch all biometric details at once
            let allBiometricDetails: [[BiometricDetail]] = try await withThrowingTaskGroup(of: (String, [BiometricDetail]).self) { group in
                for name in biometricNames {
                    group.addTask {
                        let details = try await self.service.fetchBiometricDetails(for: name)
                        return (name, details)
                    }
                }

                var detailsDict: [String: [BiometricDetail]] = [:]
                for try await (name, details) in group {
                    detailsDict[name] = details
                }
                return biometricNames.map { detailsDict[$0] ?? [] }
            }

            // Batch fetch all biometrics base records at once
            let allBiometricsBases: [String: BiometricsBase] = try await withThrowingTaskGroup(of: (String, BiometricsBase?).self) { group in
                for name in biometricNames {
                    group.addTask {
                        let base = try await self.service.fetchBiometricsBase(for: name)
                        return (name, base)
                    }
                }

                var basesDict: [String: BiometricsBase] = [:]
                for try await (name, base) in group {
                    if let base = base {
                        basesDict[name] = base
                    }
                }
                return basesDict
            }

            var cards: [BiometricCardData] = []

            for (index, biometricName) in biometricNames.enumerated() {
                guard let biometricReadings = grouped[biometricName],
                      let latestReading = biometricReadings.first else { continue }

                let ranges = allBiometricDetails[index]
                let biometricsBase = allBiometricsBases[biometricName]

                // Determine status using patient gender
                let status = await service.determineBiometricStatus(value: latestReading.value, ranges: ranges, gender: patientGender)

                // Get detailed range name (not bucket)
                let rangeName = await service.getBiometricRangeName(value: latestReading.value, ranges: ranges, gender: patientGender)

                // Get optimal range display (with age filtering)
                let optimalRange = service.getOptimalRangeDisplayBiometric(from: ranges, gender: patientGender, age: patientAge)

                let trendData = biometricReadings.prefix(6).reversed().map { $0.value }

                // Format value based on format field
                let formattedValue = formatValue(latestReading.value, format: biometricsBase?.format)

                // Use unit_display from biometrics_base if available
                let valueWithUnit: String
                if let unitDisplay = biometricsBase?.unitDisplay, !unitDisplay.isEmpty {
                    valueWithUnit = "\(formattedValue) \(unitDisplay)"
                } else if biometricsBase?.unit == nil {
                    // No units means it's a ratio
                    valueWithUnit = formattedValue
                } else {
                    valueWithUnit = "\(formattedValue) \(formatUnit(latestReading.unit))"
                }

                // Fetch directionality for this biometric
                let directionality = await fetchDirectionality(for: biometricName, isBiometric: true) ?? "optimal_range"

                // Fetch range segments from biometrics_detail
                // Try patient gender first, fall back to "all" if no results
                var simplifiedRanges: [SimplifiedBiometricRange] = try await supabase
                    .from("biometrics_detail")
                    .select()
                    .eq("biometric", value: biometricName)
                    .eq("gender", value: patientGender)
                    .order("range_low", ascending: true)
                    .execute()
                    .value

                // Fall back to "all" gender if no gender-specific ranges found
                if simplifiedRanges.isEmpty {
                    simplifiedRanges = try await supabase
                        .from("biometrics_detail")
                        .select()
                        .eq("biometric", value: biometricName)
                        .eq("gender", value: "all")
                        .order("range_low", ascending: true)
                        .execute()
                        .value
                }

                // Filter by age if patient age is known
                if let age = patientAge {
                    let ageDouble = Double(age)
                    // First try to find ranges that match the patient's age
                    let ageFilteredRanges = simplifiedRanges.filter { range in
                        // Include if no age restriction (null age_low and age_high)
                        if range.ageLow == nil && range.ageHigh == nil {
                            return true
                        }
                        // Include if age is within the specified range
                        let meetsLowBound = range.ageLow == nil || ageDouble >= range.ageLow!
                        let meetsHighBound = range.ageHigh == nil || ageDouble <= range.ageHigh!
                        return meetsLowBound && meetsHighBound
                    }
                    // Only use age-filtered ranges if we found some
                    if !ageFilteredRanges.isEmpty {
                        simplifiedRanges = ageFilteredRanges
                    }
                }

                // Filter to show only relevant segments using directionality
                let visibleSegments = filterVisibleBiometricSegmentsWithDirectionality(
                    allSegments: simplifiedRanges,
                    patientValue: latestReading.value,
                    patientBucket: status,
                    directionality: directionality
                )

                let patientValue = latestReading.value

                // Build range segments - don't skip card if no segments found
                let rangeSegments: [RangeSegment] = buildBiometricDisplaySegments(
                    visibleSegments: visibleSegments,
                    patientValue: patientValue,
                    status: status,
                    directionality: directionality
                )

                let card = BiometricCardData(
                    name: biometricName,
                    value: valueWithUnit,
                    numericValue: latestReading.value,
                    status: status,
                    rangeName: rangeName,
                    optimalRange: optimalRange,
                    trend: service.calculateTrend(from: biometricReadings.map { reading in
                        BiomarkerReading(
                            id: reading.id,
                            patientId: reading.patientId,
                            biomarkerName: reading.biometricName,
                            value: reading.value,
                            unit: reading.unit,
                            testDate: reading.recordedAt,
                            source: reading.source,
                            notes: reading.notes,
                            cyclePhase: nil,
                            createdAt: reading.createdAt,
                            updatedAt: reading.updatedAt
                        )
                    }),
                    trendData: trendData,
                    unit: latestReading.unit,
                    category: biometricsBase?.category,
                    rangeSegments: rangeSegments
                )

                cards.append(card)
            }

            // Sort by status (Out-of-Range first, then In-Range, then Optimal)
            biometricCards = cards.sorted { card1, card2 in
                let priority1 = getStatusPriority(card1.status)
                let priority2 = getStatusPriority(card2.status)
                return priority1 < priority2
            }

        } catch {
            self.error = "Failed to load biometrics: \(error.localizedDescription)"
            print("Error loading biometrics: \(error)")
        }

        isLoading = false
    }

    func loadCategories() async {
        do {
            let categoryRecords = try await service.fetchCategories()
            // Get unique category names
            categories = Array(Set(categoryRecords.map { $0.categoryName })).sorted()
        } catch {
            print("Error loading categories: \(error)")
        }
    }

    // MARK: - Helper Functions

    private func getStatusPriority(_ status: String) -> Int {
        switch status {
        case "Out-of-Range": return 0
        case "In-Range": return 1
        case "Optimal": return 2
        default: return 3
        }
    }

    private func formatValue(_ value: Double, format: String?) -> String {
        guard let format = format?.lowercased() else {
            return String(format: "%.1f", value)
        }

        if format.contains("integer") || format == "integer" {
            return String(format: "%.0f", value)
        } else if format.contains("1 decimal") || format == "1 decimal" {
            return String(format: "%.1f", value)
        } else if format.contains("2 decimal") || format == "2 decimal" {
            return String(format: "%.2f", value)
        } else if format.contains("3 decimal") || format == "3 decimal" {
            return String(format: "%.3f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatUnit(_ unit: String) -> String {
        // Convert backend unit format to display format
        let unitMap: [String: String] = [
            "milligrams_per_deciliter": "mg/dL",
            "nanograms_per_milliliter": "ng/mL",
            "picograms_per_milliliter": "pg/mL",
            "milli_international_units_per_liter": "mIU/L",
            "billion_per_liter": "B/L",
            "percent": "%",
            "micrograms_per_deciliter": "μg/dL",
            "nanograms_per_deciliter": "ng/dL",
            "micromoles_per_liter": "μmol/L",
            "milliliters_per_kilogram_per_minute": "mL/kg/min",
            "liter": "L",
            "steps": "steps",
            "minutes": "min",
            "kilograms_per_square_meter": "kg/m²",
            "grams_per_deciliter": "g/dL",
            "international_units_per_liter": "IU/L",
            "millimoles_per_liter": "mmol/L",
            "beats_per_minute": "bpm",
            "millimeters_of_mercury": "mmHg",
            "celsius": "°C",
            "fahrenheit": "°F",
            "grams": "g",
            "kilograms": "kg",
            "pounds": "lbs",
            "centimeters": "cm",
            "meters": "m",
            "inches": "in"
        ]

        return unitMap[unit] ?? unit
    }

    // MARK: - Helper Functions

    private func fetchDirectionality(for biomarkerName: String, isBiometric: Bool) async -> String? {
        do {
            if isBiometric {
                struct DirectionalityResult: Codable {
                    let directionality: String?
                }

                let result: [DirectionalityResult] = try await supabase
                    .from("biometrics_detail")
                    .select("directionality")
                    .eq("biometric", value: biomarkerName)
                    .limit(1)
                    .execute()
                    .value

                return result.first?.directionality
            } else {
                struct DirectionalityResult: Codable {
                    let directionality: String?
                }

                let result: [DirectionalityResult] = try await supabase
                    .from("biomarkers_detail")
                    .select("directionality")
                    .eq("biomarker", value: biomarkerName)
                    .limit(1)
                    .execute()
                    .value

                return result.first?.directionality
            }
        } catch {
            print("❌ Error fetching directionality for \(biomarkerName): \(error)")
            return nil
        }
    }

    // MARK: - Segment Filtering

    private func filterVisibleSegments<T>(
        allSegments: [T],
        patientValue: Double,
        patientBucket: String
    ) -> [T] where T: Any {
        // Cast to access properties
        guard let segments = allSegments as? [SimplifiedRange] else {
            return allSegments
        }

        // Find the segment containing the patient value
        guard let patientIndex = segments.firstIndex(where: { segment in
            patientValue >= segment.bucketMin && patientValue <= segment.bucketMax
        }) else {
            // If patient value not found in any segment, return all segments
            return allSegments
        }

        // Determine which 3 segments to show based on position
        let segmentIndices: [Int]
        if patientIndex == 0 {
            // Lowest bucket: show this + 2 above
            let maxIndex = min(segments.count - 1, 2)
            segmentIndices = Array(0...maxIndex)
        } else if patientIndex == segments.count - 1 {
            // Highest bucket: show 2 below + this
            let minIndex = max(0, segments.count - 3)
            segmentIndices = Array(minIndex...patientIndex)
        } else {
            // Middle bucket: show 1 below + this + 1 above
            let minIndex = max(0, patientIndex - 1)
            let maxIndex = min(segments.count - 1, patientIndex + 1)
            segmentIndices = Array(minIndex...maxIndex)
        }

        // Return only visible segments
        return segmentIndices.compactMap { index in
            allSegments[index]
        }
    }

    private func filterVisibleSegmentsWithDirectionality<T>(
        allSegments: [T],
        patientValue: Double,
        patientBucket: String,
        directionality: String
    ) -> [T] where T: Any {
        // Cast to access properties
        guard let segments = allSegments as? [SimplifiedRange] else {
            return allSegments
        }

        // Find the segment containing the patient value
        guard let patientIndex = segments.firstIndex(where: { segment in
            patientValue >= segment.bucketMin && patientValue <= segment.bucketMax
        }) else {
            // If patient value not found in any segment, return all segments
            return allSegments
        }

        // Determine which segments to show based on directionality
        let segmentIndices: [Int]

        if patientBucket == "Optimal" {
            // For optimal values, show 2 bands in the concerning direction
            switch directionality {
            case "higher_better":
                // Show patient segment + 2 bands to the left (lower values = concerning)
                let minIndex = max(0, patientIndex - 2)
                segmentIndices = Array(minIndex...patientIndex)
            case "lower_better", "lower_expected":
                // Show patient segment + 2 bands to the right (higher values = concerning)
                let maxIndex = min(segments.count - 1, patientIndex + 2)
                segmentIndices = Array(patientIndex...maxIndex)
            default: // optimal_range
                // Show 1 band on either side
                let minIndex = max(0, patientIndex - 1)
                let maxIndex = min(segments.count - 1, patientIndex + 1)
                segmentIndices = Array(minIndex...maxIndex)
            }
        } else {
            // For non-optimal values, show path to optimal + adjacent context
            // Always show at least 3 segments centered around patient
            let minIndex = max(0, patientIndex - 1)
            let maxIndex = min(segments.count - 1, patientIndex + 1)
            segmentIndices = Array(minIndex...maxIndex)
        }

        // Return only visible segments
        return segmentIndices.compactMap { index in
            allSegments[index]
        }
    }

    private func filterVisibleBiometricSegments<T>(
        allSegments: [T],
        patientValue: Double,
        patientBucket: String
    ) -> [T] where T: Any {
        // Cast to access properties
        guard let segments = allSegments as? [SimplifiedBiometricRange] else {
            return allSegments
        }

        // Find the segment containing the patient value
        guard let patientIndex = segments.firstIndex(where: { segment in
            patientValue >= segment.bucketMin && patientValue <= segment.bucketMax
        }) else {
            // If patient value not found in any segment, return all segments
            return allSegments
        }

        // Determine which 3 segments to show based on position
        let segmentIndices: [Int]
        if patientIndex == 0 {
            // Lowest bucket: show this + 2 above
            let maxIndex = min(segments.count - 1, 2)
            segmentIndices = Array(0...maxIndex)
        } else if patientIndex == segments.count - 1 {
            // Highest bucket: show 2 below + this
            let minIndex = max(0, segments.count - 3)
            segmentIndices = Array(minIndex...patientIndex)
        } else {
            // Middle bucket: show 1 below + this + 1 above
            let minIndex = max(0, patientIndex - 1)
            let maxIndex = min(segments.count - 1, patientIndex + 1)
            segmentIndices = Array(minIndex...maxIndex)
        }

        // Return only visible segments
        return segmentIndices.compactMap { index in
            allSegments[index]
        }
    }

    private func filterVisibleBiometricSegmentsWithDirectionality<T>(
        allSegments: [T],
        patientValue: Double,
        patientBucket: String,
        directionality: String
    ) -> [T] where T: Any {
        // Cast to access properties
        guard let segments = allSegments as? [SimplifiedBiometricRange] else {
            return allSegments
        }

        // Find the segment containing the patient value
        guard let patientIndex = segments.firstIndex(where: { segment in
            patientValue >= segment.bucketMin && patientValue <= segment.bucketMax
        }) else {
            // If patient value not found in any segment, return all segments
            return allSegments
        }

        // Determine which segments to show based on directionality
        let segmentIndices: [Int]

        if patientBucket == "Optimal" {
            // For optimal values, show 2 bands in the concerning direction
            switch directionality {
            case "higher_better":
                // Show patient segment + 2 bands to the left (lower values = concerning)
                let minIndex = max(0, patientIndex - 2)
                segmentIndices = Array(minIndex...patientIndex)
            case "lower_better", "lower_expected":
                // Show patient segment + 2 bands to the right (higher values = concerning)
                let maxIndex = min(segments.count - 1, patientIndex + 2)
                segmentIndices = Array(patientIndex...maxIndex)
            default: // optimal_range
                // Show 1 band on either side
                let minIndex = max(0, patientIndex - 1)
                let maxIndex = min(segments.count - 1, patientIndex + 1)
                segmentIndices = Array(minIndex...maxIndex)
            }
        } else {
            // For non-optimal values, show path to optimal + adjacent context
            // Always show at least 3 segments centered around patient
            let minIndex = max(0, patientIndex - 1)
            let maxIndex = min(segments.count - 1, patientIndex + 1)
            segmentIndices = Array(minIndex...maxIndex)
        }

        // Return only visible segments
        return segmentIndices.compactMap { index in
            allSegments[index]
        }
    }

    // MARK: - Build Display Segments

    /// Builds display segments for biomarkers - returns empty array if no valid segments found (never skips card)
    /// Simplified: just pass through visible segments with realistic bounds applied to artificial extremes
    private func buildDisplaySegments(
        visibleSegments: [SimplifiedRange],
        patientValue: Double,
        status: String,
        directionality: String
    ) -> [RangeSegment] {
        // If no segments, return empty array (card will still be created)
        guard !visibleSegments.isEmpty else {
            return []
        }

        // Find patient's segment
        let patientSegment = visibleSegments.first(where: { seg in
            patientValue >= seg.bucketMin && patientValue <= seg.bucketMax
        })

        // Build segments - first/last are treated as artificial bounds
        return visibleSegments.enumerated().map { (index, seg) in
            let isFirst = index == 0
            let isLast = index == visibleSegments.count - 1

            let isPatientSeg = patientSegment.map { ps in
                seg.bucketMin == ps.bucketMin && seg.bucketMax == ps.bucketMax
            } ?? false

            return RangeSegment(
                rangeName: seg.rangeBucket,
                rangeBucket: seg.rangeBucket,
                rangeLow: seg.bucketMin,
                rangeHigh: seg.bucketMax,
                isArtificialLow: isFirst,
                isArtificialHigh: isLast,
                isPatientSegment: isPatientSeg
            )
        }
    }

    /// Builds display segments for biometrics - returns empty array if no valid segments found (never skips card)
    private func buildBiometricDisplaySegments(
        visibleSegments: [SimplifiedBiometricRange],
        patientValue: Double,
        status: String,
        directionality: String
    ) -> [RangeSegment] {
        guard !visibleSegments.isEmpty else {
            return []
        }

        // Find patient's segment
        let patientSegment = visibleSegments.first(where: { seg in
            patientValue >= seg.bucketMin && patientValue <= seg.bucketMax
        })

        // Build segments - first/last are treated as artificial bounds
        return visibleSegments.enumerated().map { (index, seg) in
            let isFirst = index == 0
            let isLast = index == visibleSegments.count - 1

            let isPatientSeg = patientSegment.map { ps in
                seg.bucketMin == ps.bucketMin && seg.bucketMax == ps.bucketMax
            } ?? false

            return RangeSegment(
                rangeName: seg.rangeBucket,
                rangeBucket: seg.rangeBucket,
                rangeLow: seg.bucketMin,
                rangeHigh: seg.bucketMax,
                isArtificialLow: isFirst,
                isArtificialHigh: isLast,
                isPatientSegment: isPatientSeg
            )
        }
    }
}
