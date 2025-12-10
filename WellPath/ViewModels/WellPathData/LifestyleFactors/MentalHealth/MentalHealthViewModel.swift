//
//  MentalHealthViewModel.swift
//  WellPath
//
//  ViewModels for mental health assessment views.
//  Handles loading/saving assessment data via patient_quantity_samples.
//

import Foundation
import Supabase

// MARK: - Mental Health List ViewModel

@MainActor
class MentalHealthViewModel: ObservableObject {
    @Published var latestSWLSScore: Int?
    @Published var latestSWLSDate: Date?
    @Published var latestGAD2Score: Int?
    @Published var latestGAD2Date: Date?
    @Published var latestPHQ2Score: Int?
    @Published var latestPHQ2Date: Date?

    @Published var isLoading = false
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client

    func loadLatestScores() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load latest SWLS score
            if let swlsData = try await fetchLatestScore(
                patientId: userId.uuidString,
                quantityType: QuantityTypes.swlsScore
            ) {
                latestSWLSScore = Int(swlsData.value)
                latestSWLSDate = swlsData.date
            }

            // Load latest GAD-2 score
            if let gad2Data = try await fetchLatestScore(
                patientId: userId.uuidString,
                quantityType: QuantityTypes.gad2Score
            ) {
                latestGAD2Score = Int(gad2Data.value)
                latestGAD2Date = gad2Data.date
            }

            // Load latest PHQ-2 score
            if let phq2Data = try await fetchLatestScore(
                patientId: userId.uuidString,
                quantityType: QuantityTypes.phq2Score
            ) {
                latestPHQ2Score = Int(phq2Data.value)
                latestPHQ2Date = phq2Data.date
            }
        } catch {
            self.error = error
            print("Error loading mental health scores: \(error)")
        }
    }

    private func fetchLatestScore(
        patientId: String,
        quantityType: String
    ) async throws -> (value: Double, date: Date)? {
        let response: [QuantitySampleResponse] = try await supabase
            .from("patient_quantity_samples")
            .select("quantity_value, start_time")
            .eq("patient_id", value: patientId)
            .eq("quantity_type", value: quantityType)
            .order("start_time", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let sample = response.first, let value = sample.quantityValue else { return nil }
        return (value, sample.startTime)
    }
}

// MARK: - Assessment Detail ViewModel

@MainActor
class AssessmentDetailViewModel: ObservableObject {
    @Published var scoreHistory: [MentalHealthScoreDataPoint] = []
    @Published var latestScore: Int?
    @Published var latestDate: Date?
    @Published var isLoading = false
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client
    private var currentAssessmentType: MentalHealthAssessmentType?

    func loadHistory(for type: MentalHealthAssessmentType) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        isLoading = true
        currentAssessmentType = type
        defer { isLoading = false }

        do {
            let quantityType = quantityTypeId(for: type)

            let response: [QuantitySampleResponse] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: true)
                .execute()
                .value

            scoreHistory = response.compactMap { sample in
                guard let value = sample.quantityValue else { return nil }
                return MentalHealthScoreDataPoint(date: sample.startTime, score: Int(value))
            }

            if let latest = scoreHistory.last {
                latestScore = latest.score
                latestDate = latest.date
            }
        } catch {
            self.error = error
            print("Error loading assessment history: \(error)")
        }
    }

    func saveAssessment(type: MentalHealthAssessmentType, score: Int, responses: [String: Int]) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let quantityType = quantityTypeId(for: type)
            let now = Date()
            let timezone = TimeZone.current.identifier

            // Convert responses to AnyJSON metadata
            var metadata: [String: AnyJSON] = [:]
            for (key, value) in responses {
                metadata[key] = .integer(value)
            }

            // Create quantity sample using the proper write model
            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: quantityType,
                value: Double(score),
                unit: "score",
                timestamp: now,
                source: .wellpathInput,
                timezone: timezone,
                metadata: metadata.isEmpty ? nil : metadata,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            // Update local state
            latestScore = score
            latestDate = now
            scoreHistory.append(MentalHealthScoreDataPoint(date: now, score: score))

        } catch {
            self.error = error
            print("Error saving assessment: \(error)")
        }
    }

    func scoreProgress(for type: MentalHealthAssessmentType) -> Double {
        guard let score = latestScore else { return 0 }
        let range = type.scoreRange
        let rangeSize = Double(range.upperBound - range.lowerBound)
        let value = Double(score - range.lowerBound)
        return value / rangeSize
    }

    func interpretation(for type: MentalHealthAssessmentType) -> String {
        guard let score = latestScore else { return "" }
        switch type {
        case .swls: return SWLSAssessment.interpretation(for: score)
        case .gad2: return GAD2Assessment.interpretation(for: score)
        case .phq2: return PHQ2Assessment.interpretation(for: score)
        }
    }

    func interpretationDescription(for type: MentalHealthAssessmentType) -> String? {
        guard let score = latestScore else { return nil }
        switch type {
        case .swls: return SWLSAssessment.interpretationDescription(for: score)
        case .gad2: return GAD2Assessment.interpretationDescription(for: score)
        case .phq2: return PHQ2Assessment.interpretationDescription(for: score)
        }
    }

    private func quantityTypeId(for type: MentalHealthAssessmentType) -> String {
        switch type {
        case .swls: return QuantityTypes.swlsScore
        case .gad2: return QuantityTypes.gad2Score
        case .phq2: return QuantityTypes.phq2Score
        }
    }
}

// MARK: - Response Models

struct QuantitySampleResponse: Codable {
    let quantityValue: Double?
    let startTime: Date

    enum CodingKeys: String, CodingKey {
        case quantityValue = "quantity_value"
        case startTime = "start_time"
    }
}
