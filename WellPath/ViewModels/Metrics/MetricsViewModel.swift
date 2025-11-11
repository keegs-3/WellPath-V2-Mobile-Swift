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

    func loadBiomarkers() async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch patient gender
            let patientDetails: [PatientDetails] = try await supabase
                .from("patients")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let patient = patientDetails.first, let gender = patient.biologicalSex {
                patientGender = gender
            }

            // Fetch all biomarker readings for user
            let readings = try await service.fetchBiomarkerReadings(for: userId)

            // Group by biomarker name and get latest reading for each
            let grouped = Dictionary(grouping: readings, by: { $0.biomarkerName })

            // Get unique biomarker names
            let biomarkerNames = Array(grouped.keys)

            // Batch fetch all biomarker details at once
            let allBiomarkerDetails: [[BiomarkerDetail]] = try await withThrowingTaskGroup(of: (String, [BiomarkerDetail]).self) { group in
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
                return biomarkerNames.map { detailsDict[$0] ?? [] }
            }

            // Batch fetch all biomarker base records at once
            let allBiomarkerBases: [String: BiomarkerBase] = try await withThrowingTaskGroup(of: (String, BiomarkerBase?).self) { group in
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

            var cards: [BiomarkerCardData] = []

            for (index, biomarkerName) in biomarkerNames.enumerated() {
                guard let biomarkerReadings = grouped[biomarkerName],
                      let latestReading = biomarkerReadings.first else { continue }

                let ranges = allBiomarkerDetails[index]
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

                let card = BiomarkerCardData(
                    name: biomarkerName,
                    value: valueWithUnit,
                    status: status,
                    rangeName: rangeName,
                    optimalRange: optimalRange,
                    trend: trend,
                    trendData: trendData,
                    unit: latestReading.unit,
                    category: biomarkerBase?.category
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

                let card = BiometricCardData(
                    name: biometricName,
                    value: valueWithUnit,
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
                            createdAt: reading.createdAt,
                            updatedAt: reading.updatedAt
                        )
                    }),
                    trendData: trendData,
                    unit: latestReading.unit,
                    category: biometricsBase?.category
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
}
