//
//  LearnView.swift
//  WellPath
//
//  Main Learn section - Premium dark aesthetic with rich visuals
//  Inspired by Oura Explore + MyFitnessPal Learn
//

import SwiftUI

struct LearnView: View {
    @StateObject private var viewModel = LearnViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: LearnCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        // Category Pills
                        categoryPills

                        // Featured Spotlight
                        if !viewModel.featuredArticles.isEmpty {
                            spotlightSection
                        }

                        // Chiron AI Suggestions
                        if !viewModel.chironSuggestions.isEmpty {
                            chironSection
                        }

                        // Continue Learning
                        if !viewModel.inProgressArticles.isEmpty {
                            continueSection
                        }

                        // Explore by Pillar
                        pillarsSection

                        // Browse Categories
                        if selectedCategory == nil {
                            allCategoriesSection
                        } else {
                            filteredCategorySection
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.black)
            .navigationTitle("Learn")
            .searchable(text: $searchText, prompt: "Search articles")
            .task {
                await viewModel.loadAll()
            }
            .refreshable {
                await viewModel.loadAll()
            }
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text("Loading content...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Category Pills

    @ViewBuilder
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All category
                LearnCategoryPill(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                ForEach(LearnCategory.allCases, id: \.self) { category in
                    LearnCategoryPill(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Spotlight Section (Featured)

    @ViewBuilder
    private var spotlightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LearnSectionHeader(title: "Spotlight", icon: "sparkles")

            TabView {
                ForEach(viewModel.featuredArticles.prefix(5)) { article in
                    NavigationLink(destination: ArticleDetailView(article: article, viewModel: viewModel)) {
                        SpotlightCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 220)
        }
    }

    // MARK: - Chiron Section

    @ViewBuilder
    private var chironSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LearnSectionHeader(title: "Recommended for You", icon: "wand.and.stars")

            VStack(spacing: 12) {
                ForEach(viewModel.chironSuggestions.prefix(3)) { suggestion in
                    if let article = suggestion.article {
                        NavigationLink(destination: ArticleDetailView(article: article, viewModel: viewModel)) {
                            RecommendationCard(
                                article: article,
                                reason: suggestion.suggestionReason,
                                onDismiss: {
                                    Task {
                                        await viewModel.dismissSuggestion(suggestion.id)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Continue Learning Section

    @ViewBuilder
    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LearnSectionHeader(title: "Continue Learning", icon: "book.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.inProgressArticles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article, viewModel: viewModel)) {
                            ContinueCard(
                                article: article,
                                progress: viewModel.progress(for: article.articleId)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Pillars Section

    @ViewBuilder
    private var pillarsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LearnSectionHeader(title: "Explore by Pillar", icon: "square.grid.2x2.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(LearnPillar.allCases, id: \.self) { pillar in
                        NavigationLink(destination: PillarLearnView(pillar: pillar, viewModel: viewModel)) {
                            PillarCard(
                                pillar: pillar,
                                progress: viewModel.progress(forPillar: pillar.rawValue)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - All Categories Section

    @ViewBuilder
    private var allCategoriesSection: some View {
        VStack(spacing: 24) {
            // Quick Tips
            if let quickTips = viewModel.articlesByCategory[.quickTips], !quickTips.isEmpty {
                articleGridSection(title: "Quick Tips", icon: "bolt.fill", articles: quickTips)
            }

            // Longevity Research
            if let research = viewModel.articlesByCategory[.longevityResearch], !research.isEmpty {
                articleGridSection(title: "Longevity Research", icon: "leaf.fill", articles: research)
            }

            // Deep Dives
            if let deepDives = viewModel.articlesByCategory[.deepDives], !deepDives.isEmpty {
                articleGridSection(title: "Deep Dives", icon: "magnifyingglass", articles: deepDives)
            }

            // App Guides
            if let guides = viewModel.articlesByCategory[.appGuides], !guides.isEmpty {
                articleGridSection(title: "App Guides", icon: "iphone", articles: guides)
            }
        }
    }

    // MARK: - Filtered Category Section

    @ViewBuilder
    private var filteredCategorySection: some View {
        if let category = selectedCategory,
           let articles = viewModel.articlesByCategory[category], !articles.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                LearnSectionHeader(title: category.displayName, icon: category.icon)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(articles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article, viewModel: viewModel)) {
                            ArticleGridCard(article: article, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func articleGridSection(title: String, icon: String, articles: [LearnArticle]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                LearnSectionHeader(title: title, icon: icon)
                Spacer()
                Text("See all")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.trailing)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                ForEach(articles.prefix(4)) { article in
                    NavigationLink(destination: ArticleDetailView(article: article, viewModel: viewModel)) {
                        ArticleGridCard(article: article, viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Pillars Enum

enum LearnPillar: String, CaseIterable {
    case nutrition = "Healthful Nutrition"
    case movement = "Movement + Exercise"
    case sleep = "Restorative Sleep"
    case stress = "Stress Management"
    case cognitive = "Cognitive Health"
    case connection = "Connection + Purpose"
    case coreCare = "Core Care"
    case substances = "Substances"

    var displayName: String {
        switch self {
        case .nutrition: return "Nutrition"
        case .movement: return "Movement"
        case .sleep: return "Sleep"
        case .stress: return "Stress"
        case .cognitive: return "Cognitive"
        case .connection: return "Connection"
        case .coreCare: return "Core Care"
        case .substances: return "Substances"
        }
    }

    var icon: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .movement: return "figure.walk"
        case .sleep: return "bed.double.fill"
        case .stress: return "heart.fill"
        case .cognitive: return "brain.head.profile"
        case .connection: return "person.2.fill"
        case .coreCare: return "cross.fill"
        case .substances: return "pills.fill"
        }
    }

    var color: Color {
        switch self {
        case .nutrition: return Color(hex: "#8DD8FF") ?? .blue
        case .movement: return Color(hex: "#EB875D") ?? .orange
        case .sleep: return Color(hex: "#80CBC4") ?? .teal
        case .stress: return Color(hex: "#ED8D8D") ?? .pink
        case .cognitive: return Color(hex: "#C6B5FF") ?? .purple
        case .connection: return Color(hex: "#ADD399") ?? .green
        case .coreCare: return Color(hex: "#F4D284") ?? .yellow
        case .substances: return Color(hex: "#B39DDB") ?? .indigo
        }
    }
}

// MARK: - Learn Section Header

struct LearnSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
}

// MARK: - Learn Category Pill

struct LearnCategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.15))
                )
        }
    }
}

// MARK: - Spotlight Card (Featured)

struct SpotlightCard: View {
    let article: LearnArticle

    private var pillarColor: Color {
        if let pillar = LearnPillar.allCases.first(where: { $0.rawValue == article.pillar }) {
            return pillar.color
        }
        return .blue
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [pillarColor, pillarColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative icon
            Image(systemName: article.iconName ?? "book.fill")
                .font(.system(size: 100))
                .foregroundColor(.white.opacity(0.15))
                .offset(x: 120, y: -20)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Badge
                if let pillar = article.pillar {
                    Text(pillar)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                Text(article.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 12) {
                    Label("\(article.estimatedReadMinutes) min", systemImage: "clock")
                    Label("\(article.pointsValue) pts", systemImage: "star.fill")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
            }
            .padding(20)
        }
        .frame(height: 200)
        .padding(.horizontal)
    }
}

// MARK: - Recommendation Card (Chiron)

struct RecommendationCard: View {
    let article: LearnArticle
    let reason: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // AI Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(reason)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Continue Card

struct ContinueCard: View {
    let article: LearnArticle
    let progress: ArticleProgress?

    private var scrollProgress: Double {
        Double(progress?.scrollPercentage ?? 0) / 100.0
    }

    private var pillarColor: Color {
        if let pillar = LearnPillar.allCases.first(where: { $0.rawValue == article.pillar }) {
            return pillar.color
        }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress arc
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: scrollProgress)
                    .stroke(pillarColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(scrollProgress * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(article.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text("\(article.estimatedReadMinutes) min")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 130)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Pillar Card

struct PillarCard: View {
    let pillar: LearnPillar
    let progress: PillarLearnProgress?

    private var completionPercentage: Double {
        progress?.overallPercentage ?? 0
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Background glow
                Circle()
                    .fill(pillar.color.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .blur(radius: 10)

                // Progress ring
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: completionPercentage / 100)
                    .stroke(pillar.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Icon
                Image(systemName: pillar.icon)
                    .font(.title2)
                    .foregroundColor(pillar.color)
            }

            VStack(spacing: 4) {
                Text(pillar.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let progress = progress {
                    Text("\(progress.articlesCompleted)/\(progress.articlesTotal)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: 100)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Article Grid Card

struct ArticleGridCard: View {
    let article: LearnArticle
    @ObservedObject var viewModel: LearnViewModel

    private var pillarColor: Color {
        if let pillar = LearnPillar.allCases.first(where: { $0.rawValue == article.pillar }) {
            return pillar.color
        }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area with gradient
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [pillarColor.opacity(0.7), pillarColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)

                // Icon
                Image(systemName: article.iconName ?? "doc.text.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Completed badge
                if viewModel.isCompleted(article.articleId) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(article.estimatedReadMinutes) min read")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Preview

#Preview {
    LearnView()
        .preferredColorScheme(.dark)
}
