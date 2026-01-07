//
//  HealthKitSyncProgressView.swift
//  WellPath
//
//  UI for displaying HealthKit sync progress during historical imports
//  Shows overall progress, current phase, and per-type status
//

import SwiftUI

struct HealthKitSyncProgressView: View {
    @ObservedObject var progress = HealthKitSyncProgress.shared
    @ObservedObject var syncService = HealthKitSyncService.shared
    @State private var showingDetails = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection

            // Main progress
            progressSection

            // Current phase
            phaseSection

            // Expandable type details
            if showingDetails {
                typeDetailsSection
            }

            // Action buttons
            actionButtons

            Spacer()
        }
        .padding()
        .navigationTitle("HealthKit Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: syncStatusIcon)
                .font(.system(size: 48))
                .foregroundColor(syncStatusColor)

            Text(syncStatusTitle)
                .font(.title2)
                .fontWeight(.semibold)

            if let timeRemaining = progress.formatTimeRemaining() {
                Text("Est. \(timeRemaining) remaining")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top)
    }

    private var syncStatusIcon: String {
        if progress.isHistoricalSyncActive {
            return "arrow.triangle.2.circlepath"
        } else if progress.isInitialSyncComplete {
            return "checkmark.circle.fill"
        } else {
            return "arrow.down.circle"
        }
    }

    private var syncStatusColor: Color {
        if progress.isHistoricalSyncActive {
            return .blue
        } else if progress.isInitialSyncComplete {
            return .green
        } else {
            return .orange
        }
    }

    private var syncStatusTitle: String {
        if progress.isHistoricalSyncActive {
            return "Syncing Health Data..."
        } else if progress.isInitialSyncComplete {
            return "Sync Complete"
        } else {
            return "Ready to Import"
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress.overallProgress, height: 12)
                        .animation(.easeInOut(duration: 0.3), value: progress.overallProgress)
                }
            }
            .frame(height: 12)

            // Progress text
            HStack {
                Text("\(Int(progress.overallProgress * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(progress.totalSamplesProcessed) samples")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Phase Section

    private var phaseSection: some View {
        HStack {
            if progress.isHistoricalSyncActive {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 4)
            }

            Text(progress.currentPhase)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                withAnimation {
                    showingDetails.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showingDetails ? "Hide Details" : "Show Details")
                        .font(.caption)
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Type Details Section

    private var typeDetailsSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(progress.typeProgress.keys.sorted()), id: \.self) { type in
                if let status = progress.typeProgress[type] {
                    TypeProgressRow(displayName: status.displayName, status: status)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !progress.isInitialSyncComplete && !progress.isHistoricalSyncActive {
                // Start historical import button
                Button {
                    Task {
                        await syncService.performHistoricalSync()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Import 5 Years of Data")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }

            if progress.isInitialSyncComplete {
                // Resync button
                Button {
                    Task {
                        await syncService.performIncrementalSync()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Recent Data")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(syncService.isSyncing)

                // Reset button
                Button {
                    syncService.resetSyncState()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset & Resync All")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .disabled(syncService.isSyncing)
            }

            // Error display
            if let error = progress.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.top)
    }
}

// MARK: - Type Progress Row

struct TypeProgressRow: View {
    let displayName: String
    let status: HealthKitSyncProgress.TypeSyncStatus

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            // Name and samples
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if status.samplesProcessed > 0 {
                    Text("\(status.samplesProcessed) samples")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Progress indicator or checkmark
            if status.status == .syncing {
                ProgressView()
                    .scaleEffect(0.7)
            } else if status.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if status.status == .failed {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch status.status {
        case .pending:
            return .gray
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .orange
        }
    }
}

// MARK: - Compact Progress Card

/// Compact progress indicator for embedding in other views
struct HealthKitSyncProgressCard: View {
    @ObservedObject var progress = HealthKitSyncProgress.shared
    @ObservedObject var syncService = HealthKitSyncService.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HealthKit Sync")
                        .font(.headline)

                    Text(progress.currentPhase)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if progress.isHistoricalSyncActive {
                    ProgressView()
                } else if progress.isInitialSyncComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Button {
                        Task {
                            await syncService.performHistoricalSync()
                        }
                    } label: {
                        Text("Import")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }

            if progress.isHistoricalSyncActive {
                ProgressView(value: progress.overallProgress)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Full View") {
    NavigationStack {
        HealthKitSyncProgressView()
    }
}

#Preview("Compact Card") {
    VStack {
        HealthKitSyncProgressCard()
            .padding()
        Spacer()
    }
}
