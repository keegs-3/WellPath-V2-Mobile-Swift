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
    let cardId: String?      // For favorites: links to display_view_cards
    let sectionId: String?   // For favorites: links to display_category_sections
    let itemType: FavoriteItemType  // For favorites: metric, biomarker, biometric

    init(
        title: String,
        color: Color,
        metricId: String? = nil,
        pillar: String? = nil,
        cardId: String? = nil,
        sectionId: String? = nil,
        itemType: FavoriteItemType = .metric,
        @ViewBuilder content: () -> Content,
        @ViewBuilder fullScreen: () -> FullScreenContent
    ) {
        self.title = title
        self.color = color
        self.metricId = metricId
        self.pillar = pillar
        self.cardId = cardId
        self.sectionId = sectionId
        self.itemType = itemType
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
                        FavoriteButton(
                            itemType: itemType,
                            itemId: metricId,
                            displayName: title,
                            pillar: pillar ?? "",
                            cardId: cardId,
                            sectionId: sectionId,
                            size: .compact
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.25),
                                color.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
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
        cardId: String? = nil,
        sectionId: String? = nil,
        itemType: FavoriteItemType = .metric,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.color = color
        self.metricId = metricId
        self.pillar = pillar
        self.cardId = cardId
        self.sectionId = sectionId
        self.itemType = itemType
        self.content = content()
        self.fullScreenContent = EmptyView()
    }
}

// MARK: - Metric Screen Background ViewModifier

/// Adds the standard ambient glow background for metric detail screens (Oura-style)
/// Single top-center glow with the section's color
struct MetricScreenBackground: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        let screenHeight = UIScreen.main.bounds.height

        content
            .background(
                ZStack {
                    // Rich charcoal base
                    WellPathColors.backgroundBase

                    // Single top-center ambient glow
                    RadialGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.20),
                            color.opacity(0.10),
                            color.opacity(0.04),
                            Color.clear
                        ]),
                        center: UnitPoint(x: 0.5, y: 0.0),
                        startRadius: 0,
                        endRadius: screenHeight * 0.6
                    )
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    /// Applies the standard metric screen ambient glow background (Oura-style)
    func metricScreenBackground(color: Color) -> some View {
        modifier(MetricScreenBackground(color: color))
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
