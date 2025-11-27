//
//  BiomarkerDetailViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

@MainActor
class BiomarkerDetailViewModel: ObservableObject {
    @Published var historicalData: [BiomarkerDataPoint] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var aboutSections: [BiomarkerEducationSection] = []

    private let service = BiometricsService()
    private let supabase = SupabaseManager.shared.client
    private var isLoadingMore = false

    func loadHistory(for name: String, isBiometric: Bool = false) async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            if isBiometric {
                print("🔍 Loading biometric history for: '\(name)'")
                print("🔍 User ID: \(userId.uuidString)")

                // Fetch biometric historical readings (use view that casts numeric to double for Swift compatibility)
                let readings: [BiometricReading] = try await supabase
                    .from("patient_biometric_readings_v")
                    .select()
                    .eq("patient_id", value: userId.uuidString)
                    .eq("biometric_name", value: name)
                    .order("recorded_at", ascending: false)
                    .execute()
                    .value

                print("🔍 Found \(readings.count) biometric readings")
                for (index, reading) in readings.enumerated() {
                    print("🔍 Reading \(index + 1): value=\(reading.value), date=\(reading.recordedAt)")
                }

                // Convert to chart data points
                // Try ISO8601 with fractional seconds first
                let iso8601WithFractional = ISO8601DateFormatter()
                iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                // Then try ISO8601 without fractional seconds
                let iso8601Standard = ISO8601DateFormatter()

                let standardFormatter = DateFormatter()
                standardFormatter.dateFormat = "yyyy-MM-dd"

                let timestampFormatter = DateFormatter()
                timestampFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

                historicalData = readings.compactMap { reading in
                    var date: Date?
                    print("🔍 Trying to parse: '\(reading.recordedAt)'")

                    // Try with fractional seconds first
                    date = iso8601WithFractional.date(from: reading.recordedAt)
                    if date == nil {
                        print("  ❌ ISO8601 with fractional seconds failed")
                        // Try without fractional seconds
                        date = iso8601Standard.date(from: reading.recordedAt)
                    }
                    if date == nil {
                        print("  ❌ ISO8601 standard failed")
                        date = standardFormatter.date(from: reading.recordedAt)
                    }
                    if date == nil {
                        print("  ❌ Standard format failed")
                        date = timestampFormatter.date(from: reading.recordedAt)
                    }
                    if date == nil {
                        print("  ❌ Timestamp format failed")
                    }
                    guard let finalDate = date else {
                        print("❌ FAILED TO PARSE DATE: '\(reading.recordedAt)' - THIS READING WILL BE DROPPED!")
                        return nil
                    }
                    print("✅ Parsed date successfully: \(finalDate) from '\(reading.recordedAt)'")
                    return BiomarkerDataPoint(date: finalDate, value: reading.value)
                }.sorted { $0.date > $1.date }

                print("🔍 Final historicalData count: \(historicalData.count)")
                print("🔍 Started with \(readings.count) readings, ended with \(historicalData.count) data points")
            } else {
                // Fetch biomarker historical readings
                let readings = try await service.fetchBiomarkerHistory(
                    biomarkerName: name,
                    userId: userId
                )

                // Convert to chart data points
                // Try ISO8601 with fractional seconds first
                let iso8601WithFractional = ISO8601DateFormatter()
                iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                // Then try ISO8601 without fractional seconds
                let iso8601Standard = ISO8601DateFormatter()

                let standardFormatter = DateFormatter()
                standardFormatter.dateFormat = "yyyy-MM-dd"

                let timestampFormatter = DateFormatter()
                timestampFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

                historicalData = readings.compactMap { reading in
                    var date: Date?
                    print("🔍 Trying to parse: '\(reading.testDate)'")

                    // Try with fractional seconds first
                    date = iso8601WithFractional.date(from: reading.testDate)
                    if date == nil {
                        print("  ❌ ISO8601 with fractional seconds failed")
                        // Try without fractional seconds
                        date = iso8601Standard.date(from: reading.testDate)
                    }
                    if date == nil {
                        print("  ❌ ISO8601 standard failed")
                        date = standardFormatter.date(from: reading.testDate)
                    }
                    if date == nil {
                        print("  ❌ Standard format failed")
                        date = timestampFormatter.date(from: reading.testDate)
                    }
                    if date == nil {
                        print("  ❌ Timestamp format failed")
                    }
                    guard let finalDate = date else {
                        print("❌ FAILED TO PARSE DATE: '\(reading.testDate)' - THIS READING WILL BE DROPPED!")
                        return nil
                    }
                    print("✅ Parsed date successfully: \(finalDate) from '\(reading.testDate)'")
                    return BiomarkerDataPoint(date: finalDate, value: reading.value)
                }.sorted { $0.date > $1.date }
            }

        } catch {
            self.error = "Failed to load history: \(error.localizedDescription)"
            print("Error loading history: \(error)")
        }

        isLoading = false
    }

    func loadMoreIfNeeded(for name: String, isBiometric: Bool, scrollPosition: Date, period: BiomarkerTimePeriod) async {
        // Prevent concurrent loading
        guard !isLoadingMore else { return }

        // Check if we're approaching the edges
        guard let oldestDate = historicalData.last?.date,
              let newestDate = historicalData.first?.date else { return }

        let visibleDuration = getVisibleDuration(for: period)
        let visibleStart = scrollPosition
        let visibleEnd = scrollPosition.addingTimeInterval(visibleDuration)

        // Load more if within 20% of edge
        let threshold = visibleDuration * 0.2

        let needsOlderData = abs(visibleStart.timeIntervalSince(oldestDate)) < threshold
        let needsNewerData = abs(visibleEnd.timeIntervalSince(newestDate)) < threshold

        guard needsOlderData || needsNewerData else { return }

        isLoadingMore = true

        do {
            let userId = try await supabase.auth.session.user.id

            if isBiometric {
                // Format dates for Supabase query (ISO8601)
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                var newData: [BiomarkerDataPoint] = []

                if needsOlderData {
                    // Fetch older data (before oldestDate)
                    let oldestDateString = dateFormatter.string(from: oldestDate)
                    let readings: [BiometricReading] = try await supabase
                        .from("patient_biometric_readings_v")
                        .select()
                        .eq("patient_id", value: userId.uuidString)
                        .eq("biometric_name", value: name)
                        .lt("recorded_at", value: oldestDateString)
                        .order("recorded_at", ascending: false)
                        .limit(50)
                        .execute()
                        .value

                    let iso8601WithFractional = ISO8601DateFormatter()
                    iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let iso8601Standard = ISO8601DateFormatter()

                    let olderPoints = readings.compactMap { reading -> BiomarkerDataPoint? in
                        var date: Date?
                        date = iso8601WithFractional.date(from: reading.recordedAt)
                        if date == nil {
                            date = iso8601Standard.date(from: reading.recordedAt)
                        }
                        guard let finalDate = date else { return nil }
                        return BiomarkerDataPoint(date: finalDate, value: reading.value)
                    }
                    newData.append(contentsOf: olderPoints)
                }

                if needsNewerData {
                    // Fetch newer data (after newestDate)
                    let newestDateString = dateFormatter.string(from: newestDate)
                    let readings: [BiometricReading] = try await supabase
                        .from("patient_biometric_readings_v")
                        .select()
                        .eq("patient_id", value: userId.uuidString)
                        .eq("biometric_name", value: name)
                        .gt("recorded_at", value: newestDateString)
                        .order("recorded_at", ascending: false)
                        .limit(50)
                        .execute()
                        .value

                    let iso8601WithFractional = ISO8601DateFormatter()
                    iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let iso8601Standard = ISO8601DateFormatter()

                    let newerPoints = readings.compactMap { reading -> BiomarkerDataPoint? in
                        var date: Date?
                        date = iso8601WithFractional.date(from: reading.recordedAt)
                        if date == nil {
                            date = iso8601Standard.date(from: reading.recordedAt)
                        }
                        guard let finalDate = date else { return nil }
                        return BiomarkerDataPoint(date: finalDate, value: reading.value)
                    }
                    newData.append(contentsOf: newerPoints)
                }

                // Merge only NEW data with existing data
                if !newData.isEmpty {
                    let combined = (historicalData + newData)
                    let uniqueData = Dictionary(grouping: combined, by: { $0.date })
                        .compactMap { $0.value.first }
                        .sorted { $0.date > $1.date }
                    historicalData = uniqueData
                }
            } else {
                // Format dates for Supabase query (ISO8601)
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                var newData: [BiomarkerDataPoint] = []

                if needsOlderData {
                    // Fetch older data (before oldestDate)
                    let oldestDateString = dateFormatter.string(from: oldestDate)
                    let readings: [BiomarkerReading] = try await supabase
                        .from("patient_biomarker_readings_v")
                        .select()
                        .eq("patient_id", value: userId.uuidString)
                        .eq("biomarker_name", value: name)
                        .lt("test_date", value: oldestDateString)
                        .order("test_date", ascending: false)
                        .limit(50)
                        .execute()
                        .value

                    let iso8601WithFractional = ISO8601DateFormatter()
                    iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let iso8601Standard = ISO8601DateFormatter()

                    let olderPoints = readings.compactMap { reading -> BiomarkerDataPoint? in
                        var date: Date?
                        date = iso8601WithFractional.date(from: reading.testDate)
                        if date == nil {
                            date = iso8601Standard.date(from: reading.testDate)
                        }
                        guard let finalDate = date else { return nil }
                        return BiomarkerDataPoint(date: finalDate, value: reading.value)
                    }
                    newData.append(contentsOf: olderPoints)
                }

                if needsNewerData {
                    // Fetch newer data (after newestDate)
                    let newestDateString = dateFormatter.string(from: newestDate)
                    let readings: [BiomarkerReading] = try await supabase
                        .from("patient_biomarker_readings_v")
                        .select()
                        .eq("patient_id", value: userId.uuidString)
                        .eq("biomarker_name", value: name)
                        .gt("test_date", value: newestDateString)
                        .order("test_date", ascending: false)
                        .limit(50)
                        .execute()
                        .value

                    let iso8601WithFractional = ISO8601DateFormatter()
                    iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let iso8601Standard = ISO8601DateFormatter()

                    let newerPoints = readings.compactMap { reading -> BiomarkerDataPoint? in
                        var date: Date?
                        date = iso8601WithFractional.date(from: reading.testDate)
                        if date == nil {
                            date = iso8601Standard.date(from: reading.testDate)
                        }
                        guard let finalDate = date else { return nil }
                        return BiomarkerDataPoint(date: finalDate, value: reading.value)
                    }
                    newData.append(contentsOf: newerPoints)
                }

                // Merge only NEW data with existing data
                if !newData.isEmpty {
                    let combined = (historicalData + newData)
                    let uniqueData = Dictionary(grouping: combined, by: { $0.date })
                        .compactMap { $0.value.first }
                        .sorted { $0.date > $1.date }
                    historicalData = uniqueData
                }
            }
        } catch {
            print("❌ Error loading more data: \(error)")
        }

        isLoadingMore = false
    }

    func loadAboutContent(for name: String, isBiometric: Bool) async {
        do {
            if isBiometric {
                // Load education sections from biometrics_education_sections table
                let sections: [BiometricEducationSection] = try await supabase
                    .from("biometrics_education_sections")
                    .select()
                    .eq("biometric_name", value: name)
                    .eq("is_active", value: true)
                    .order("display_order", ascending: true)
                    .execute()
                    .value

                if !sections.isEmpty {
                    aboutSections = sections.map { section in
                        // Convert BiometricEducationSection to BiomarkerEducationSection
                        // (they have the same structure, just different table names)
                        BiomarkerEducationSection(
                            id: section.id,
                            biomarkerName: section.biometricName,
                            sectionTitle: section.sectionTitle,
                            sectionContent: section.sectionContent,
                            displayOrder: section.displayOrder,
                            isActive: section.isActive,
                            createdAt: section.createdAt,
                            updatedAt: section.updatedAt
                        )
                    }
                    print("📚 Loaded \(aboutSections.count) biometric education sections for '\(name)'")
                } else {
                    print("⚠️ No education sections found for biometric '\(name)'")
                }
            } else {
                // Load education sections from biomarkers_education_sections table
                let sections: [BiomarkerEducationSection] = try await supabase
                    .from("biomarkers_education_sections")
                    .select()
                    .eq("biomarker_name", value: name)
                    .eq("is_active", value: true)
                    .order("display_order", ascending: true)
                    .execute()
                    .value

                if !sections.isEmpty {
                    aboutSections = sections
                    print("📚 Loaded \(aboutSections.count) biomarker education sections for '\(name)'")
                } else {
                    print("⚠️ No education sections found for biomarker '\(name)'")
                }
            }
        } catch {
            print("❌ Error loading about content: \(error)")
        }
    }


    private func getVisibleDuration(for period: BiomarkerTimePeriod) -> TimeInterval {
        switch period {
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        case .fiveYear: return 5 * 365 * 24 * 3600
        }
    }
}
