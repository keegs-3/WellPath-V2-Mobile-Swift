//
//  TourModels.swift
//  WellPath
//
//  Database-driven tour step model and state manager.
//  Content is loaded from Supabase tour_content table.
//

import SwiftUI

// MARK: - Tour Step (UI Model)

/// UI-facing tour step model, populated from database TourContent
struct TourStep: Identifiable {
    let id: String
    let section: TourSection
    let screen: TourScreen
    let coachMessage: String
    let coachSubtext: String?
    let highlightElements: [HighlightElement]?
    let allowsInteraction: Bool
    let demoDataKey: String?

    /// Create from database TourContent
    init(from content: TourContent) {
        self.id = content.id
        self.section = content.section
        self.screen = TourScreen.from(content: content)
        self.coachMessage = content.chironMessage
        self.coachSubtext = content.chironSubtext
        self.highlightElements = content.highlightElements
        self.allowsInteraction = content.allowDeepNavigation
        self.demoDataKey = content.demoDataKey
    }

    /// Fallback initializer for hardcoded steps
    init(
        id: String,
        section: TourSection,
        screen: TourScreen,
        coachMessage: String,
        coachSubtext: String? = nil,
        highlightElements: [HighlightElement]? = nil,
        allowsInteraction: Bool = false,
        demoDataKey: String? = nil
    ) {
        self.id = id
        self.section = section
        self.screen = screen
        self.coachMessage = coachMessage
        self.coachSubtext = coachSubtext
        self.highlightElements = highlightElements
        self.allowsInteraction = allowsInteraction
        self.demoDataKey = demoDataKey
    }
}

// MARK: - Tour Screen

/// Screen types for tour display - maps to database screen_type + section
enum TourScreen {
    // Welcome section
    case welcome
    case chironFeatures

    // Navigation section
    case navigationOverview
    case goalsTabIntro
    case scoreTabIntro
    case dataTabIntro
    case plusButton
    case hamburgerMenu

    // Goals section
    case goalsOverview
    case goalPills
    case adherenceArc
    case arcMechanics
    case goalsList
    case goalManagement
    case coachNudges
    case challenges

    // Score section
    case scoreOverview
    case scoreBreakdown
    case scorePillars
    case pillarDetail
    case componentDetail

    // Data section
    case dataOverview
    case dataSections
    case dataFavorites
    case dataCardNavigation
    case dataDeepNavigation

    // Onboarding section
    case onboardingClinician
    case onboardingBaselines
    case onboardingRecommendations
    case onboardingTracking
    case onboardingLabs

    // Wrap up
    case wrapUpSummary
    case wrapUpNextSteps

    /// Map database content to screen type
    static func from(content: TourContent) -> TourScreen {
        // Map based on content_key for precise matching
        switch content.contentKey {
        // Welcome
        case "welcome.intro": return .welcome
        case "welcome.features": return .chironFeatures

        // Navigation
        case "navigation.overview": return .navigationOverview
        case "navigation.goals_tab": return .goalsTabIntro
        case "navigation.score_tab": return .scoreTabIntro
        case "navigation.data_tab": return .dataTabIntro
        case "navigation.plus_button": return .plusButton
        case "navigation.hamburger": return .hamburgerMenu

        // Goals
        case "goals.overview": return .goalsOverview
        case "goals.pills": return .goalPills
        case "goals.arc_intro": return .adherenceArc
        case "goals.arc_mechanics": return .arcMechanics
        case "goals.goals_list": return .goalsList
        case "goals.management": return .goalManagement
        case "goals.nudges": return .coachNudges
        case "goals.challenges": return .challenges

        // Score
        case "score.overview": return .scoreOverview
        case "score.breakdown": return .scoreBreakdown
        case "score.pillars": return .scorePillars
        case "score.pillar_detail": return .pillarDetail
        case "score.component_detail": return .componentDetail

        // Data
        case "data.overview": return .dataOverview
        case "data.sections": return .dataSections
        case "data.favorites": return .dataFavorites
        case "data.card_navigation": return .dataCardNavigation
        case "data.deep_navigation": return .dataDeepNavigation

        // Onboarding
        case "onboarding.clinician": return .onboardingClinician
        case "onboarding.baselines": return .onboardingBaselines
        case "onboarding.recommendations": return .onboardingRecommendations
        case "onboarding.tracking": return .onboardingTracking
        case "onboarding.labs": return .onboardingLabs

        // Wrap up
        case "wrapup.summary": return .wrapUpSummary
        case "wrapup.next_steps": return .wrapUpNextSteps

        // Fallback based on section
        default:
            switch content.section {
            case .welcome: return .welcome
            case .navigation: return .navigationOverview
            case .goals: return .goalsOverview
            case .score: return .scoreOverview
            case .data: return .dataOverview
            case .onboarding: return .onboardingClinician
            case .wrapup: return .wrapUpSummary
            }
        }
    }
}

// MARK: - Tour State Manager

@MainActor
class InteractiveTourManager: ObservableObject {
    static let shared = InteractiveTourManager()

    @Published var isShowingTour = false
    @Published var currentStepIndex = 0
    @Published var highlightedArea: CGRect? = nil
    @Published var isLoading = false
    @Published var loadError: Error?

    /// Loaded tour steps from database
    @Published private(set) var steps: [TourStep] = []

    private let contentService = TourContentService.shared

    private init() {}

    // MARK: - Computed Properties

    var currentStep: TourStep {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else {
            return TourStep.fallbackWelcome
        }
        return steps[currentStepIndex]
    }

    var totalSteps: Int {
        steps.count
    }

    var isFirstStep: Bool {
        currentStepIndex == 0
    }

    var isLastStep: Bool {
        currentStepIndex == totalSteps - 1
    }

    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStepIndex + 1) / Double(totalSteps)
    }

    /// Current section being displayed
    var currentSection: TourSection {
        currentStep.section
    }

    /// All unique sections in order
    var sections: [TourSection] {
        var seen = Set<TourSection>()
        var result: [TourSection] = []
        for step in steps {
            if !seen.contains(step.section) {
                seen.insert(step.section)
                result.append(step.section)
            }
        }
        return result
    }

    // MARK: - Tour Lifecycle

    /// Start the tour - loads content from database
    func startTour() async {
        isLoading = true
        loadError = nil

        // Load content from database
        await contentService.loadAllContent()

        if contentService.isLoaded && !contentService.tourSteps.isEmpty {
            // Convert database content to UI steps
            steps = contentService.tourSteps.map { TourStep(from: $0) }
            print("[Tour] Loaded \(steps.count) steps from database")
        } else {
            // Fall back to hardcoded steps
            steps = TourStep.fallbackSteps
            print("[Tour] Using \(steps.count) fallback steps")
        }

        isLoading = false
        currentStepIndex = 0
        isShowingTour = true
    }

    /// Start tour synchronously (uses cached or fallback content)
    func startTourSync() {
        if contentService.isLoaded && !contentService.tourSteps.isEmpty {
            steps = contentService.tourSteps.map { TourStep(from: $0) }
        } else {
            steps = TourStep.fallbackSteps
        }
        currentStepIndex = 0
        isShowingTour = true
    }

    func endTour() {
        isShowingTour = false
        currentStepIndex = 0
        UserDefaults.standard.set(true, forKey: "wellpath_interactive_tour_completed")
    }

    func nextStep() {
        if currentStepIndex < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStepIndex += 1
            }
        }
    }

    func previousStep() {
        if currentStepIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStepIndex -= 1
            }
        }
    }

    func goToStep(_ index: Int) {
        guard index >= 0 && index < totalSteps else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStepIndex = index
        }
    }

    /// Jump to first step of a section
    func goToSection(_ section: TourSection) {
        if let index = steps.firstIndex(where: { $0.section == section }) {
            goToStep(index)
        }
    }

    /// Jump to first step matching a specific screen type
    func goToScreen(_ screen: TourScreen) {
        if let index = steps.firstIndex(where: { $0.screen == screen }) {
            goToStep(index)
        }
    }

    var hasSeenTour: Bool {
        UserDefaults.standard.bool(forKey: "wellpath_interactive_tour_completed")
    }

    /// Get demo data for current step
    func currentDemoData() -> TourDemoData? {
        guard let key = currentStep.demoDataKey else { return nil }
        return contentService.getDemoData(key)
    }
}

// MARK: - Fallback Steps

extension TourStep {
    static let fallbackWelcome = TourStep(
        id: "fallback-welcome",
        section: .welcome,
        screen: .welcome,
        coachMessage: "Welcome to WellPath! I'm Chiron, your longevity assistant.",
        coachSubtext: "I'll guide you through optimizing your healthspan."
    )

    /// Fallback steps if database load fails
    static let fallbackSteps: [TourStep] = [
        TourStep(
            id: "fallback-1",
            section: .welcome,
            screen: .welcome,
            coachMessage: "Welcome to WellPath! I'm Chiron, your longevity assistant.",
            coachSubtext: "I'll guide you through optimizing your healthspan."
        ),
        TourStep(
            id: "fallback-2",
            section: .goals,
            screen: .goalsOverview,
            coachMessage: "This is your Goals tab.",
            coachSubtext: "Track your active health goals and weekly progress here."
        ),
        TourStep(
            id: "fallback-3",
            section: .score,
            screen: .scoreOverview,
            coachMessage: "Your WellPath Score reflects your overall health optimization.",
            coachSubtext: "It combines biomarkers, surveys, and education."
        ),
        TourStep(
            id: "fallback-4",
            section: .data,
            screen: .dataOverview,
            coachMessage: "The Data tab organizes all your health information.",
            coachSubtext: "Browse by pillars, markers, biomarkers, or biometrics."
        ),
        TourStep(
            id: "fallback-5",
            section: .wrapup,
            screen: .wrapUpNextSteps,
            coachMessage: "You're ready to start your WellPath journey!",
            coachSubtext: "Set your baselines now, or explore on your own."
        )
    ]
}

// MARK: - Legacy Compatibility

/// For backward compatibility with existing code
@MainActor
struct TourFlow {
    static var totalSteps: Int {
        InteractiveTourManager.shared.totalSteps
    }
}
