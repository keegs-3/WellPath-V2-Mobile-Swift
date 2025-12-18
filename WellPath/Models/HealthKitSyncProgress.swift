//
//  HealthKitSyncProgress.swift
//  WellPath
//
//  Observable model for tracking HealthKit sync progress.
//  Supports progress indicators, checkpoints for resume, and per-type status.
//

import Foundation

/// Observable class for tracking HealthKit sync progress
@MainActor
class HealthKitSyncProgress: ObservableObject {
    static let shared = HealthKitSyncProgress()

    // MARK: - Overall Progress

    /// Overall sync progress (0.0 to 1.0)
    @Published var overallProgress: Double = 0.0

    /// Current phase description for UI display
    @Published var currentPhase: String = "Ready"

    /// Whether a historical sync is currently running
    @Published var isHistoricalSyncActive: Bool = false

    /// Whether the initial historical sync has completed
    @Published var isInitialSyncComplete: Bool = false

    /// Estimated time remaining in seconds (nil if unknown)
    @Published var estimatedTimeRemaining: TimeInterval?

    // MARK: - Per-Type Status

    /// Progress status for each data type being synced
    @Published var typeProgress: [String: TypeSyncStatus] = [:]

    /// Data types that failed to sync
    @Published var failedTypes: [String] = []

    /// Last error message
    @Published var lastError: String?

    // MARK: - Types

    struct TypeSyncStatus {
        let displayName: String
        var progress: Double
        var samplesProcessed: Int
        var status: Status
        var lastSyncedDate: Date?

        enum Status: String {
            case pending
            case syncing
            case completed
            case failed
            case skipped
        }
    }

    // MARK: - Checkpoint Persistence

    private let checkpointKey = "healthkit_sync_checkpoints"
    private let initialSyncCompleteKey = "healthkit_initial_sync_complete"

    private init() {
        loadInitialSyncState()
    }

    // MARK: - Checkpoint Methods

    /// Get the last synced date checkpoint for a data type
    func getCheckpoint(for type: String) -> Date? {
        guard let data = UserDefaults.standard.data(forKey: checkpointKey),
              let checkpoints = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return nil
        }
        return checkpoints[type]
    }

    /// Save a checkpoint for a data type after successful sync
    func saveCheckpoint(for type: String, date: Date) {
        var checkpoints = getAllCheckpoints()
        checkpoints[type] = date

        if let data = try? JSONEncoder().encode(checkpoints) {
            UserDefaults.standard.set(data, forKey: checkpointKey)
        }
    }

    /// Get all checkpoints
    func getAllCheckpoints() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: checkpointKey),
              let checkpoints = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return checkpoints
    }

    /// Clear all sync checkpoints (for full resync)
    func clearAllCheckpoints() {
        UserDefaults.standard.removeObject(forKey: checkpointKey)
        isInitialSyncComplete = false
        UserDefaults.standard.set(false, forKey: initialSyncCompleteKey)
    }

    // MARK: - Initial Sync State

    private func loadInitialSyncState() {
        isInitialSyncComplete = UserDefaults.standard.bool(forKey: initialSyncCompleteKey)
    }

    func markInitialSyncComplete() {
        isInitialSyncComplete = true
        UserDefaults.standard.set(true, forKey: initialSyncCompleteKey)
    }

    // MARK: - Progress Updates

    /// Update status for a specific data type
    func updateTypeStatus(
        type: String,
        displayName: String,
        status: TypeSyncStatus.Status,
        progress: Double = 0.0,
        samplesProcessed: Int = 0
    ) {
        typeProgress[type] = TypeSyncStatus(
            displayName: displayName,
            progress: progress,
            samplesProcessed: samplesProcessed,
            status: status,
            lastSyncedDate: status == .completed ? Date() : nil
        )
    }

    /// Mark a type as failed
    func markTypeFailed(type: String, error: String) {
        if var status = typeProgress[type] {
            status.status = .failed
            typeProgress[type] = status
        }
        if !failedTypes.contains(type) {
            failedTypes.append(type)
        }
        lastError = error
    }

    /// Reset progress for new sync
    func resetProgress() {
        overallProgress = 0.0
        currentPhase = "Starting..."
        typeProgress = [:]
        failedTypes = []
        lastError = nil
        estimatedTimeRemaining = nil
    }

    // MARK: - Helpers

    /// Format time interval for display
    func formatTimeRemaining() -> String? {
        guard let remaining = estimatedTimeRemaining else { return nil }
        let minutes = Int(remaining / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    /// Get count of completed types
    var completedTypesCount: Int {
        typeProgress.values.filter { $0.status == .completed }.count
    }

    /// Get total types being synced
    var totalTypesCount: Int {
        typeProgress.count
    }

    /// Total samples processed across all types
    var totalSamplesProcessed: Int {
        typeProgress.values.reduce(0) { $0 + $1.samplesProcessed }
    }
}
