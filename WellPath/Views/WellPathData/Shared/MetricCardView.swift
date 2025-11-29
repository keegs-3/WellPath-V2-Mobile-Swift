//
//  MetricCardView.swift
//  WellPath
//
//  Reusable card component for metric screens
//  All cards are tappable and navigate to full view (full-screen push navigation)
//

import SwiftUI

struct MetricCardView<Content: View, FullScreenContent: View>: View {
    let title: String
    let color: Color
    let content: Content
    let fullScreenContent: FullScreenContent
    let metricId: String?
    let pillar: String?

    init(
        title: String,
        color: Color,
        metricId: String? = nil,
        pillar: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder fullScreen: () -> FullScreenContent
    ) {
        self.title = title
        self.color = color
        self.metricId = metricId
        self.pillar = pillar
        self.content = content()
        self.fullScreenContent = fullScreen()
    }

    var body: some View {
        NavigationLink {
            fullScreenContent
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Card header with title, favorite star, and chevron
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    // Favorite star (if metricId provided)
                    if let metricId = metricId {
                        MetricFavoriteStar(
                            metricId: metricId,
                            displayName: title,
                            pillar: pillar ?? "",
                            color: color
                        )
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }

                // Card content (mini preview)
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Metric Favorite Star (inline, small)

struct MetricFavoriteStar: View {
    let metricId: String
    let displayName: String
    let pillar: String
    let color: Color

    @ObservedObject private var favoritesService = FavoritesService.shared
    @State private var isAnimating = false

    private var isFavorite: Bool {
        favoritesService.isFavorite(type: .metric, id: metricId)
    }

    var body: some View {
        Button {
            isAnimating = true
            Task {
                await favoritesService.toggleFavorite(
                    type: .metric,
                    id: metricId,
                    displayName: displayName,
                    pillar: pillar
                )
                isAnimating = false
            }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 14))
                .foregroundColor(isFavorite ? .yellow : .secondary.opacity(0.5))
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Convenience initializer for cards without full-screen expansion (rare case)
extension MetricCardView where FullScreenContent == EmptyView {
    init(
        title: String,
        color: Color,
        metricId: String? = nil,
        pillar: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.color = color
        self.metricId = metricId
        self.pillar = pillar
        self.content = content()
        self.fullScreenContent = EmptyView()
    }
}

// MARK: - Metric Screen Background ViewModifier

/// Adds the standard gradient background with watermark icon for metric detail screens
struct MetricScreenBackground: ViewModifier {
    let color: Color
    let icon: String

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base background that extends to bottom
                    Color(uiColor: .systemGroupedBackground)

                    // Gradient overlay at top
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)
                        Spacer()
                    }

                    // Watermark icon
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: icon)
                                .font(.system(size: 200))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .rotationEffect(.degrees(-15))
                                .offset(x: 50, y: -50)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    /// Applies the standard metric screen gradient background with icon watermark
    func metricScreenBackground(color: Color, icon: String) -> some View {
        modifier(MetricScreenBackground(color: color, icon: icon))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            MetricCardView(
                title: "Protein Amount",
                color: .green
            ) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("85g")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Weekly Avg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("92g")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            } fullScreen: {
                Text("Full chart view")
            }

            MetricCardView(
                title: "Protein Timing",
                color: .green
            ) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Top Meal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Dinner")
                            .font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("42%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("of daily intake")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } fullScreen: {
                Text("Full timing view")
            }

            MetricCardView(
                title: "Protein Type",
                color: .green
            ) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Quality Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("78")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            } fullScreen: {
                Text("Full type view")
            }
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
