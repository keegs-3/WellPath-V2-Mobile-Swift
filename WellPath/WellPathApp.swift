//
//  WellPathApp.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI
import Supabase

@main
struct WellPathApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var syncService = HealthKitSyncService.shared
    @StateObject private var displayConfig = DisplayConfigurationService.shared
    @StateObject private var pushService = PushNotificationService.shared
    @StateObject private var scoreCache = ScoreCacheService.shared

    private let supabase = SupabaseManager.shared.client

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(displayConfig)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    // Load display configuration from database (pillars, categories, views, tiers)
                    // This is needed before UI renders, so keep it synchronous
                    await loadDisplayConfiguration()

                    // Run HealthKit sync in background - don't block UI
                    Task {
                        await performInitialSync()
                    }

                    // Request push notification permission in background
                    Task {
                        await requestPushNotifications()
                    }

                    // Run cache sync in background - don't block UI
                    performCacheSync()

                    // Pre-load behavioral scores for fast UI rendering
                    Task {
                        await preloadScores()
                    }
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

    private func performCacheSync() {
        // DISABLED: LocalCacheManager is @MainActor which blocks UI during sync
        // TODO: Refactor LocalCacheManager to use background ModelContext
        // For now, data is fetched on-demand when views load
        print("📡 Cache sync disabled - data will be fetched on-demand")
    }

    private func preloadScores() async {
        // Check if user is authenticated before loading scores
        guard (try? await supabase.auth.session) != nil else {
            print("📊 Skipping score preload - user not authenticated")
            return
        }

        print("📊 Pre-loading behavioral scores...")
        await scoreCache.loadTodayScores()
    }

    private func requestPushNotifications() async {
        // Check if user is authenticated before requesting
        guard (try? await supabase.auth.session) != nil else {
            print("🔔 Skipping push notification request - user not authenticated")
            return
        }

        // Request permission and register for remote notifications
        let granted = await pushService.requestAuthorization()
        print("🔔 Push notification permission: \(granted ? "granted" : "denied")")
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        print("🔗 Deep link received: \(url)")

        // Handle Supabase auth callback URLs
        // Format: wellpath://auth/callback#access_token=...&type=...
        // Format: wellpath://auth/reset#access_token=...&type=recovery
        // Format: wellpath://auth/callback#access_token=...&type=invite

        Task {
            do {
                // Let Supabase handle the URL - it will parse the tokens
                let session = try await supabase.auth.session(from: url)
                print("🔐 Session established from deep link: \(session.user.email ?? "unknown")")

                // Check if this is an invite or password recovery flow
                // Both require the user to set their password
                if url.absoluteString.contains("type=recovery") ||
                   url.absoluteString.contains("type=invite") ||
                   url.path.contains("reset") ||
                   url.path.contains("callback") {
                    // Notify LoginView to show set password sheet
                    await MainActor.run {
                        NotificationCenter.default.post(name: .showInviteSetPassword, object: nil)
                    }
                }
            } catch {
                print("❌ Deep link auth error: \(error)")
            }
        }
    }
}
