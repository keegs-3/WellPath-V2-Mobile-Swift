//
//  PillarLearnView.swift
//  WellPath
//
//  View for educational content within a specific health pillar
//  Premium dark aesthetic with gradient accents
//

import SwiftUI

struct PillarLearnView: View {
    let pillar: LearnPillar
    @ObservedObject var viewModel: LearnViewModel

    private var pillarArticles: [LearnArticle] {
        viewModel.articles(forPillar: pillar.rawValue)
    }

    private var progress: PillarLearnProgress? {
        viewModel.progress(forPillar: pillar.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero progress header
                progressHeader

                // Articles by type
                if !aboutArticles.isEmpty {
                    articleSection(type: "About", icon: "info.circle.fill", articles: aboutArticles)
                }

                if !whyArticles.isEmpty {
                    articleSection(type: "Why It Matters", icon: "heart.fill", articles: whyArticles)
                }

                if !howArticles.isEmpty {
                    articleSection(type: "How To", icon: "list.bullet.clipboard.fill", articles: howArticles)
                }

                if !challengeArticles.isEmpty {
                    articleSection(type: "Challenges", icon: "flag.fill", articles: challengeArticles)
                }

                if !otherArticles.isEmpty {
                    articleSection(type: "More Articles", icon: "doc.text.fill", articles: otherArticles)
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .wellPathAmbientBackground()
        .navigationTitle(pillar.displayName)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Article Filtering

    private var aboutArticles: [LearnArticle] {
        pillarArticles.filter { $0.articleType == "about" }
    }

    private var whyArticles: [LearnArticle] {
        pillarArticles.filter { $0.articleType == "why" }
    }

    private var howArticles: [LearnArticle] {
        pillarArticles.filter { $0.articleType == "how" }
    }

    private var challengeArticles: [LearnArticle] {
        pillarArticles.filter { $0.articleType == "challenges" }
    }

    private var otherArticles: [LearnArticle] {
        pillarArticles.filter { article in
            let knownTypes = ["about", "why", "how", "challenges"]
            return article.articleType == nil || !knownTypes.contains(article.articleType ?? "")
        }
    }

    // MARK: - Progress Header

    @ViewBuilder
    private var progressHeader: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [pillar.color.opacity(0.4), pillar.color.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 24) {
                // Progress ring
                ZStack {
                    // Glow
                    Circle()
                        .fill(pillar.color.opacity(0.3))
                        .frame(width: 110, height: 110)
                        .blur(radius: 15)

                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 10)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: (progress?.overallPercentage ?? 0) / 100)
                        .stroke(pillar.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(progress?.overallPercentage ?? 0))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Complete")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // Stats
                VStack(alignment: .leading, spacing: 14) {
                    statRow(
                        icon: "doc.text.fill",
                        value: "\(progress?.articlesCompleted ?? 0)/\(progress?.articlesTotal ?? 0)",
                        label: "Articles"
                    )

                    statRow(
                        icon: "checkmark.seal.fill",
                        value: "\(progress?.quizzesPassed ?? 0)/\(progress?.quizzesTotal ?? 0)",
                        label: "Quizzes"
                    )

                    statRow(
                        icon: "star.fill",
                        value: "\(progress?.totalPoints ?? 0)",
                        label: "Points"
                    )
                }
            }
            .padding(24)
        }
    }

    private func statRow(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(pillar.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Article Section

    @ViewBuilder
    private func articleSection(type: String, icon: String, articles: [LearnArticle]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(pillar.color)
                Text(type)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Article cards
            ForEach(articles) { article in
                NavigationLink(destination: ArticleDetailView(article: article, viewModel: viewModel)) {
                    PillarArticleRow(
                        article: article,
                        color: pillar.color,
                        isCompleted: viewModel.isCompleted(article.articleId),
                        isBookmarked: viewModel.isBookmarked(article.articleId)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Pillar Article Row

struct PillarArticleRow: View {
    let article: LearnArticle
    let color: Color
    let isCompleted: Bool
    let isBookmarked: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(isCompleted ? color : Color.white.opacity(0.1))
                    .frame(width: 46, height: 46)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else if let iconName = article.iconName {
                    Image(systemName: iconName)
                        .font(.subheadline)
                        .foregroundColor(color)
                } else {
                    Image(systemName: "doc.text")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundColor(color)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(article.estimatedReadMinutes) min", systemImage: "clock")
                    Label(article.difficultyLevel.capitalized, systemImage: "chart.bar")
                    Label("\(article.pointsValue) pts", systemImage: "star.fill")
                }
                .font(.caption2)
                .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isCompleted ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        PillarLearnView(
            pillar: .nutrition,
            viewModel: LearnViewModel()
        )
    }
    .preferredColorScheme(.dark)
}
