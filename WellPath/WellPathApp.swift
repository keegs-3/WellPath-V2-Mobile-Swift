//
//  WellPathApp.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

@main
struct WellPathApp: App {
    @StateObject private var syncService = HealthKitSyncService.shared
    @StateObject private var displayConfig = DisplayConfigurationService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(displayConfig)
                .task {
                    // Load display configuration from database (pillars, categories, views, tiers)
                    await loadDisplayConfiguration()

                    // Perform HealthKit sync on app launch
                    await performInitialSync()

                    // Perform local cache sync for offline support
                    await performCacheSync()
                }
        }
    }

    private func loadDisplayConfiguration() async {
        print("Loading display configuration from database...")
        await displayConfig.loadConfiguration()
        if displayConfig.isLoaded {
            print("Display configuration loaded: \(displayConfig.pillars.count) pillars, \(displayConfig.cardCategories.count) categories")
        } else if let error = displayConfig.loadError {
            print("Failed to load display configuration: \(error)")
        }
    }

    private func performInitialSync() async {
        // Check if user has authorized HealthKit
        let healthKitManager = HealthKitManager.shared

        // Only sync if authorized
        guard healthKitManager.authorizationStatus == .authorized else {
            print("HealthKit not authorized, skipping sync")
            return
        }

        print("Starting initial HealthKit sync...")

        // Enable background observers for automatic syncing
        await syncService.enableBackgroundDelivery()

        // Perform initial sync
        await syncService.performFullSync()
    }

    private func performCacheSync() async {
        let cacheManager = LocalCacheManager.shared

        // Print current cache status
        cacheManager.printCacheStatus()

        // Check if online
        guard await cacheManager.isOnline() else {
            print("📡 Offline - using local cache only")
            cacheManager.printCacheStatus()
            return
        }

        // Perform recent sync (30 days) for quick startup
        // Full historical sync happens in background
        print("🔄 Starting local cache sync...")
        await cacheManager.performRecentSync()

        // Print status after recent sync
        print("✅ Recent sync complete")
        cacheManager.printCacheStatus()

        // Schedule full historical sync in background
        Task.detached(priority: .background) {
            await cacheManager.performFullHistoricalSync()
            // Print final status after full sync
            await MainActor.run {
                print("✅ Full historical sync complete")
                cacheManager.printCacheStatus()
            }
        }
    }
}
