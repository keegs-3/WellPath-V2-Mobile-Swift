//
//  QuestionnaireView.swift
//  WellPath
//
//  Created on 2025-11-27
//

import SwiftUI

struct QuestionnaireView: View {
    @StateObject private var viewModel = SurveyViewModel()
    @State private var selectedSectionIndex: Int = 0
    @State private var showingSectionDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.sections.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.sections.isEmpty {
                    errorView(error)
                } else {
                    switch viewModel.mode {
                    case .onboarding:
                        onboardingModeView
                    case .management:
                        managementModeView
                    }
                }
            }
            .navigationTitle("Questionnaire")
            .task {
                await viewModel.loadInitialData()
            }
        }
    }

    // MARK: - Onboarding Mode (< 80% complete)

    private var onboardingModeView: some View {
        VStack(spacing: 0) {
            // Progress header
            overallProgressHeader

            // Section carousel
            sectionCarousel

            // Start/Continue button
            VStack(spacing: 16) {
                if let section = viewModel.getFirstUnansweredSection() {
                    NavigationLink {
                        SurveyOnboardingView(viewModel: viewModel, startingSection: section)
                    } label: {
                        HStack {
                            Image(systemName: viewModel.answeredQuestions == 0 ? "play.fill" : "arrow.right")
                            Text(viewModel.answeredQuestions == 0 ? "Start Questionnaire" : "Continue")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Text("\(viewModel.answeredQuestions) of \(viewModel.totalQuestions) questions answered")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Management Mode (>= 80% complete)

    private var managementModeView: some View {
        VStack(spacing: 0) {
            // Completion badge
            completionBadge

            // Section carousel
            sectionCarousel

            // Section detail button
            if !viewModel.sections.isEmpty {
                NavigationLink {
                    SurveySectionDetailView(
                        viewModel: viewModel,
                        section: viewModel.sections[min(selectedSectionIndex, viewModel.sections.count - 1)]
                    )
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View All Questions")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Shared Components

    private var overallProgressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Overall Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(viewModel.overallCompletionPercentage * 100))%")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            ProgressView(value: viewModel.overallCompletionPercentage)
                .tint(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var completionBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Questionnaire Complete")
                    .font(.headline)
                Text("You can review or update your answers anytime")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding()
    }

    private var sectionCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sections")
                .font(.headline)
                .padding(.horizontal)

            TabView(selection: $selectedSectionIndex) {
                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                    SectionCarouselCard(section: section, viewModel: viewModel)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 220)

            // Page indicator dots
            HStack(spacing: 6) {
                ForEach(0..<viewModel.sections.count, id: \.self) { index in
                    Circle()
                        .fill(index == selectedSectionIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading questionnaire...")
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await viewModel.loadInitialData()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Section Carousel Card

struct SectionCarouselCard: View {
    let section: SurveySection
    @ObservedObject var viewModel: SurveyViewModel

    var body: some View {
        NavigationLink {
            SurveySectionDetailView(viewModel: viewModel, section: section)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: section.iconName)
                        .font(.title2)
                        .foregroundColor(sectionColor)

                    Text(section.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    if section.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: section.completionPercentage)
                        .tint(sectionColor)

                    HStack {
                        Text("\(section.answeredCount)/\(section.questionCount) questions")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(section.completionPercentage * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(sectionColor)
                    }
                }

                Spacer()

                // Footer
                HStack {
                    Label("\(section.estimatedMinutes) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Tap to review")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private var sectionColor: Color {
        switch section.themeColor {
        case "green": return .green
        case "orange": return .orange
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "red": return .red
        default: return .blue
        }
    }
}

#Preview {
    QuestionnaireView()
}
