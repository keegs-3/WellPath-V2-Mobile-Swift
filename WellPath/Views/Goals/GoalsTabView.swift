//
//  GoalsTabView.swift
//  WellPath
//
//  Main Goals tab - the engagement hub showing progress, coach messages, and challenges
//  Redesigned with Oura-style hero ring and flattened navigation
//

import SwiftUI

struct GoalsTabView: View {
    @StateObject private var viewModel = GoalsViewModel()
    @State private var showQuickEntry = false
    @State private var selectedGoal: PatientGoal?
    @State private var showCoachChat = false
    @State private var showWizard = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Full-screen hero background
                GoalsHeroBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Goal pills ABOVE the arc (glass style)
                        goalPillsSection

                        // Floating arc (tappable → GoalsListView)
                        heroRingSection

                        // Chiron engagement card (challenges + nudges)
                        chironSection

                        // Journey-specific content (baseline card during onboarding)
                        journeyContent

                        Spacer(minLength: 100)
                    }
                    .padding()
                }

                // Floating Chat Button
                Button {
                    showCoachChat = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.green)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            // No nav title - "Goals" is shown in tab bar
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
            }
            .refreshable {
                await viewModel.loadGoals()
            }
            .task {
                await viewModel.loadGoals()
            }
            .sheet(isPresented: $showQuickEntry) {
                if let goal = selectedGoal {
                    QuickEntrySheet(
                        goal: goal,
                        currentValue: viewModel.actualValue(for: goal.goalId),
                        onSubmit: { value in
                            Task {
                                let success = await viewModel.logQuickEntry(goalId: goal.goalId, value: value)
                                if success {
                                    showQuickEntry = false
                                }
                            }
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showCoachChat) {
                CoachChatSheet()
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showWizard) {
                WizardView()
            }
        }
    }

    // MARK: - Hero Ring Section (Floating, Full Width)

    @ViewBuilder
    private var heroRingSection: some View {
        switch viewModel.journeyState {
        case .activeGoals:
            if viewModel.activeGoals.isEmpty {
                NavigationLink(destination: GoalsListView()) {
                    FloatingAdherenceArc(
                        weeklyProgress: 0,
                        maxPotential: 0,
                        isEmpty: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(destination: GoalsListView()) {
                    FloatingAdherenceArc(
                        weeklyProgress: viewModel.overallWeeklyProgress,
                        maxPotential: viewModel.overallMaxPotential,
                        isEmpty: false
                    )
                }
                .buttonStyle(.plain)
            }
        case .loading:
            ProgressView()
                .tint(.white)
                .padding(.top, 60)
        default:
            // Show tutorial/preview version during onboarding with Complete Setup pill
            FloatingAdherenceArc(
                weeklyProgress: 0,
                maxPotential: 0,
                isEmpty: true,
                isOnboarding: true,
                onSetupTap: {
                    showWizard = true
                }
            )
        }
    }

    // MARK: - Journey Content

    @ViewBuilder
    private var journeyContent: some View {
        switch viewModel.journeyState {
        case .loading:
            ProgressView()
                .padding(40)

        case .baselineCollection:
            // "Complete Setup" pill is now in the hero arc section
            EmptyView()

        case .awaitingLabs:
            AwaitingLabsCard()

        case .awaitingBiometrics:
            AwaitingBiometricsCard()

        case .awaitingClinicianReview:
            AwaitingClinicianCard()

        case .activeGoals:
            EmptyView()
        }
    }

    // MARK: - Goal Pills Section (Glass style, above arc)

    @ViewBuilder
    private var goalPillsSection: some View {
        switch viewModel.journeyState {
        case .activeGoals:
            if !viewModel.activeGoals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.activeGoals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal, progress: viewModel.progressByGoal[goal.goalId])) {
                                GoalGlassPill(
                                    goal: goal,
                                    progress: viewModel.progressByGoal[goal.goalId]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .loading:
            EmptyView()
        default:
            // Preview goal pills during onboarding - navigate to demo detail views
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    NavigationLink(destination: DemoGoalDetailView(goalType: .protein)) {
                        PreviewGoalGlassPill(icon: "fork.knife", label: "Protein", score: 75)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: DemoGoalDetailView(goalType: .steps)) {
                        PreviewGoalGlassPill(icon: "figure.walk", label: "Steps", score: 75)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: DemoGoalDetailView(goalType: .sleep)) {
                        PreviewGoalGlassPill(icon: "bed.double.fill", label: "Sleep", score: 86)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: DemoGoalDetailView(goalType: .strength)) {
                        PreviewGoalGlassPill(icon: "dumbbell.fill", label: "Strength", score: 67)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Challenges Section

    @ViewBuilder
    private var chironSection: some View {
        switch viewModel.journeyState {
        case .activeGoals:
            NavigationLink(destination: ChallengesView()) {
                ChallengesCard(
                    activeChallenge: viewModel.activeChallenge,
                    recommendedCount: viewModel.recommendedChallengeCount
                )
            }
            .buttonStyle(.plain)
        case .loading:
            EmptyView()
        default:
            // Show preview card during onboarding
            PreviewChallengesCard()
        }
    }
}

// MARK: - Goal Mini Ring (Real Data)

struct GoalMiniRing: View {
    let goal: PatientGoal
    let progress: GoalProgress?

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var progressPercent: Double {
        progress?.displayProgress ?? 0
    }

    private var pillarColor: Color {
        Color(hex: pillar.color) ?? .green
    }

    var body: some View {
        VStack(spacing: 6) {
            // Ring with icon
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 56, height: 56)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(progressPercent / 100, 1.0))
                    .stroke(
                        pillarColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)

                // Icon
                Image(systemName: pillar.icon)
                    .font(.system(size: 18))
                    .foregroundColor(pillarColor)
            }

            // Label
            Text(goal.shortTitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 60)

            // Progress
            Text("\(Int(progressPercent))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Goal Glass Pill (Score, Icon, Label - like Protein screen)

struct GoalGlassPill: View {
    let goal: PatientGoal
    let progress: GoalProgress?

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var progressPercent: Int {
        Int(progress?.displayProgress ?? 0)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Score
            Text("\(progressPercent)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            // Icon
            Image(systemName: pillar.icon)
                .font(.system(size: 14))
                .foregroundColor(.green)

            // Label
            Text(goal.shortTitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.6))
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview Goal Glass Pill (Onboarding)

struct PreviewGoalGlassPill: View {
    let icon: String
    let label: String
    let score: Int

    var body: some View {
        HStack(spacing: 8) {
            // Score
            Text("\(score)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.green)

            // Label
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.6))
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview Goal Ring (Legacy - kept for reference)

struct PreviewGoalRing: View {
    let icon: String
    let label: String
    let progress: Double

    var body: some View {
        VStack(spacing: 6) {
            // Ring with icon
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 56, height: 56)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.green.opacity(0.6),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.green.opacity(0.6))
            }

            // Label
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 60)

            // Progress
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview Nudge Card (During Onboarding)

struct PreviewNudgeCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.green)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Coach")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("Just now")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("Welcome! Complete your health profile and I'll create personalized goals just for you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview Challenges Card (During Onboarding)

struct PreviewChallengesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)

                Text("Challenges")
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Image(systemName: "flame")
                    .font(.title3)
                    .foregroundColor(.orange.opacity(0.7))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Short-term pushes")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Complete your profile to unlock personalized challenges")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Baseline Collection Card (Compact Pill)

struct BaselineCollectionCard: View {
    let completed: Int
    let total: Int
    let onContinue: () -> Void

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        Button(action: onContinue) {
            HStack(spacing: 12) {
                // Icon with progress ring
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Complete Health Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("\(completed) of \(total) complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Awaiting Labs Card

struct AwaitingLabsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Checkmark header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Baselines Complete!")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }

            // Main content
            HStack {
                Image(systemName: "testtube.2")
                    .font(.title2)
                    .foregroundColor(.purple)

                Text("Awaiting Lab Results")
                    .font(.headline)

                Spacer()
            }

            Text("Your clinician has ordered lab work. Once your results are in, we'll be one step closer to your personalized health goals.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Info callout
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Your clinician will be notified when results are available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Awaiting Biometrics Card

struct AwaitingBiometricsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Checkmarks
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Baselines & Labs Complete!")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }

            // Main content
            HStack {
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                Text("Schedule Biometric Screening")
                    .font(.headline)

                Spacer()
            }

            Text("The final step is an in-person biometric screening with your clinician to measure vital signs and body composition.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // What to expect
            VStack(alignment: .leading, spacing: 8) {
                Text("What to expect:")
                    .font(.caption)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label("Blood Pressure", systemImage: "waveform.path.ecg")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Label("Body Composition", systemImage: "figure.stand")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Label("Physical Measurements", systemImage: "ruler")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Awaiting Clinician Card

struct AwaitingClinicianCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // All complete checkmark
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("All Health Data Collected!")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }

            // Main content
            HStack {
                Image(systemName: "person.badge.clock.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                Text("Clinician Review in Progress")
                    .font(.headline)

                Spacer()
            }

            Text("Your clinician is reviewing your results and preparing personalized goal recommendations. You'll be notified when they're ready.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // What happens next
            VStack(alignment: .leading, spacing: 12) {
                Text("What happens next:")
                    .font(.caption)
                    .fontWeight(.medium)

                HStack(alignment: .top, spacing: 12) {
                    Text("1")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.orange)
                        .clipShape(Circle())

                    Text("Your clinician analyzes your biomarkers, biometrics, and baseline data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("2")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.orange)
                        .clipShape(Circle())

                    Text("Together, you'll select focus areas for your first cycle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    Text("3")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.orange)
                        .clipShape(Circle())

                    Text("Goals and challenges appear here, personalized just for you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - No Goals Card

struct NoGoalsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Active Goals")
                .font(.headline)

            Text("Your clinician will assign personalized goals based on your health data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Goals Progress Section

struct GoalsProgressSection: View {
    let goals: [PatientGoal]
    let progressByGoal: [String: GoalProgress]
    let onGoalTap: (PatientGoal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Progress")
                .font(.headline)
                .foregroundColor(.secondary)

            // Grid of goal cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(goals) { goal in
                    GoalProgressCard(
                        goal: goal,
                        progress: progressByGoal[goal.goalId]
                    )
                    .onTapGesture {
                        onGoalTap(goal)
                    }
                }
            }
        }
    }
}

// MARK: - Goal Progress Card

struct GoalProgressCard: View {
    let goal: PatientGoal
    let progress: GoalProgress?

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var progressPercent: Double {
        progress?.displayProgress ?? 0
    }

    private var actualValue: Double {
        progress?.displayActual ?? 0
    }

    private var statusColor: Color {
        guard let status = progress?.status else { return .gray }
        switch status {
        case .ahead, .completed: return .green
        case .onTrack: return Color(hex: pillar.color) ?? .blue
        case .atRisk: return .orange
        case .behind: return .red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(progressPercent / 100, 1.0))
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progressPercent)

                VStack(spacing: 2) {
                    Image(systemName: pillar.icon)
                        .font(.title2)
                        .foregroundColor(statusColor)

                    Text("\(Int(progressPercent))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .frame(width: 70, height: 70)

            // Labels
            VStack(spacing: 2) {
                Text(goal.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if goal.isWeekly {
                    Text("\(Int(actualValue))/\(Int(goal.targetValue)) \(goal.targetUnit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(Int(actualValue))/\(Int(goal.targetValue))\(goal.targetUnit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Note: Color.init(hex:) extension is defined in PillarModels.swift

// MARK: - Floating Adherence Arc (No Card)

struct FloatingAdherenceArc: View {
    let weeklyProgress: Double
    let maxPotential: Double
    var isEmpty: Bool = false
    var isOnboarding: Bool = false
    var onSetupTap: (() -> Void)? = nil

    @State private var animatedProgress: Double = 0
    @State private var animatedMax: Double = 0

    private var statusMessage: String {
        if isEmpty && !isOnboarding {
            return "No Active Goals"
        } else if weeklyProgress >= 90 {
            return "Outstanding!"
        } else if weeklyProgress >= 75 {
            return "Great Progress"
        } else if weeklyProgress >= 50 {
            return "Keep Going"
        } else if !isOnboarding {
            return "Let's Go"
        } else {
            return ""
        }
    }

    /// Whether to show actual sample data during onboarding (vs "--")
    private var showSampleData: Bool {
        isOnboarding && !isEmpty && weeklyProgress > 0
    }

    var body: some View {
        VStack(spacing: 4) {
            // Arc gauge - full width
            AdherenceArcGauge(
                progress: animatedProgress,
                maxPotential: animatedMax
            )
            .frame(height: 80)
            .opacity(isEmpty ? 0.4 : (isOnboarding ? 0.7 : 1.0))

            // Large score
            if isEmpty && !showSampleData {
                Text("--")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                Text("\(Int(animatedProgress))")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundColor(showSampleData ? .white.opacity(0.8) : .white)
            }

            // Label
            Text("WEEKLY ADHERENCE")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))
                .tracking(2)

            // Max potential (still achievable) - in green
            // Show during demo mode too
            if !isEmpty && maxPotential > 0 {
                Text("\(Int(animatedMax))% still achievable")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.56, green: 0.82, blue: 0.31).opacity(showSampleData ? 0.7 : 1.0))
                    .padding(.top, 4)
            }

            // Status message or Complete Setup pill
            if isOnboarding {
                // Complete Setup pill (tappable)
                Button {
                    onSetupTap?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.subheadline)
                        Text("Complete Setup")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .background(Color.green.opacity(0.3))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green.opacity(0.5), lineWidth: 1)
                    )
                }
                .padding(.top, 8)
            }

            // Tap hint (only when not onboarding)
            if !isOnboarding && !isEmpty {
                HStack(spacing: 4) {
                    Text("View goals")
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 2)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = weeklyProgress
                animatedMax = maxPotential
            }
        }
        .onChange(of: weeklyProgress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: maxPotential) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedMax = newValue
            }
        }
    }
}

// MARK: - Goals Time Period (for hero backgrounds)

enum GoalsTimePeriod: String {
    case morning    // 5am - 12pm
    case afternoon  // 12pm - 5pm
    case evening    // 5pm - 9pm
    case night      // 9pm - 5am

    static var current: GoalsTimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    var heroImageName: String {
        "goals-hero-\(rawValue)"
    }

    var greeting: String {
        switch self {
        case .morning: return "Good Morning"
        case .afternoon: return "Good Afternoon"
        case .evening: return "Good Evening"
        case .night: return "Good Night"
        }
    }
}

// MARK: - Full Screen Hero Background

struct GoalsHeroBackground: View {
    private var imageName: String {
        GoalsTimePeriod.current.heroImageName
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Try time-based image first, fallback to gradient
                if let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    // Fallback gradient
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.12, blue: 0.18),
                            Color(red: 0.12, green: 0.18, blue: 0.24),
                            Color(red: 0.15, green: 0.25, blue: 0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                // Dark overlay from top through ring area for readability
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.7), location: 0),
                        .init(color: .black.opacity(0.6), location: 0.2),
                        .init(color: .black.opacity(0.4), location: 0.4),
                        .init(color: .black.opacity(0.2), location: 0.5),
                        .init(color: .clear, location: 0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Gradient overlay for content readability (fades to solid at bottom)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.3),
                        .init(color: Color(uiColor: .systemBackground).opacity(0.7), location: 0.5),
                        .init(color: Color(uiColor: .systemBackground), location: 0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

#Preview {
    VStack {
        PreviewGoalGlassPill(icon: "fork.knife", label: "Protein", score: 85)
        PreviewGoalRing(icon: "figure.walk", label: "Steps", progress: 0.72)
    }
    .padding()
    .background(Color.black)
}
