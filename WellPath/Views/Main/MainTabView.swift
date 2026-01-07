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
    @State private var showOnboarding = false
    @State private var showTour = false
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
                        showCoachChat: $showCoachChat,
                        showOnboarding: $showOnboarding,
                        showTour: $showTour
                    )
                    .transition(.move(edge: .leading))
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Custom two-bubble tab bar (hidden when side menu is open)
                if !showSideMenu {
                    LiquidGlassTabBar(
                        selectedTab: $selectedTab,
                        onAddTap: { showQuickAdd = true }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Hide hamburger when side menu is open
                    if !showSideMenu {
                        if selectedTab == 0 {
                            // Goals tab - hamburger menu
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showSideMenu.toggle()
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title3)
                            }
                        } else if selectedTab == 2 {
                            // My Data tab - favorites button
                            NavigationLink(destination: SectionDetailView(initialSection: .favorites)) {
                                Image(systemName: "star.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(currentTabTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 2 && !showSideMenu {
                        // My Data tab - search button
                        Button {
                            searchState.activateSearch()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                        }
                    }
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
                LearnView()
            }
        }
        .sheet(isPresented: $showCoachChat) {
            CoachChatSheet()
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            WizardView()
        }
        .fullScreenCover(isPresented: $showTour) {
            TourContainerView()
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
            GoalsContentView(showCoachChat: $showCoachChat, showTour: $showTour)
        case 1:
            ScoreTabView(showTour: $showTour)
        case 2:
            MyDataLandingView()
        default:
            GoalsContentView(showCoachChat: $showCoachChat, showTour: $showTour)
        }
    }

    private var currentTabTitle: String {
        switch selectedTab {
        case 0: return "Goals"
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
    @Binding var showTour: Bool
    @State private var showQuickEntry = false
    @State private var selectedGoal: PatientGoal?
    @State private var showWizard = false

    /// Whether we're in demo/locked mode (goals not yet active)
    private var isLockedMode: Bool {
        switch viewModel.journeyState {
        case .activeGoals:
            return false
        case .loading:
            return false
        default:
            return true
        }
    }

    var body: some View {
        Group {
            if isLockedMode && viewModel.journeyState != .loading {
                // Show locked view with blurred preview
                GoalsLockedView(
                    onTakeTour: { showTour = true },
                    onContinueSetup: { showWizard = true }
                )
            } else {
                // Active goals mode - show real content
                activeGoalsContent
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

    // MARK: - Active Goals Content

    private var activeGoalsContent: some View {
        ZStack(alignment: .bottomTrailing) {
            GoalsHeroBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    goalPillsSection
                        .padding(.horizontal)
                    heroRingSection
                    journeyContent
                        .padding(.horizontal)
                    chironSection
                        .padding(.horizontal)
                    Spacer(minLength: 100)
                }
                .padding(.vertical)
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
    }

    // MARK: - Active Mode Sections (only shown when activeGoals)

    @ViewBuilder
    private var heroRingSection: some View {
        if viewModel.journeyState == .loading {
            ProgressView().tint(.white).padding(.top, 60)
        } else if viewModel.activeGoals.isEmpty {
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
    }

    @ViewBuilder
    private var journeyContent: some View {
        // Journey status cards only in active mode
        EmptyView()
    }

    @ViewBuilder
    private var goalPillsSection: some View {
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
    }

    @ViewBuilder
    private var chironSection: some View {
        NavigationLink(destination: ChallengesView()) {
            ChallengesCard(
                activeChallenge: viewModel.activeChallenge,
                recommendedCount: viewModel.recommendedChallengeCount
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthStateManager())
}
