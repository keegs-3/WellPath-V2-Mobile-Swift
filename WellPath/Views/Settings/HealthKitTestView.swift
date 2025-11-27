//
//  HealthKitTestView.swift
//  WellPath
//
//  Simple test view to verify HealthKit availability
//

import SwiftUI
import HealthKit

struct HealthKitTestView: View {
    @State private var isAvailable = false
    @State private var testMessage = "Testing..."
    @State private var stepCount: Double = 0
    @StateObject private var syncService = HealthKitSyncService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("HealthKit Test")
                    .font(.title)
                    .bold()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Availability Test")
                        .font(.headline)
                    Text(testMessage)
                        .font(.body)
                        .foregroundColor(isAvailable ? .green : .red)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)

                if isAvailable {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Data Read")
                            .font(.headline)
                        Text("Steps today: \(Int(stepCount))")
                            .font(.body)

                        Button("Request Authorization & Read Steps") {
                            Task {
                                await testHealthKit()
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)

                    // Sync to Backend Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync to Backend")
                            .font(.headline)

                        if let lastSync = syncService.lastSyncDate {
                            Text("Last synced: \(lastSync.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never synced")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let error = syncService.syncError {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Button(syncService.isSyncing ? "Syncing..." : "Sync HealthKit Data to Database") {
                            Task {
                                await syncService.performFullSync()
                            }
                        }
                        .disabled(syncService.isSyncing)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(syncService.isSyncing ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        Button("Reset Sync State (Force Full Resync)") {
                            syncService.resetSyncState()
                        }
                        .disabled(syncService.isSyncing)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(syncService.isSyncing ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        Text("Syncs: Steps, Sleep, Protein, Water, Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
        }
        .task {
            checkAvailability()
        }
    }

    private func checkAvailability() {
        let available = HKHealthStore.isHealthDataAvailable()
        isAvailable = available
        testMessage = available ? "✅ HealthKit is available!" : "❌ HealthKit is not available"
        print("HealthKit availability: \(available)")
    }

    private func testHealthKit() async {
        let healthStore = HKHealthStore()

        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            testMessage = "❌ Steps type not available"
            return
        }

        do {
            // Request authorization
            try await healthStore.requestAuthorization(toShare: [], read: [stepsType])
            print("✅ Authorization requested")

            // Try to read today's steps
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)

            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

            let sum = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let steps = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    continuation.resume(returning: steps)
                }

                healthStore.execute(query)
            }

            stepCount = sum
            print("✅ Read \(Int(sum)) steps")
            testMessage = "✅ Successfully read health data!"

        } catch {
            testMessage = "❌ Error: \(error.localizedDescription)"
            print("❌ HealthKit test error: \(error)")
        }
    }
}

#Preview {
    HealthKitTestView()
}
