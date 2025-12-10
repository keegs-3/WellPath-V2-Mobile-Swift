//
//  CachedDataProvider.swift
//  WellPath
//
//  Cache-first data provider that wraps PatientSamplesQueryService
//  Returns cached data immediately, then updates from network if online
//

import Foundation
import Supabase

@MainActor
final class CachedDataProvider {
    static let shared = CachedDataProvider()

    private let cacheManager = LocalCacheManager.shared
    private let queryService = PatientSamplesQueryService.shared
    private let supabase = SupabaseManager.shared.client

    private init() {}

    // MARK: - Sleep Data (Cache-First)

    /// Fetch sleep summaries with cache-first strategy
    /// Returns cached data immediately, optionally refreshes in background
    func fetchSleepSessionSummaries(
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> [SleepSessionSummaryRowLocal] {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw CachedDataError.notAuthenticated
        }

        // Check cache first
        let hasCachedData = cacheManager.hasCachedData(
            type: .sleepSummaries,
            patientId: userId,
            startDate: startDate,
            endDate: endDate
        )
        let isStale = cacheManager.isCacheStale(type: .sleepSummaries, patientId: userId)
        let isOnline = await cacheManager.isOnline()

        // Strategy:
        // 1. If we have cache and not forcing refresh, return cache immediately
        // 2. If online and (no cache OR stale OR force refresh), fetch from network
        // 3. If offline and no cache, return empty (or throw)

        if hasCachedData && !forceRefresh {
            let cached = cacheManager.fetchCachedSleepSummaries(
                patientId: userId,
                startDate: startDate,
                endDate: endDate
            )

            // Background refresh if stale and online
            if isStale && isOnline {
                Task {
                    await refreshSleepSummariesInBackground(
                        patientId: userId,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }

            return cached
        }

        // No cache or force refresh - try network
        if isOnline {
            return try await fetchAndCacheSleepSummaries(
                patientId: userId,
                startDate: startDate,
                endDate: endDate
            )
        }

        // Offline - return whatever cache we have
        let cached = cacheManager.fetchCachedSleepSummaries(
            patientId: userId,
            startDate: startDate,
            endDate: endDate
        )

        if cached.isEmpty {
            throw CachedDataError.offlineNoCache
        }

        return cached
    }

    private func fetchAndCacheSleepSummaries(
        patientId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [SleepSessionSummaryRowLocal] {
        let networkData = try await queryService.fetchSleepSessionSummaries(
            startDate: startDate,
            endDate: endDate
        )

        // Cache the data
        await cacheManager.cacheSleepSummaries(summaries: networkData, patientId: patientId)

        // Convert to local format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return networkData.map { row in
            SleepSessionSummaryRowLocal(
                sleepDate: row.sleepDate,
                sessionCount: row.sessionCount,
                sessionStart: row.sessionStart,
                sessionEnd: row.sessionEnd,
                bedtime: row.bedtime,
                waketime: row.waketime,
                deepMinutes: row.deepMinutes,
                remMinutes: row.remMinutes,
                lightMinutes: row.lightMinutes,
                awakeMinutes: row.awakeMinutes,
                totalSleepMinutes: row.totalSleepMinutes,
                timeInBedMinutes: row.timeInBedMinutes,
                totalSleepHours: row.totalSleepHours,
                sleepEfficiency: row.sleepEfficiency,
                avgBedtimeOffset7d: row.avgBedtimeOffset7d,
                avgWaketimeOffset7d: row.avgWaketimeOffset7d,
                avgSleepMinutes7d: row.avgSleepMinutes7d,
                avgDeepMinutes7d: row.avgDeepMinutes7d,
                avgRemMinutes7d: row.avgRemMinutes7d,
                avgLightMinutes7d: row.avgLightMinutes7d,
                daysInRolling7d: row.daysInRolling7d,
                bedtimeInRange: row.bedtimeInRange,
                waketimeInRange: row.waketimeInRange
            )
        }
    }

    private func refreshSleepSummariesInBackground(
        patientId: UUID,
        startDate: Date,
        endDate: Date
    ) async {
        do {
            _ = try await fetchAndCacheSleepSummaries(
                patientId: patientId,
                startDate: startDate,
                endDate: endDate
            )
            print("✅ Background sleep summary refresh complete")
        } catch {
            print("❌ Background sleep refresh failed: \(error)")
        }
    }

    // MARK: - Quantity Data (Cache-First)

    /// Fetch daily quantity aggregations with cache-first strategy
    func fetchQuantityDaily(
        quantityType: String,
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> [DailyAggregatedValue] {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw CachedDataError.notAuthenticated
        }

        let cacheKey = CacheDataType.quantitySamples
        let hasCachedData = cacheManager.hasCachedData(
            type: cacheKey,
            patientId: userId,
            startDate: startDate,
            endDate: endDate
        )
        let isStale = cacheManager.isCacheStale(type: cacheKey, patientId: userId)
        let isOnline = await cacheManager.isOnline()

        if hasCachedData && !forceRefresh {
            let cached = cacheManager.fetchCachedQuantitySamples(
                patientId: userId,
                quantityType: quantityType,
                startDate: startDate,
                endDate: endDate
            )

            if isStale && isOnline {
                Task {
                    await refreshQuantitySamplesInBackground(
                        patientId: userId,
                        quantityType: quantityType,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }

            return cached
        }

        if isOnline {
            return try await fetchAndCacheQuantitySamples(
                patientId: userId,
                quantityType: quantityType,
                startDate: startDate,
                endDate: endDate
            )
        }

        let cached = cacheManager.fetchCachedQuantitySamples(
            patientId: userId,
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate
        )

        if cached.isEmpty {
            throw CachedDataError.offlineNoCache
        }

        return cached
    }

    private func fetchAndCacheQuantitySamples(
        patientId: UUID,
        quantityType: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [DailyAggregatedValue] {
        // Fetch raw samples from network
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        let results: [QuantitySampleResult] = try await supabase
            .from("patient_quantity_samples")
            .select("id, aggregation_date, start_time, end_time, quantity_value, quantity_unit, quantity_type, metadata")
            .eq("patient_id", value: patientId)
            .eq("quantity_type", value: quantityType)
            .eq("is_primary", value: true)
            .gte("aggregation_date", value: startStr)
            .lte("aggregation_date", value: endStr)
            .order("aggregation_date", ascending: true)
            .execute()
            .value

        // Cache the samples
        await cacheManager.cacheQuantitySamples(
            samples: results,
            patientId: patientId,
            quantityType: quantityType
        )

        // Aggregate by day
        var dailyTotals: [Date: (value: Double, count: Int)] = [:]
        for sample in results {
            guard let date = sample.aggregationDate, let value = sample.quantityValue else { continue }
            let current = dailyTotals[date] ?? (0, 0)
            dailyTotals[date] = (current.value + value, current.count + 1)
        }

        return dailyTotals.map {
            DailyAggregatedValue(date: $0.key, value: $0.value.value, count: $0.value.count)
        }.sorted { $0.date < $1.date }
    }

    private func refreshQuantitySamplesInBackground(
        patientId: UUID,
        quantityType: String,
        startDate: Date,
        endDate: Date
    ) async {
        do {
            _ = try await fetchAndCacheQuantitySamples(
                patientId: patientId,
                quantityType: quantityType,
                startDate: startDate,
                endDate: endDate
            )
            print("✅ Background \(quantityType) refresh complete")
        } catch {
            print("❌ Background \(quantityType) refresh failed: \(error)")
        }
    }

    // MARK: - Sleep Stage Breakdown (Derived from Summaries)

    /// Fetch daily sleep stage breakdown using cached summaries
    func fetchSleepStageBreakdownDaily(
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> [DailySleepStageData] {
        let summaries = try await fetchSleepSessionSummaries(
            startDate: startDate,
            endDate: endDate,
            forceRefresh: forceRefresh
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return summaries.compactMap { row -> DailySleepStageData? in
            guard let date = dateFormatter.date(from: row.sleepDate) else { return nil }
            return DailySleepStageData(
                date: date,
                deepMinutes: row.deepMinutes,
                remMinutes: row.remMinutes,
                coreMinutes: row.lightMinutes,
                awakeMinutes: row.awakeMinutes,
                sleepDurationMinutes: row.totalSleepMinutes,
                timeInBedMinutes: row.timeInBedMinutes
            )
        }.sorted { $0.date < $1.date }
    }

    /// Fetch sleep duration daily using cached summaries
    func fetchSleepDurationDaily(
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> [DailyAggregatedValue] {
        let summaries = try await fetchSleepSessionSummaries(
            startDate: startDate,
            endDate: endDate,
            forceRefresh: forceRefresh
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return summaries.compactMap { row -> DailyAggregatedValue? in
            guard let date = dateFormatter.date(from: row.sleepDate) else { return nil }
            return DailyAggregatedValue(
                date: date,
                value: row.totalSleepMinutes,
                count: row.sessionCount
            )
        }.sorted { $0.date < $1.date }
    }

    /// Fetch sleep timing using cached summaries
    func fetchSleepTiming(
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> [(date: Date, bedtime: Date, waketime: Date)] {
        let summaries = try await fetchSleepSessionSummaries(
            startDate: startDate,
            endDate: endDate,
            forceRefresh: forceRefresh
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return summaries.compactMap { row -> (date: Date, bedtime: Date, waketime: Date)? in
            guard let date = dateFormatter.date(from: row.sleepDate) else { return nil }
            return (date: date, bedtime: row.bedtime, waketime: row.waketime)
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Errors

enum CachedDataError: Error, LocalizedError {
    case notAuthenticated
    case offlineNoCache
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .offlineNoCache:
            return "Offline and no cached data available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
