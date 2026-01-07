//
//  ChallengesView.swift
//  WellPath
//
//  Tabbed view: Active | Available | History (completed + skipped)
//  Challenges are mini-goals - same visual language and data linkage as Goals
//

import SwiftUI

enum ChallengesTab: String, CaseIterable {
    case active = "Active"
    case available = "Available"
    case history = "History"
}

struct ChallengesView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @State private var selectedTab: ChallengesTab = .active

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Challenges", selection: $selectedTab) {
                ForEach(ChallengesTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            TabView(selection: $selectedTab) {
                activeTab
                    .tag(ChallengesTab.active)

                availableTab
                    .tag(ChallengesTab.available)

                historyTab
                    .tag(ChallengesTab.history)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    // MARK: - Active Tab

    @ViewBuilder
    private var activeTab: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(40)
            } else if viewModel.activeChallenges.isEmpty {
                emptyActiveState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.activeChallenges) { challenge in
                        NavigationLink(destination: ChallengeDetailView(challenge: challenge)) {
                            ChallengeCard(challenge: challenge)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private var emptyActiveState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Active Challenges")
                .font(.headline)

            Text("Accept an available challenge to get started on a focused push toward your goals.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if !viewModel.recommendedChallenges.isEmpty {
                Button {
                    selectedTab = .available
                } label: {
                    Text("View Available")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
    }

    // MARK: - Available Tab

    @ViewBuilder
    private var availableTab: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(40)
            } else if viewModel.recommendedChallenges.isEmpty {
                emptyAvailableState
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Explanation
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)

                        Text("These challenges are personalized based on your goals and progress. Accept one to start a focused push.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    // Available challenges
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.recommendedChallenges) { challenge in
                            AvailableChallengeCard(
                                challenge: challenge,
                                onAccept: {
                                    Task { await viewModel.acceptChallenge(challenge) }
                                },
                                onSkip: { reason in
                                    Task { await viewModel.skipChallenge(challenge, reason: reason) }
                                }
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var emptyAvailableState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Available Challenges")
                .font(.headline)

            Text("Your coach will suggest challenges based on your goals and progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - History Tab

    @ViewBuilder
    private var historyTab: some View {
        ScrollView {
            if viewModel.completedChallenges.isEmpty && viewModel.skippedChallenges.isEmpty {
                emptyHistoryState
            } else {
                LazyVStack(spacing: 12) {
                    // Completed challenges
                    ForEach(viewModel.completedChallenges) { challenge in
                        NavigationLink(destination: ChallengeDetailView(challenge: challenge)) {
                            ChallengeHistoryCard(challenge: challenge, status: .completed)
                        }
                        .buttonStyle(.plain)
                    }

                    // Skipped challenges
                    ForEach(viewModel.skippedChallenges) { challenge in
                        ChallengeHistoryCard(challenge: challenge, status: .skipped)
                    }
                }
                .padding()
            }
        }
    }

    private var emptyHistoryState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No History Yet")
                .font(.headline)

            Text("Completed and skipped challenges will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Challenge Card (Active)

struct ChallengeCard: View {
    let challenge: PatientChallenge

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 4)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: challenge.displayProgress / 100)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let description = challenge.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label("Day \(challenge.daysCompleted + 1)/\(challenge.durationDays ?? 7)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(Int(challenge.displayProgress))%", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Available Challenge Card

struct AvailableChallengeCard: View {
    let challenge: PatientChallenge
    let onAccept: () -> Void
    let onSkip: (ChallengeSkipReason) -> Void

    @State private var showingSkipOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with rationale badge
            HStack {
                if let rationale = challenge.challengeRationale {
                    ChallengeRationaleBadge(rationale: rationale)
                }

                Spacer()

                if let days = challenge.durationDays {
                    Text("\(days) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Title
            Text(challenge.title)
                .font(.headline)

            // Description
            if let description = challenge.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            // AI Rationale
            if let rationale = challenge.aiRationale {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.purple)

                    Text(rationale)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(8)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Accept")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(8)
                }

                Button {
                    showingSkipOptions = true
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .confirmationDialog("Why are you skipping?", isPresented: $showingSkipOptions) {
            ForEach(ChallengeSkipReason.allCases, id: \.self) { reason in
                Button(reason.displayName) {
                    onSkip(reason)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Challenge History Card

struct ChallengeHistoryCard: View {
    let challenge: PatientChallenge
    let status: ChallengeStatus

    private var statusIcon: String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "arrow.uturn.right.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .abandoned: return "minus.circle.fill"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .completed: return .green
        case .skipped: return .orange
        case .failed: return .red
        case .abandoned: return .gray
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    if let days = challenge.durationDays {
                        Text("\(days) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if status == .skipped, let reason = challenge.skipReason {
                        Text("• \(reason)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if status == .completed {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChallengesView()
    }
}
