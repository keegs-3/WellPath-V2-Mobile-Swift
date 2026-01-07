//
//  TourContentService.swift
//  WellPath
//
//  Service for loading tour content from the database
//

import Foundation

@MainActor
class TourContentService: ObservableObject {
    static let shared = TourContentService()

    @Published private(set) var tourSteps: [TourContent] = []
    @Published private(set) var demoData: [String: TourDemoData] = [:]
    @Published private(set) var chironContent: [ChironContent] = []
    @Published private(set) var challengeContent: [String: ChallengeContent] = [:]
    @Published private(set) var isLoaded = false
    @Published private(set) var loadError: Error?

    private let supabase = SupabaseManager.shared.client

    private init() {}

    // MARK: - Load All Content

    /// Loads all tour content from the database
    func loadAllContent() async {
        do {
            async let steps = loadTourSteps()
            async let demo = loadDemoData()
            async let chiron = loadChironContent()
            async let challenge = loadChallengeContent()

            let (stepsResult, demoResult, chironResult, challengeResult) = try await (steps, demo, chiron, challenge)

            self.tourSteps = stepsResult
            self.demoData = demoResult
            self.chironContent = chironResult
            self.challengeContent = challengeResult
            self.isLoaded = true
            self.loadError = nil

            print("[TourContent] Loaded \(stepsResult.count) tour steps, \(demoResult.count) demo data sets, \(chironResult.count) Chiron messages, \(challengeResult.count) challenge content")

        } catch {
            print("[TourContent] Error loading content: \(error)")
            self.loadError = error
            // Fall back to hardcoded content if needed
            self.tourSteps = Self.fallbackTourSteps
            self.isLoaded = true
        }
    }

    // MARK: - Individual Loaders

    private func loadTourSteps() async throws -> [TourContent] {
        let steps: [TourContent] = try await supabase
            .from("tour_content")
            .select("*")
            .eq("is_active", value: true)
            .order("step_order")
            .execute()
            .value

        return steps
    }

    private func loadDemoData() async throws -> [String: TourDemoData] {
        let data: [TourDemoData] = try await supabase
            .from("tour_demo_data")
            .select("*")
            .eq("is_active", value: true)
            .execute()
            .value

        var result: [String: TourDemoData] = [:]
        for item in data {
            result[item.dataKey] = item
        }
        return result
    }

    private func loadChironContent() async throws -> [ChironContent] {
        let content: [ChironContent] = try await supabase
            .from("chiron_content")
            .select("*")
            .eq("is_active", value: true)
            .order("priority", ascending: false)
            .execute()
            .value

        return content
    }

    private func loadChallengeContent() async throws -> [String: ChallengeContent] {
        let content: [ChallengeContent] = try await supabase
            .from("challenge_content")
            .select("*")
            .eq("is_active", value: true)
            .execute()
            .value

        var result: [String: ChallengeContent] = [:]
        for item in content {
            result[item.challengeType] = item
        }
        return result
    }

    // MARK: - Accessors

    /// Get tour steps for a specific section
    func stepsForSection(_ section: TourSection) -> [TourContent] {
        tourSteps.filter { $0.section == section }
            .sorted { $0.stepOrder < $1.stepOrder }
    }

    /// Get all sections in order
    var sections: [TourSection] {
        // Return sections in order based on first step appearance
        var seen = Set<TourSection>()
        var result: [TourSection] = []
        for step in tourSteps.sorted(by: { $0.stepOrder < $1.stepOrder }) {
            if !seen.contains(step.section) {
                seen.insert(step.section)
                result.append(step.section)
            }
        }
        return result
    }

    /// Get total number of steps
    var totalSteps: Int {
        tourSteps.count
    }

    /// Get step at index
    func step(at index: Int) -> TourContent? {
        guard index >= 0 && index < tourSteps.count else { return nil }
        return tourSteps[index]
    }

    /// Get demo data by key
    func getDemoData(_ key: String) -> TourDemoData? {
        demoData[key]
    }

    /// Get Chiron message for a specific key
    func getChironMessage(_ key: String) -> ChironContent? {
        chironContent.first { $0.contentKey == key }
    }

    /// Get Chiron messages by type and category
    func getChironMessages(type: String, category: String? = nil) -> [ChironContent] {
        chironContent.filter { content in
            content.contentType == type &&
            (category == nil || content.category == category)
        }
    }

    /// Get challenge content by type
    func getChallengeContent(type: String) -> ChallengeContent? {
        challengeContent[type]
    }

    // MARK: - Fallback Content

    /// Fallback tour steps if database load fails
    private static let fallbackTourSteps: [TourContent] = [
        TourContent(
            id: "fallback-1",
            contentKey: "welcome.intro",
            section: .welcome,
            stepOrder: 1,
            chironMessage: "Welcome to WellPath! I'm Chiron, your longevity assistant.",
            chironSubtext: "I'll guide you through optimizing your healthspan.",
            screenType: .custom,
            highlightElements: nil,
            tapTarget: nil,
            tapDestination: nil,
            allowDeepNavigation: false,
            demoDataKey: nil,
            isActive: true
        ),
        TourContent(
            id: "fallback-2",
            contentKey: "wrapup.next_steps",
            section: .wrapup,
            stepOrder: 99,
            chironMessage: "You're ready to start your WellPath journey!",
            chironSubtext: "Set your baselines now, or explore on your own.",
            screenType: .custom,
            highlightElements: nil,
            tapTarget: nil,
            tapDestination: nil,
            allowDeepNavigation: false,
            demoDataKey: nil,
            isActive: true
        )
    ]
}
