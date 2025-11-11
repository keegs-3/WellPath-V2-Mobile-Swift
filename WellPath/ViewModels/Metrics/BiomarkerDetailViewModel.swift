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

    private let service = BiometricsService()
    private let supabase = SupabaseManager.shared.client

    func loadHistory(for name: String, isBiometric: Bool = false) async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            if isBiometric {
                print("🔍 Loading biometric history for: '\(name)'")
                print("🔍 User ID: \(userId.uuidString)")

                // Fetch biometric historical readings
                let readings: [BiometricReading] = try await supabase
                    .from("patient_biometric_readings")
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
}
