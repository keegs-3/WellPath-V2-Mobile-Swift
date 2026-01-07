//
//  ArticleDetailView.swift
//  WellPath
//
//  Full article view with markdown rendering - Premium dark aesthetic
//

import SwiftUI

struct ArticleDetailView: View {
    let article: LearnArticle
    @ObservedObject var viewModel: LearnViewModel

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var hasMarkedStarted = false
    @State private var startTime = Date()
    @State private var showingReferences = false

    @Environment(\.dismiss) private var dismiss

    private var pillarColor: Color {
        if let pillar = LearnPillar.allCases.first(where: { $0.rawValue == article.pillar }) {
            return pillar.color
        }
        return .blue
    }

    private var scrollPercentage: Int {
        guard contentHeight > 0 else { return 0 }
        let percentage = min(100, max(0, (scrollOffset / contentHeight) * 100))
        return Int(percentage)
    }

    private var isCompleted: Bool {
        viewModel.isCompleted(article.articleId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Header
                heroHeader

                // Content
                markdownContent

                // Key Concepts
                if let concepts = article.keyConcepts, !concepts.isEmpty {
                    keyConceptsSection(concepts)
                }

                // Evidence References
                if let refs = article.evidenceReferences, !refs.isEmpty {
                    referencesSection(refs)
                }

                // Related Metrics
                if let metricIds = article.relatedMetricIds, !metricIds.isEmpty {
                    relatedMetricsSection(metricIds)
                }

                // Complete button
                if !isCompleted {
                    completeButton
                } else {
                    completedBanner
                }

                Spacer(minLength: 40)
            }
            .padding()
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ArticleScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                        .preference(key: ArticleContentHeightPreferenceKey.self, value: geometry.size.height)
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ArticleScrollOffsetPreferenceKey.self) { value in
            scrollOffset = -value
        }
        .onPreferenceChange(ArticleContentHeightPreferenceKey.self) { value in
            contentHeight = value
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.toggleBookmark(article.articleId)
                    }
                } label: {
                    Image(systemName: viewModel.isBookmarked(article.articleId) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(pillarColor)
                }
            }
        }
        .task {
            if !hasMarkedStarted && !isCompleted {
                await viewModel.startArticle(article.articleId)
                hasMarkedStarted = true
                startTime = Date()
            }
        }
        .onDisappear {
            let timeSpent = Int(Date().timeIntervalSince(startTime))
            Task {
                await viewModel.updateReadingProgress(
                    article.articleId,
                    scrollPercentage: scrollPercentage,
                    timeSpentSeconds: timeSpent
                )
            }
        }
        .sheet(isPresented: $showingReferences) {
            ReferencesListView(references: article.evidenceReferences ?? [], color: pillarColor)
        }
    }

    // MARK: - Hero Header

    @ViewBuilder
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [pillarColor, pillarColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)

            // Decorative icon
            Image(systemName: article.iconName ?? "book.fill")
                .font(.system(size: 120))
                .foregroundColor(.white.opacity(0.15))
                .offset(x: 140, y: 20)

            // Content overlay
            VStack(alignment: .leading, spacing: 10) {
                // Badges
                HStack(spacing: 8) {
                    if let pillar = article.pillar {
                        Text(pillar)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    if let articleType = article.articleType {
                        Text(articleType.capitalized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.2), in: Capsule())
                    }
                }

                Spacer()

                // Title
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Subtitle
                if let subtitle = article.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }

                // Meta info
                HStack(spacing: 16) {
                    Label("\(article.estimatedReadMinutes) min", systemImage: "clock")
                    Label("\(article.pointsValue) pts", systemImage: "star.fill")
                    Label(article.difficultyLevel.capitalized, systemImage: "chart.bar")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(20)
        }
    }

    // MARK: - Markdown Content

    @ViewBuilder
    private var markdownContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let attributed = try? AttributedString(markdown: article.contentMarkdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attributed)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(8)
            } else {
                Text(article.contentMarkdown)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Key Concepts Section

    @ViewBuilder
    private func keyConceptsSection(_ concepts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(pillarColor)
                Text("Key Concepts")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            ForEach(Array(concepts.enumerated()), id: \.offset) { _, concept in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(pillarColor)
                        .font(.subheadline)

                    Text(concept)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(pillarColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - References Section

    @ViewBuilder
    private func referencesSection(_ refs: [EvidenceReference]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(pillarColor)
                    Text("Evidence & References")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                Button {
                    showingReferences = true
                } label: {
                    Text("View All (\(refs.count))")
                        .font(.caption)
                        .foregroundColor(pillarColor)
                }
            }

            ForEach(refs.prefix(2)) { ref in
                ReferenceRow(reference: ref, color: pillarColor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Related Metrics Section

    @ViewBuilder
    private func relatedMetricsSection(_ metricIds: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(pillarColor)
                Text("Related Metrics")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Track your progress in the app")
                .font(.caption)
                .foregroundColor(.gray)

            ForEach(metricIds, id: \.self) { metricId in
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(pillarColor)
                    Text(metricId.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Complete Button

    @ViewBuilder
    private var completeButton: some View {
        Button {
            Task {
                await viewModel.completeArticle(article.articleId, pointsEarned: article.pointsValue)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                Text("Mark as Complete")
                Text("+\(article.pointsValue) pts")
                    .fontWeight(.bold)
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [pillarColor, pillarColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
    }

    // MARK: - Completed Banner

    @ViewBuilder
    private var completedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("You've finished this article!")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Reference Row

struct ReferenceRow: View {
    let reference: EvidenceReference
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reference.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)

            HStack(spacing: 10) {
                if let year = reference.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                if let pmid = reference.pmid {
                    Text("PMID: \(pmid)")
                        .font(.caption2)
                        .foregroundColor(color)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - References List View

struct ReferencesListView: View {
    let references: [EvidenceReference]
    let color: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(references) { ref in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(ref.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            if let summary = ref.summary {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            HStack(spacing: 14) {
                                if let year = ref.year {
                                    Label(String(year), systemImage: "calendar")
                                }

                                if let pmid = ref.pmid {
                                    Label("PMID: \(pmid)", systemImage: "doc.text")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.gray)

                            if let url = ref.url, let link = URL(string: url) {
                                Link(destination: link) {
                                    Label("View Source", systemImage: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundColor(color)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("References")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(color)
                }
            }
        }
    }
}

// MARK: - Preference Keys

struct ArticleScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ArticleContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(
            article: LearnArticle(
                articleId: "test-article",
                pillar: "Healthful Nutrition",
                category: "pillar_content",
                articleType: "about",
                userType: .all,
                title: "Understanding Protein",
                subtitle: "Why protein matters for your health",
                contentMarkdown: """
                Protein is one of the three macronutrients essential for human health.

                ## Why Protein Matters

                Your body uses protein for:
                - Building and repairing tissues
                - Making enzymes and hormones
                - Supporting immune function

                ## How Much Do You Need?

                Most adults need about **0.8 grams per kilogram** of body weight daily.
                """,
                keyConcepts: [
                    "Protein is essential for tissue repair",
                    "Spread intake across meals",
                    "Vary your protein sources"
                ],
                evidenceReferences: [
                    EvidenceReference(pmid: "12345678", title: "Protein Requirements in Adults", summary: "Meta-analysis of protein intake studies", year: 2023, url: nil)
                ],
                estimatedReadMinutes: 5,
                difficultyLevel: "beginner",
                iconName: "fork.knife",
                heroImageUrl: nil,
                relatedMetricIds: ["protein_grams"],
                aiContext: nil,
                pointsValue: 10,
                displayOrder: 1,
                isFeatured: true,
                isPublished: true
            ),
            viewModel: LearnViewModel()
        )
    }
    .preferredColorScheme(.dark)
}
