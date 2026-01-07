//
//  ScoreCacheService.swift
//  WellPath
//
//  Singleton service that pre-loads and caches behavioral scores.
//  Call loadTodayScores() at app launch to populate cache.
//

import Foundation
import Supabase

@MainActor
class ScoreCacheService: ObservableObject {
    static let shared = ScoreCacheService()

    // Cached scores: [score_type: score_value]
    @Published private(set) var todayScores: [String: Int] = [:]
    @Published private(set) var baselineScores: [String: Int] = [:]
    @Published private(set) var isLoaded = false
    @Published private(set) var isLoading = false
    @Published private(set) var lastLoadTime: Date?

    private let supabase = SupabaseManager.shared.client
    private let cacheValiditySeconds: TimeInterval = 60  // Re-fetch if older than 60s

    private init() {}

    // MARK: - Load All Scores

    /// Load all behavioral scores for today in one batch query
    /// Call this at app launch or when returning to foreground
    func loadTodayScores() async {
        // Skip if recently loaded
        if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < cacheValiditySeconds {
            return
        }

        guard !isLoading else { return }
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayStr = dateFormatter.string(from: Date())

            struct ScoreResult: Codable {
                let scoreType: String
                let scoreValue: Double
                let scoreContext: String

                enum CodingKeys: String, CodingKey {
                    case scoreType = "score_type"
                    case scoreValue = "score_value"
                    case scoreContext = "score_context"
                }
            }

            // Load ALL scores for today (daily and baseline) in ONE query
            let results: [ScoreResult] = try await supabase
                .from("behavioral_scores")
                .select("score_type, score_value, score_context")
                .eq("patient_id", value: userId.uuidString)
                .or("score_date.eq.\(todayStr),score_context.eq.baseline")
                .execute()
                .value

            var daily: [String: Int] = [:]
            var baseline: [String: Int] = [:]

            for result in results {
                let score = Int(result.scoreValue.rounded())
                if result.scoreContext == "daily" {
                    daily[result.scoreType] = score
                } else if result.scoreContext == "baseline" {
                    baseline[result.scoreType] = score
                }
            }

            todayScores = daily
            baselineScores = baseline
            lastLoadTime = Date()
            isLoaded = true

            print("[ScoreCache] Loaded \(daily.count) daily scores, \(baseline.count) baseline scores")

        } catch {
            print("[ScoreCache] Error loading scores: \(error)")
        }

        isLoading = false
    }

    /// Force refresh scores (invalidate cache)
    func refresh() async {
        lastLoadTime = nil
        await loadTodayScores()
    }

    // MARK: - Get Scores

    func dailyScore(for scoreType: String) -> Int? {
        todayScores[scoreType]
    }

    func baselineScore(for scoreType: String) -> Int? {
        baselineScores[scoreType]
    }

    /// Get component scores for a composite score type
    func componentScores(for componentTypes: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for type in componentTypes {
            if let score = todayScores[type] {
                result[type] = score
            }
        }
        return result
    }

    /// Invalidate cache when new data is logged
    func invalidate() {
        lastLoadTime = nil
        isLoaded = false
    }
}
