//
//  LocalCacheManager.swift
//  WellPath
//
//  Manages local SwiftData cache for offline functionality
//  Implements cache-first strategy with background sync
//

import Foundation
import SwiftData
import Supabase

@MainActor
final class LocalCacheManager {
    static let shared = LocalCacheManager()

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    private let supabase = SupabaseManager.shared.client

    // Cache settings
    private let defaultCacheYears: Int = 5  // Cache 5 years of historical data
    private let staleCacheMinutes: Int = 60 * 6  // Refresh cache every 6 hours if online

    private init() {
        setupModelContainer()
    }

    private func setupModelContainer() {
        do {
            let schema = Schema([
                CachedQuantitySample.self,
                CachedSleepSummary.self,
                CachedCorrelationSample.self,
                CachedDisplayMetric.self,
                CacheSyncStatus.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer?.mainContext
            print("✅ LocalCacheManager: SwiftData container initialized")
        } catch {
            print("❌ LocalCacheManager: Failed to setup model container: \(error)")
        }
    }

    // MARK: - Public API

    /// Check if we have cached data for a given type and date range
    func hasCachedData(
        type: CacheDataType,
        patientId: UUID,
        startDate: Date,
        endDate: Date
    ) -> Bool {
        guard let context = modelContext else { return false }

        let key = "\(type.rawValue)_\(patientId.uuidString)"
        let descriptor = FetchDescriptor<CacheSyncStatus>(
            predicate: #Predicate { $0.key == key }
        )

        guard let status = try? context.fetch(descriptor).first else { return false }

        // Check if cached data covers the requested range
        guard let oldest = status.oldestDataDate,
              let newest = status.newestDataDate else { return false }

        return oldest <= startDate && newest >= endDate
    }

    /// Check if cache is stale (needs refresh when online)
    func isCacheStale(type: CacheDataType, patientId: UUID) -> Bool {
        guard let context = modelContext else { return true }

        let key = "\(type.rawValue)_\(patientId.uuidString)"
        let descriptor = FetchDescriptor<CacheSyncStatus>(
            predicate: #Predicate { $0.key == key }
        )

        guard let status = try? context.fetch(descriptor).first else { return true }

        let staleThreshold = Date().addingTimeInterval(-Double(staleCacheMinutes * 60))
        return status.lastSyncDate < staleThreshold
    }

    // MARK: - Sleep Summary Cache

    /// Fetch sleep summaries from local cache
    func fetchCachedSleepSummaries(
        patientId: UUID,
        startDate: Date,
        endDate: Date
    ) -> [SleepSessionSummaryRowLocal] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CachedSleepSummary>(
            predicate: #Predicate {
                $0.patientId == patientId &&
                $0.sleepDate >= startDate &&
                $0.sleepDate <= endDate
            },
            sortBy: [SortDescriptor(\.sleepDate, order: .reverse)]
        )

        guard let cached = try? context.fetch(descriptor) else { return [] }
        return cached.compactMap { $0.toSummaryRow() }
    }

    /// Save sleep summaries to local cache
    /// Processes in batches to avoid blocking UI
    func cacheSleepSummaries(
        summaries: [SleepSessionSummaryRow],
        patientId: UUID
    ) async {
        guard let context = modelContext else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let now = Date()

        // Process in batches of 50 to avoid blocking UI
        let batchSize = 50
        var processed = 0

        for row in summaries {
            let cached = CachedSleepSummary(from: row, patientId: patientId, cachedAt: now)

            // Check if exists and update, or insert
            let compositeKey = cached.compositeKey
            let descriptor = FetchDescriptor<CachedSleepSummary>(
                predicate: #Predicate { $0.compositeKey == compositeKey }
            )

            if let existing = try? context.fetch(descriptor).first {
                // Update existing
                existing.sessionCount = cached.sessionCount
                existing.sessionStart = cached.sessionStart
                existing.sessionEnd = cached.sessionEnd
                existing.bedtime = cached.bedtime
                existing.waketime = cached.waketime
                existing.deepMinutes = cached.deepMinutes
                existing.remMinutes = cached.remMinutes
                existing.lightMinutes = cached.lightMinutes
                existing.awakeMinutes = cached.awakeMinutes
                existing.totalSleepMinutes = cached.totalSleepMinutes
                existing.timeInBedMinutes = cached.timeInBedMinutes
                existing.sleepEfficiency = cached.sleepEfficiency
                existing.avgBedtimeOffset7d = cached.avgBedtimeOffset7d
                existing.avgWaketimeOffset7d = cached.avgWaketimeOffset7d
                existing.avgSleepMinutes7d = cached.avgSleepMinutes7d
                existing.avgDeepMinutes7d = cached.avgDeepMinutes7d
                existing.avgRemMinutes7d = cached.avgRemMinutes7d
                existing.avgLightMinutes7d = cached.avgLightMinutes7d
                existing.daysInRolling7d = cached.daysInRolling7d
                existing.bedtimeInRange = cached.bedtimeInRange
                existing.waketimeInRange = cached.waketimeInRange
                existing.cachedAt = now
            } else {
                context.insert(cached)
            }

            processed += 1

            // Yield to let UI update every batch
            if processed % batchSize == 0 {
                try? context.save()
                await Task.yield()
            }
        }

        // Update sync status
        updateSyncStatus(
            type: .sleepSummaries,
            patientId: patientId,
            summaries: summaries,
            dateFormatter: dateFormatter
        )

        try? context.save()
        print("✅ Cached \(summaries.count) sleep summaries")
    }

    private func updateSyncStatus(
        type: CacheDataType,
        patientId: UUID,
        summaries: [SleepSessionSummaryRow],
        dateFormatter: DateFormatter
    ) {
        guard let context = modelContext else { return }

        let key = "\(type.rawValue)_\(patientId.uuidString)"
        let descriptor = FetchDescriptor<CacheSyncStatus>(
            predicate: #Predicate { $0.key == key }
        )

        let dates = summaries.compactMap { dateFormatter.date(from: $0.sleepDate) }
        let oldestDate = dates.min()
        let newestDate = dates.max()

        if let existing = try? context.fetch(descriptor).first {
            existing.lastSyncDate = Date()
            if let oldest = oldestDate, existing.oldestDataDate == nil || oldest < existing.oldestDataDate! {
                existing.oldestDataDate = oldest
            }
            if let newest = newestDate, existing.newestDataDate == nil || newest > existing.newestDataDate! {
                existing.newestDataDate = newest
            }
            existing.recordCount = summaries.count
        } else {
            let status = CacheSyncStatus(
                key: key,
                patientId: patientId,
                lastSyncDate: Date(),
                oldestDataDate: oldestDate,
                newestDataDate: newestDate,
                recordCount: summaries.count
            )
            context.insert(status)
        }
    }

    // MARK: - Quantity Samples Cache

    /// Fetch quantity samples from local cache
    func fetchCachedQuantitySamples(
        patientId: UUID,
        quantityType: String,
        startDate: Date,
        endDate: Date
    ) -> [DailyAggregatedValue] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CachedQuantitySample>(
            predicate: #Predicate {
                $0.patientId == patientId &&
                $0.quantityType == quantityType &&
                $0.aggregationDate >= startDate &&
                $0.aggregationDate <= endDate
            },
            sortBy: [SortDescriptor(\.aggregationDate, order: .forward)]
        )

        guard let cached = try? context.fetch(descriptor) else { return [] }

        // Group by date and sum values
        var dailyTotals: [Date: (value: Double, count: Int)] = [:]
        for sample in cached {
            let date = Calendar.current.startOfDay(for: sample.aggregationDate)
            let current = dailyTotals[date] ?? (0, 0)
            dailyTotals[date] = (current.value + sample.value, current.count + 1)
        }

        return dailyTotals.map {
            DailyAggregatedValue(date: $0.key, value: $0.value.value, count: $0.value.count)
        }.sorted { $0.date < $1.date }
    }

    /// Save quantity samples to local cache
    func cacheQuantitySamples(
        samples: [QuantitySampleResult],
        patientId: UUID,
        quantityType: String
    ) async {
        guard let context = modelContext else { return }

        let now = Date()
        var dates: [Date] = []

        for sample in samples {
            guard let date = sample.aggregationDate,
                  let value = sample.quantityValue else { continue }

            dates.append(date)

            // Check if exists
            let sampleId = sample.id
            let descriptor = FetchDescriptor<CachedQuantitySample>(
                predicate: #Predicate { $0.id == sampleId }
            )

            if let existing = try? context.fetch(descriptor).first {
                existing.value = value
                existing.cachedAt = now
            } else {
                let cached = CachedQuantitySample(
                    id: sample.id,
                    patientId: patientId,
                    quantityType: quantityType,
                    aggregationDate: date,
                    value: value,
                    unit: sample.quantityUnit,
                    cachedAt: now
                )
                context.insert(cached)
            }
        }

        // Update sync status
        let key = "\(CacheDataType.quantitySamples.rawValue)_\(quantityType)_\(patientId.uuidString)"
        updateQuantitySyncStatus(key: key, patientId: patientId, dates: dates, recordCount: samples.count)

        try? context.save()
        print("✅ Cached \(samples.count) \(quantityType) samples")
    }

    private func updateQuantitySyncStatus(key: String, patientId: UUID, dates: [Date], recordCount: Int) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<CacheSyncStatus>(
            predicate: #Predicate { $0.key == key }
        )

        let oldestDate = dates.min()
        let newestDate = dates.max()

        if let existing = try? context.fetch(descriptor).first {
            existing.lastSyncDate = Date()
            if let oldest = oldestDate, existing.oldestDataDate == nil || oldest < existing.oldestDataDate! {
                existing.oldestDataDate = oldest
            }
            if let newest = newestDate, existing.newestDataDate == nil || newest > existing.newestDataDate! {
                existing.newestDataDate = newest
            }
            existing.recordCount = recordCount
        } else {
            let status = CacheSyncStatus(
                key: key,
                patientId: patientId,
                lastSyncDate: Date(),
                oldestDataDate: oldestDate,
                newestDataDate: newestDate,
                recordCount: recordCount
            )
            context.insert(status)
        }
    }

    // MARK: - Full Historical Sync

    /// Perform a full historical data sync for offline support
    /// Call this on app launch or when user has good connectivity
    func performFullHistoricalSync() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            print("❌ LocalCacheManager: No authenticated user for sync")
            return
        }

        print("🔄 Starting full historical sync...")

        let calendar = Calendar.current
        let now = Date()
        let yearsAgo = calendar.date(byAdding: .year, value: -defaultCacheYears, to: now)!

        // Sync sleep summaries
        await syncSleepSummaries(patientId: userId, startDate: yearsAgo, endDate: now)

        // Sync quantity types
        let quantityTypes = [
            PatientSamplesQueryService.QuantityTypes.steps,
            PatientSamplesQueryService.QuantityTypes.proteinGrams,
            PatientSamplesQueryService.QuantityTypes.vegetablesServings,
            PatientSamplesQueryService.QuantityTypes.fruitsServings,
            PatientSamplesQueryService.QuantityTypes.legumesServings,
            PatientSamplesQueryService.QuantityTypes.wholeGrainsServings,
            PatientSamplesQueryService.QuantityTypes.alcoholDrinks
        ]

        for quantityType in quantityTypes {
            await syncQuantitySamples(patientId: userId, quantityType: quantityType, startDate: yearsAgo, endDate: now)
        }

        print("✅ Full historical sync completed")
    }

    /// Sync recent data only (last 30 days) - faster refresh
    func performRecentSync() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!

        await syncSleepSummaries(patientId: userId, startDate: thirtyDaysAgo, endDate: now)

        let quantityTypes = [
            PatientSamplesQueryService.QuantityTypes.steps,
            PatientSamplesQueryService.QuantityTypes.proteinGrams
        ]

        for quantityType in quantityTypes {
            await syncQuantitySamples(patientId: userId, quantityType: quantityType, startDate: thirtyDaysAgo, endDate: now)
        }
    }

    private func syncSleepSummaries(patientId: UUID, startDate: Date, endDate: Date) async {
        do {
            let summaries = try await PatientSamplesQueryService.shared.fetchSleepSessionSummaries(
                startDate: startDate,
                endDate: endDate
            )
            await cacheSleepSummaries(summaries: summaries, patientId: patientId)
        } catch {
            print("❌ Failed to sync sleep summaries: \(error)")
        }
    }

    private func syncQuantitySamples(patientId: UUID, quantityType: String, startDate: Date, endDate: Date) async {
        do {
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
                .execute()
                .value

            await cacheQuantitySamples(samples: results, patientId: patientId, quantityType: quantityType)
        } catch {
            print("❌ Failed to sync \(quantityType) samples: \(error)")
        }
    }

    // MARK: - Cache Cleanup

    /// Clear all cached data for a patient
    func clearCache(for patientId: UUID) {
        guard let context = modelContext else { return }

        // Delete all cached data for this patient
        let sleepDescriptor = FetchDescriptor<CachedSleepSummary>(
            predicate: #Predicate { $0.patientId == patientId }
        )
        let quantityDescriptor = FetchDescriptor<CachedQuantitySample>(
            predicate: #Predicate { $0.patientId == patientId }
        )
        let correlationDescriptor = FetchDescriptor<CachedCorrelationSample>(
            predicate: #Predicate { $0.patientId == patientId }
        )
        let syncStatusDescriptor = FetchDescriptor<CacheSyncStatus>(
            predicate: #Predicate { $0.patientId == patientId }
        )

        do {
            let sleepItems = try context.fetch(sleepDescriptor)
            sleepItems.forEach { context.delete($0) }

            let quantityItems = try context.fetch(quantityDescriptor)
            quantityItems.forEach { context.delete($0) }

            let correlationItems = try context.fetch(correlationDescriptor)
            correlationItems.forEach { context.delete($0) }

            let syncItems = try context.fetch(syncStatusDescriptor)
            syncItems.forEach { context.delete($0) }

            try context.save()
            print("✅ Cleared cache for patient \(patientId)")
        } catch {
            print("❌ Failed to clear cache: \(error)")
        }
    }

    // MARK: - Network Connectivity Check

    /// Simple connectivity check - attempt a lightweight API call
    func isOnline() async -> Bool {
        do {
            // Try to get current session - lightweight check
            _ = try await supabase.auth.session
            return true
        } catch {
            return false
        }
    }

    // MARK: - Cache Status & Debugging

    /// Get detailed cache status for debugging
    func printCacheStatus() {
        guard let context = modelContext else {
            print("📊 Cache Status: No model context available")
            return
        }

        print("\n" + String(repeating: "=", count: 60))
        print("📊 LOCAL CACHE STATUS")
        print(String(repeating: "=", count: 60))

        // Print database location
        if let container = modelContainer {
            let configurations = container.configurations
            for config in configurations {
                let url = config.url
                print("📁 Database: \(url.path)")
            }
        }

        // Count cached items
        do {
            let sleepCount = try context.fetchCount(FetchDescriptor<CachedSleepSummary>())
            let quantityCount = try context.fetchCount(FetchDescriptor<CachedQuantitySample>())
            let correlationCount = try context.fetchCount(FetchDescriptor<CachedCorrelationSample>())

            print("\n📈 Cached Records:")
            print("   Sleep Summaries: \(sleepCount)")
            print("   Quantity Samples: \(quantityCount)")
            print("   Correlation Samples: \(correlationCount)")
            print("   Total: \(sleepCount + quantityCount + correlationCount)")

            // Get sync status
            let syncStatuses = try context.fetch(FetchDescriptor<CacheSyncStatus>())
            if !syncStatuses.isEmpty {
                print("\n🔄 Sync Status:")
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short

                for status in syncStatuses {
                    let key = status.key.replacingOccurrences(of: status.patientId.uuidString, with: "...")
                    let lastSync = dateFormatter.string(from: status.lastSyncDate)
                    let oldest = status.oldestDataDate.map { dateFormatter.string(from: $0) } ?? "N/A"
                    let newest = status.newestDataDate.map { dateFormatter.string(from: $0) } ?? "N/A"
                    print("   \(key)")
                    print("      Last sync: \(lastSync)")
                    print("      Range: \(oldest) → \(newest)")
                    print("      Records: \(status.recordCount)")
                }
            } else {
                print("\n🔄 Sync Status: No sync history yet")
            }

        } catch {
            print("❌ Error reading cache status: \(error)")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }

    /// Get cache statistics as a struct (for UI display)
    func getCacheStats() -> CacheStats {
        guard let context = modelContext else {
            return CacheStats(sleepCount: 0, quantityCount: 0, correlationCount: 0, lastSyncDate: nil, isInitialized: false)
        }

        do {
            let sleepCount = try context.fetchCount(FetchDescriptor<CachedSleepSummary>())
            let quantityCount = try context.fetchCount(FetchDescriptor<CachedQuantitySample>())
            let correlationCount = try context.fetchCount(FetchDescriptor<CachedCorrelationSample>())

            // Get most recent sync
            let syncStatuses = try context.fetch(FetchDescriptor<CacheSyncStatus>(
                sortBy: [SortDescriptor(\.lastSyncDate, order: .reverse)]
            ))
            let lastSync = syncStatuses.first?.lastSyncDate

            return CacheStats(
                sleepCount: sleepCount,
                quantityCount: quantityCount,
                correlationCount: correlationCount,
                lastSyncDate: lastSync,
                isInitialized: true
            )
        } catch {
            return CacheStats(sleepCount: 0, quantityCount: 0, correlationCount: 0, lastSyncDate: nil, isInitialized: false)
        }
    }
}

// MARK: - Cache Statistics

struct CacheStats {
    let sleepCount: Int
    let quantityCount: Int
    let correlationCount: Int
    let lastSyncDate: Date?
    let isInitialized: Bool

    var totalRecords: Int {
        sleepCount + quantityCount + correlationCount
    }

    var description: String {
        if !isInitialized {
            return "Cache not initialized"
        }
        if totalRecords == 0 {
            return "Cache empty"
        }
        let syncInfo = lastSyncDate.map { "Last sync: \(formatDate($0))" } ?? "Never synced"
        return "\(totalRecords) records cached. \(syncInfo)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Cache Data Types

enum CacheDataType: String {
    case sleepSummaries = "sleep_summaries"
    case quantitySamples = "quantity"
    case correlationSamples = "correlation"
    case displayMetrics = "display_metrics"
}
