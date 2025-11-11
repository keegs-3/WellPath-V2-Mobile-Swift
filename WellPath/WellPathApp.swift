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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Perform HealthKit sync on app launch
                    await performInitialSync()
                }
        }
    }

    private func performInitialSync() async {
        // Check if user has authorized HealthKit
        let healthKitManager = HealthKitManager.shared

        // Only sync if authorized
        guard healthKitManager.authorizationStatus == .authorized else {
            print("ℹ️ HealthKit not authorized, skipping sync")
            return
        }

        print("🚀 Starting initial HealthKit sync...")
        await syncService.performFullSync()
    }
}
