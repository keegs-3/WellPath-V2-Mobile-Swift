//
//  SubstanceTrackingViewModels.swift
//  WellPath
//
//  ViewModels for individual substance tracking views.
//  Each ViewModel handles loading/saving data via patient_quantity_samples.
//

import Foundation
import Supabase

// MARK: - Alcohol Tracking ViewModel

@MainActor
class AlcoholTrackingViewModel: ObservableObject {
    @Published var weeklyHistory: [SubstanceDataPoint] = []
    @Published var currentWeekDrinks: Int = 0
    @Published var isLoading = false
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client

    func loadHistory() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [SubstanceQuantitySampleResponse] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: QuantityTypes.alcoholDrinks)
                .order("start_time", ascending: true)
                .execute()
                .value

            weeklyHistory = response.compactMap { sample in
                guard let value = sample.quantityValue else { return nil }
                return SubstanceDataPoint(date: sample.startTime, value: Int(value))
            }

            // Get current week total
            if let latest = weeklyHistory.last {
                let calendar = Calendar.current
                if calendar.isDate(latest.date, equalTo: Date(), toGranularity: .weekOfYear) {
                    currentWeekDrinks = latest.value
                }
            }
        } catch {
            self.error = error
            print("Error loading alcohol history: \(error)")
        }
    }

    func logDrinks(_ count: Int, date: Date = Date()) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let timezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.alcoholDrinks,
                value: Double(count),
                unit: "drink",
                timestamp: date,
                source: .wellpathInput,
                timezone: timezone,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            // Reload data
            await loadHistory()
        } catch {
            self.error = error
            print("Error logging drinks: \(error)")
        }
    }
}

// MARK: - Tobacco Tracking ViewModel

@MainActor
class TobaccoTrackingViewModel: ObservableObject {
    @Published var smokeFreeHistory: [SubstanceDataPoint] = []
    @Published var cigaretteHistory: [SubstanceDataPoint] = []
    @Published var currentStreak: Int = 0
    @Published var quitDate: Date?
    @Published var isLoading = false
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client

    func loadHistory() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load smoke-free data
            let smokeFreeResponse: [SubstanceQuantitySampleResponse] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "tobacco_days_smoke_free")
                .order("start_time", ascending: true)
                .execute()
                .value

            smokeFreeHistory = smokeFreeResponse.compactMap { sample in
                guard let value = sample.quantityValue else { return nil }
                return SubstanceDataPoint(date: sample.startTime, value: Int(value))
            }

            // Calculate current streak
            if let latest = smokeFreeHistory.last {
                let calendar = Calendar.current
                let daysSince = calendar.dateComponents([.day], from: latest.date, to: Date()).day ?? 0
                currentStreak = Int(latest.value) + daysSince
                quitDate = calendar.date(byAdding: .day, value: -currentStreak, to: Date())
            }

            // Load cigarette data
            let cigaretteResponse: [SubstanceQuantitySampleResponse] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: QuantityTypes.tobaccoUses)
                .order("start_time", ascending: true)
                .execute()
                .value

            cigaretteHistory = cigaretteResponse.compactMap { sample in
                guard let value = sample.quantityValue else { return nil }
                return SubstanceDataPoint(date: sample.startTime, value: Int(value))
            }
        } catch {
            self.error = error
            print("Error loading tobacco history: \(error)")
        }
    }

    func setQuitDate(_ date: Date) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let calendar = Calendar.current
            let daysSince = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            let timezone = TimeZone.current.identifier

            var metadata: [String: AnyJSON] = [:]
            metadata["quit_date"] = .integer(Int(date.timeIntervalSince1970))

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: "tobacco_days_smoke_free",
                value: Double(daysSince),
                unit: "day",
                timestamp: Date(),
                source: .wellpathInput,
                timezone: timezone,
                metadata: metadata,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            await loadHistory()
        } catch {
            self.error = error
            print("Error setting quit date: \(error)")
        }
    }

    func logCigarettes(_ count: Int, date: Date = Date()) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let timezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.tobaccoUses,
                value: Double(count),
                unit: "count",
                timestamp: date,
                source: .wellpathInput,
                timezone: timezone,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            await loadHistory()
        } catch {
            self.error = error
            print("Error logging cigarettes: \(error)")
        }
    }

    func resetQuitDate() async {
        // Reset smoke-free streak (user relapsed)
        quitDate = nil
        currentStreak = 0
    }
}

// MARK: - Nicotine Tracking ViewModel

@MainActor
class NicotineTrackingViewModel: ObservableObject {
    @Published var usageHistory: [SubstanceDataPoint] = []
    @Published var todayUsage: Int = 0
    @Published var isLoading = false
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client

    func loadHistory() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [SubstanceQuantitySampleResponse] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: QuantityTypes.nicotineUses)
                .order("start_time", ascending: true)
                .execute()
                .value

            usageHistory = response.compactMap { sample in
                guard let value = sample.quantityValue else { return nil }
                return SubstanceDataPoint(date: sample.startTime, value: Int(value))
            }

            // Check today's usage
            if let latest = usageHistory.last {
                let calendar = Calendar.current
                if calendar.isDateInToday(latest.date) {
                    todayUsage = latest.value
                }
            }
        } catch {
            self.error = error
            print("Error loading nicotine history: \(error)")
        }
    }

    func logUsage(_ count: Int, date: Date = Date()) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let timezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.nicotineUses,
                value: Double(count),
                unit: "count",
                timestamp: date,
                source: .wellpathInput,
                timezone: timezone,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            await loadHistory()
        } catch {
            self.error = error
            print("Error logging nicotine usage: \(error)")
        }
    }
}


// MARK: - Response Models

struct SubstanceQuantitySampleResponse: Codable {
    let quantityValue: Double?
    let startTime: Date

    enum CodingKeys: String, CodingKey {
        case quantityValue = "quantity_value"
        case startTime = "start_time"
    }
}

struct SubstanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}
