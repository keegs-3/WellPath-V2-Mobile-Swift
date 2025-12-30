//
//  MainTabView.swift
//  WellPath
//
//  Created on 2025-10-22
//  Updated: 2025-12-30 - Custom two-bubble Liquid Glass tab bar
//    - 3 main tabs: Today | Score | My Data (left bubble)
//    - + button (right bubble)
//    - Hamburger menu (slide-out from left) for Profile, Learn, Settings
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showQuickAdd = false
    @State private var showSideMenu = false
    @State private var showEducation = false
    @State private var showCoachChat = false
    @StateObject private var searchState = WellPathDataSearchState.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Tab content
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Side menu overlay
                if showSideMenu {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSideMenu = false
                            }
                        }
                        .transition(.opacity)

                    SideMenuView(
                        isShowing: $showSideMenu,
                        showEducation: $showEducation,
                        showCoachChat: $showCoachChat
                    )
                    .transition(.move(edge: .leading))
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Custom two-bubble tab bar
                LiquidGlassTabBar(
                    selectedTab: $selectedTab,
                    onAddTap: { showQuickAdd = true }
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSideMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(currentTabTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .environmentObject(searchState)
        .sheet(isPresented: $showQuickAdd) {
            QuickAddModal()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEducation) {
            NavigationStack {
                EducationView()
            }
        }
        .sheet(isPresented: $showCoachChat) {
            CoachChatSheet()
                .presentationDetents([.large])
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab != 2 && searchState.isSearchActive {  // My Data is tab 2
                searchState.deactivateSearch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToGoals)) { _ in
            selectedTab = 0  // Today tab (Goals)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCoachChat)) { _ in
            showCoachChat = true
        }
    }

    // MARK: - Tab Content (manual switching)

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            GoalsContentView(showCoachChat: $showCoachChat)
        case 1:
            ScoreTabView()
        case 2:
            MyDataLandingView()
        default:
            GoalsContentView(showCoachChat: $showCoachChat)
        }
    }

    private var currentTabTitle: String {
        switch selectedTab {
        case 0: return "Today"
        case 1: return "Score"
        case 2: return "My Data"
        default: return "WellPath"
        }
    }
}

// MARK: - Goals Content View

struct GoalsContentView: View {
    @StateObject private var viewModel = GoalsViewModel()
    @Binding var showCoachChat: Bool
    @State private var showQuickEntry = false
    @State private var selectedGoal: PatientGoal?
    @State private var showWizard = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GoalsHeroBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    goalPillsSection
                    heroRingSection
                    nudgesSection
                    journeyContent
                    challengeSection
                    Spacer(minLength: 100)
                }
                .padding()
            }

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
                            if success { showQuickEntry = false }
                        }
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .fullScreenCover(isPresented: $showWizard) {
            WizardView()
        }
    }

    @ViewBuilder
    private var heroRingSection: some View {
        switch viewModel.journeyState {
        case .activeGoals:
            if viewModel.activeGoals.isEmpty {
                NavigationLink(destination: GoalsListView()) {
                    FloatingAdherenceArc(weeklyProgress: 0, maxPotential: 0, isEmpty: true)
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
            ProgressView().tint(.white).padding(.top, 60)
        default:
            FloatingAdherenceArc(
                weeklyProgress: 0, maxPotential: 0, isEmpty: true,
                isOnboarding: true, onSetupTap: { showWizard = true }
            )
        }
    }

    @ViewBuilder
    private var journeyContent: some View {
        switch viewModel.journeyState {
        case .loading: ProgressView().padding(40)
        case .baselineCollection: EmptyView()
        case .awaitingLabs: AwaitingLabsCard()
        case .awaitingBiometrics: AwaitingBiometricsCard()
        case .awaitingClinicianReview: AwaitingClinicianCard()
        case .activeGoals: EmptyView()
        }
    }

    @ViewBuilder
    private var goalPillsSection: some View {
        switch viewModel.journeyState {
        case .activeGoals:
            if !viewModel.activeGoals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.activeGoals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal, progress: viewModel.progressByGoal[goal.goalId])) {
                                GoalGlassPill(goal: goal, progress: viewModel.progressByGoal[goal.goalId])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .loading: EmptyView()
        default:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    NavigationLink(destination: ExampleGoalDetailView(goalType: .protein)) {
                        PreviewGoalGlassPill(icon: "fork.knife", label: "Protein", score: 75)
                    }.buttonStyle(.plain)
                    NavigationLink(destination: ExampleGoalDetailView(goalType: .steps)) {
                        PreviewGoalGlassPill(icon: "figure.walk", label: "Steps", score: 62)
                    }.buttonStyle(.plain)
                    NavigationLink(destination: ExampleGoalDetailView(goalType: .sleep)) {
                        PreviewGoalGlassPill(icon: "bed.double.fill", label: "Sleep", score: 88)
                    }.buttonStyle(.plain)
                    NavigationLink(destination: ExampleGoalDetailView(goalType: .strength)) {
                        PreviewGoalGlassPill(icon: "dumbbell.fill", label: "Strength", score: 33)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var nudgesSection: some View {
        switch viewModel.journeyState {
        case .activeGoals:
            if let nudge = viewModel.latestNudge { LatestNudgeCard(nudge: nudge) }
        case .loading: EmptyView()
        default: PreviewNudgeCard()
        }
    }

    @ViewBuilder
    private var challengeSection: some View {
        switch viewModel.journeyState {
        case .activeGoals:
            if let challenge = viewModel.activeChallenge {
                ActiveChallengeCard(challenge: challenge)
            } else {
                NoChallengesCard()
            }
        case .loading: EmptyView()
        default: ComingSoonChallengesCard()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthStateManager())
}
