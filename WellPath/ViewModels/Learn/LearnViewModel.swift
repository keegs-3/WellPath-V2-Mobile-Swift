//
//  LearnViewModel.swift
//  WellPath
//
//  ViewModel for the Learn section
//  Manages articles, progress tracking, and Chiron suggestions
//

import Foundation
import Combine

@MainActor
class LearnViewModel: ObservableObject {
    // MARK: - Published Properties

    // Articles
    @Published var featuredArticles: [LearnArticle] = []
    @Published var articlesByPillar: [String: [LearnArticle]] = [:]
    @Published var articlesByCategory: [LearnCategory: [LearnArticle]] = [:]

    // Progress
    @Published var progressByArticle: [String: ArticleProgress] = [:]
    @Published var pillarProgress: [String: PillarLearnProgress] = [:]

    // Chiron Suggestions
    @Published var chironSuggestions: [ChironArticleSuggestion] = []

    // State
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Computed Properties

    /// Articles the user started but didn't complete
    var inProgressArticles: [LearnArticle] {
        let inProgressIds = progressByArticle
            .filter { $0.value.status == .inProgress }
            .map { $0.key }

        return allArticles.filter { inProgressIds.contains($0.articleId) }
    }

    /// All loaded articles flattened
    var allArticles: [LearnArticle] {
        var articles: [LearnArticle] = []
        articles.append(contentsOf: featuredArticles)
        for pillarArticles in articlesByPillar.values {
            articles.append(contentsOf: pillarArticles)
        }
        for categoryArticles in articlesByCategory.values {
            articles.append(contentsOf: categoryArticles)
        }
        // Deduplicate
        return Array(Set(articles.map { $0.articleId }).compactMap { id in
            articles.first { $0.articleId == id }
        })
    }

    /// Total points earned across all articles
    var totalPointsEarned: Int {
        progressByArticle.values.reduce(0) { $0 + $1.pointsEarned }
    }

    /// Overall completion percentage
    var overallCompletionPercentage: Double {
        guard !allArticles.isEmpty else { return 0 }
        let completed = progressByArticle.values.filter { $0.status == .completed }.count
        return Double(completed) / Double(allArticles.count) * 100
    }

    // MARK: - Private

    private let supabase = SupabaseManager.shared.client

    // MARK: - Load All Data

    func loadAll() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        isLoading = true
        error = nil

        // Load in parallel
        async let articlesTask: () = loadArticles()
        async let progressTask: () = loadProgress(patientId: userId)
        async let suggestionsTask: () = loadChironSuggestions(patientId: userId)

        await articlesTask
        await progressTask
        await suggestionsTask

        isLoading = false
    }

    // MARK: - Load Articles

    private func loadArticles() async {
        do {
            // Load all published articles
            let articles: [LearnArticle] = try await supabase
                .from("learn_articles")
                .select()
                .eq("is_published", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            print("[Learn] Loaded \(articles.count) articles")

            // Separate featured
            self.featuredArticles = articles.filter { $0.isFeatured }

            // Group by pillar
            var byPillar: [String: [LearnArticle]] = [:]
            for article in articles where article.pillar != nil {
                let pillar = article.pillar!
                byPillar[pillar, default: []].append(article)
            }
            self.articlesByPillar = byPillar

            // Group by category
            var byCategory: [LearnCategory: [LearnArticle]] = [:]
            for article in articles {
                if let category = LearnCategory(rawValue: article.category) {
                    byCategory[category, default: []].append(article)
                }
            }
            self.articlesByCategory = byCategory

        } catch {
            print("[Learn] Error loading articles: \(error)")
            self.error = error.localizedDescription
        }
    }

    // MARK: - Load Progress

    private func loadProgress(patientId: UUID) async {
        do {
            let progress: [ArticleProgress] = try await supabase
                .from("patient_article_progress")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .execute()
                .value

            var byArticle: [String: ArticleProgress] = [:]
            for p in progress {
                byArticle[p.articleId] = p
            }
            self.progressByArticle = byArticle

            print("[Learn] Loaded progress for \(progress.count) articles")

            // Calculate pillar progress
            await calculatePillarProgress()

        } catch {
            print("[Learn] Error loading progress: \(error)")
        }
    }

    private func calculatePillarProgress() async {
        var pillarStats: [String: PillarLearnProgress] = [:]

        for (pillar, articles) in articlesByPillar {
            let articlesTotal = articles.count
            let articlesCompleted = articles.filter { article in
                progressByArticle[article.articleId]?.status == .completed
            }.count

            // TODO: Calculate quizzes and challenges when implemented
            let quizzesTotal = 0
            let quizzesPassed = 0
            let challengesTotal = 0
            let challengesCompleted = 0

            let totalPoints = articles.reduce(0) { sum, article in
                sum + (progressByArticle[article.articleId]?.pointsEarned ?? 0)
            }

            pillarStats[pillar] = PillarLearnProgress(
                pillar: pillar,
                articlesCompleted: articlesCompleted,
                articlesTotal: articlesTotal,
                quizzesPassed: quizzesPassed,
                quizzesTotal: quizzesTotal,
                challengesCompleted: challengesCompleted,
                challengesTotal: challengesTotal,
                totalPoints: totalPoints
            )
        }

        self.pillarProgress = pillarStats
    }

    // MARK: - Load Chiron Suggestions

    private func loadChironSuggestions(patientId: UUID) async {
        do {
            // Load suggestions with joined article data
            let suggestions: [ChironArticleSuggestion] = try await supabase
                .from("chiron_article_suggestions")
                .select("*, learn_articles(*)")
                .eq("patient_id", value: patientId.uuidString)
                .eq("is_dismissed", value: false)
                .order("relevance_score", ascending: false)
                .limit(5)
                .execute()
                .value

            self.chironSuggestions = suggestions
            print("[Learn] Loaded \(suggestions.count) Chiron suggestions")

        } catch {
            print("[Learn] Error loading suggestions: \(error)")
        }
    }

    // MARK: - Article Actions

    /// Mark an article as started
    func startArticle(_ articleId: String) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        do {
            // Check if progress exists
            if progressByArticle[articleId] != nil {
                // Update existing
                try await supabase
                    .from("patient_article_progress")
                    .update([
                        "status": "in_progress",
                        "started_at": now
                    ])
                    .eq("patient_id", value: userId.uuidString)
                    .eq("article_id", value: articleId)
                    .execute()
            } else {
                // Insert new
                struct NewProgress: Encodable {
                    let patientId: String
                    let articleId: String
                    let status: String
                    let startedAt: String

                    enum CodingKeys: String, CodingKey {
                        case patientId = "patient_id"
                        case articleId = "article_id"
                        case status
                        case startedAt = "started_at"
                    }
                }

                try await supabase
                    .from("patient_article_progress")
                    .insert(NewProgress(
                        patientId: userId.uuidString,
                        articleId: articleId,
                        status: "in_progress",
                        startedAt: now
                    ))
                    .execute()
            }

            // Reload progress
            await loadProgress(patientId: userId)

        } catch {
            print("[Learn] Error starting article: \(error)")
        }
    }

    /// Mark an article as completed
    func completeArticle(_ articleId: String, pointsEarned: Int) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        do {
            struct CompleteUpdate: Encodable {
                let status: String
                let completedAt: String
                let pointsEarned: Int

                enum CodingKeys: String, CodingKey {
                    case status
                    case completedAt = "completed_at"
                    case pointsEarned = "points_earned"
                }
            }

            try await supabase
                .from("patient_article_progress")
                .update(CompleteUpdate(
                    status: "completed",
                    completedAt: now,
                    pointsEarned: pointsEarned
                ))
                .eq("patient_id", value: userId.uuidString)
                .eq("article_id", value: articleId)
                .execute()

            await loadProgress(patientId: userId)
            print("[Learn] Completed article: \(articleId), earned \(pointsEarned) points")

        } catch {
            print("[Learn] Error completing article: \(error)")
        }
    }

    /// Update reading progress (scroll percentage, time spent)
    func updateReadingProgress(_ articleId: String, scrollPercentage: Int, timeSpentSeconds: Int) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            struct ProgressUpdate: Encodable {
                let scrollPercentage: Int
                let timeSpentSeconds: Int

                enum CodingKeys: String, CodingKey {
                    case scrollPercentage = "scroll_percentage"
                    case timeSpentSeconds = "time_spent_seconds"
                }
            }

            try await supabase
                .from("patient_article_progress")
                .update(ProgressUpdate(
                    scrollPercentage: scrollPercentage,
                    timeSpentSeconds: timeSpentSeconds
                ))
                .eq("patient_id", value: userId.uuidString)
                .eq("article_id", value: articleId)
                .execute()

        } catch {
            print("[Learn] Error updating reading progress: \(error)")
        }
    }

    /// Toggle bookmark status
    func toggleBookmark(_ articleId: String) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let currentlyBookmarked = progressByArticle[articleId]?.isBookmarked ?? false

        do {
            // Ensure progress record exists first
            if progressByArticle[articleId] == nil {
                struct NewProgress: Encodable {
                    let patientId: String
                    let articleId: String
                    let isBookmarked: Bool

                    enum CodingKeys: String, CodingKey {
                        case patientId = "patient_id"
                        case articleId = "article_id"
                        case isBookmarked = "is_bookmarked"
                    }
                }

                try await supabase
                    .from("patient_article_progress")
                    .insert(NewProgress(
                        patientId: userId.uuidString,
                        articleId: articleId,
                        isBookmarked: true
                    ))
                    .execute()
            } else {
                struct BookmarkUpdate: Encodable {
                    let isBookmarked: Bool

                    enum CodingKeys: String, CodingKey {
                        case isBookmarked = "is_bookmarked"
                    }
                }

                try await supabase
                    .from("patient_article_progress")
                    .update(BookmarkUpdate(isBookmarked: !currentlyBookmarked))
                    .eq("patient_id", value: userId.uuidString)
                    .eq("article_id", value: articleId)
                    .execute()
            }

            await loadProgress(patientId: userId)

        } catch {
            print("[Learn] Error toggling bookmark: \(error)")
        }
    }

    /// Dismiss a Chiron suggestion
    func dismissSuggestion(_ suggestionId: UUID) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            try await supabase
                .from("chiron_article_suggestions")
                .update(["is_dismissed": true])
                .eq("id", value: suggestionId.uuidString)
                .execute()

            await loadChironSuggestions(patientId: userId)

        } catch {
            print("[Learn] Error dismissing suggestion: \(error)")
        }
    }

    // MARK: - Helpers

    /// Get articles for a specific pillar
    func articles(forPillar pillar: String) -> [LearnArticle] {
        articlesByPillar[pillar] ?? []
    }

    /// Get articles for a specific category
    func articles(forCategory category: LearnCategory) -> [LearnArticle] {
        articlesByCategory[category] ?? []
    }

    /// Get progress for a specific article
    func progress(for articleId: String) -> ArticleProgress? {
        progressByArticle[articleId]
    }

    /// Check if an article is bookmarked
    func isBookmarked(_ articleId: String) -> Bool {
        progressByArticle[articleId]?.isBookmarked ?? false
    }

    /// Check if an article is completed
    func isCompleted(_ articleId: String) -> Bool {
        progressByArticle[articleId]?.status == .completed
    }

    /// Get pillar progress
    func progress(forPillar pillar: String) -> PillarLearnProgress? {
        pillarProgress[pillar]
    }

    /// Get bookmarked articles
    var bookmarkedArticles: [LearnArticle] {
        let bookmarkedIds = progressByArticle
            .filter { $0.value.isBookmarked }
            .map { $0.key }

        return allArticles.filter { bookmarkedIds.contains($0.articleId) }
    }
}
