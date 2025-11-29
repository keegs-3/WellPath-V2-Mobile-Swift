//
//  BiomarkerCategoryScreen.swift
//  WellPath
//
//  Shows biomarkers for a specific category with rich card data
//

import SwiftUI

enum BiomarkerCategory: String {
    case cardiovascular = "cardiovascular"
    case metabolism = "metabolism"
    case inflammation = "inflammation"
    case hormones = "hormones"
    case immune = "immune"

    var title: String {
        switch self {
        case .cardiovascular: return "Cardiovascular"
        case .metabolism: return "Metabolism"
        case .inflammation: return "Inflammation"
        case .hormones: return "Hormones"
        case .immune: return "Immune & Renal"
        }
    }

    var icon: String {
        switch self {
        case .cardiovascular: return "heart.fill"
        case .metabolism: return "flame.fill"
        case .inflammation: return "waveform.path.ecg"
        case .hormones: return "pills.fill"
        case .immune: return "shield.fill"
        }
    }

    // Database category patterns to match
    var categoryPatterns: [String] {
        switch self {
        case .cardiovascular:
            return ["Cardiovascular"]
        case .metabolism:
            return ["Metabolism"]
        case .inflammation:
            return ["Inflammation"]
        case .hormones:
            return ["Hormone"]
        case .immune:
            return ["Immune", "Renal"]
        }
    }
}

struct BiomarkerCategoryScreen: View {
    let category: BiomarkerCategory
    let pillar: String
    let color: Color

    @StateObject private var viewModel = MetricsViewModel()

    // Filter cards by category
    private var categoryCards: [BiomarkerCardData] {
        viewModel.biomarkerCards.filter { card in
            guard let cardCategory = card.category else { return false }
            return category.categoryPatterns.contains { pattern in
                cardCategory.contains(pattern)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading biomarkers...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if categoryCards.isEmpty {
                    emptyState
                } else {
                    biomarkersList
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                Color(uiColor: .systemGroupedBackground)

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: category.icon)
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
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadBiomarkers()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No \(category.title.lowercased()) biomarkers")
                .font(.headline)
            Text("Lab results will appear here when available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    private var biomarkersList: some View {
        ForEach(categoryCards) { card in
            NavigationLink(destination: BiomarkerDetailView(
                name: card.name,
                value: card.value,
                status: card.status,
                optimalRange: card.optimalRange,
                trend: card.trend,
                isBiometric: false
            )) {
                BiomarkerCard(
                    name: card.name,
                    value: card.value,
                    numericValue: card.numericValue,
                    status: card.status,
                    rangeName: card.rangeName,
                    optimalRange: card.optimalRange,
                    trend: card.trend,
                    trendData: card.trendData,
                    statusColor: getStatusColor(card.status),
                    isBiometric: false,
                    rangeSegments: card.rangeSegments
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func getStatusColor(_ status: String) -> Color {
        switch status {
        case "Out-of-Range": return .red
        case "In-Range": return .blue
        case "Optimal": return .green
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        BiomarkerCategoryScreen(
            category: .cardiovascular,
            pillar: "Biomarkers",
            color: Color(hex: "#BD8FF0") ?? .purple
        )
    }
}
