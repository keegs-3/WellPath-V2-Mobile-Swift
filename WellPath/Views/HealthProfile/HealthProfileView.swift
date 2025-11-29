//
//  HealthProfileView.swift
//  WellPath
//
//  Main container for the Health Profile (survey) experience.
//  Shows sections with category-based progress.
//

import SwiftUI

struct HealthProfileView: View {
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var showWelcomeSheet = false
    @State private var selectedSection: SurveySection?
    @State private var showReassessment = false

    // Optional dismiss handler for when presented modally
    var onDismiss: (() -> Void)?

    /// Check if we're in reassessment phase
    private var isInReassessmentPhase: Bool {
        viewModel.surveyState?.lifecyclePhase == .reassessment
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.sections.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.sections.isEmpty {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Health Profile")
            .toolbar {
                if let dismiss = onDismiss {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showWelcomeSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .task {
                await viewModel.loadData()
                // Show welcome sheet on first launch
                if !viewModel.hasSeenWelcome {
                    showWelcomeSheet = true
                }
            }
            .sheet(isPresented: $showWelcomeSheet) {
                HealthProfileWelcomeSheet {
                    viewModel.markWelcomeSeen()
                    showWelcomeSheet = false
                }
            }
            .fullScreenCover(isPresented: $showReassessment) {
                ReassessmentEntryView()
            }
            .navigationDestination(for: SurveySection.self) { section in
                CategoryListView(section: section, viewModel: viewModel)
            }
            .onAppear {
                // Auto-show reassessment if in that phase
                if isInReassessmentPhase && viewModel.isComplete {
                    showReassessment = true
                }
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Reassessment banner (if in reassessment phase)
                if isInReassessmentPhase {
                    reassessmentBanner
                }

                // Overall progress header
                overallProgressCard

                // Section list
                sectionList

                // Continue button
                if !viewModel.isComplete {
                    continueButton
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Reassessment Banner

    private var reassessmentBanner: some View {
        Button {
            showReassessment = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reassessment Time")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Review updates from your tracked data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overall Progress Card

    private var overallProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Health Profile")
                        .font(.headline)

                    if viewModel.isComplete {
                        Label("Complete", systemImage: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Text("\(viewModel.completedCategoryCount) of \(viewModel.totalCategoryCount) topics completed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: viewModel.overallProgress)
                        .stroke(viewModel.isComplete ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(viewModel.overallProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Section List

    private var sectionList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.sections) { section in
                NavigationLink(value: section) {
                    SectionCard(section: section)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            if let nextSection = viewModel.nextIncompleteSection {
                selectedSection = nextSection
            }
        } label: {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("Continue Where I Left Off")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your health profile...")
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
                    await viewModel.loadData()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Section Card

struct SectionCard: View {
    let section: SurveySection

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: section.iconName)
                .font(.title2)
                .foregroundColor(sectionColor)
                .frame(width: 44, height: 44)
                .background(sectionColor.opacity(0.15))
                .cornerRadius(10)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(section.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if section.categories.allSatisfy({ $0.isComplete }) && !section.categories.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                // Category progress dots
                HStack(spacing: 4) {
                    ForEach(section.categories) { category in
                        Circle()
                            .fill(category.isComplete ? sectionColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }

                    Spacer()

                    Text("\(section.completedCategoryCount) of \(section.categories.count) topics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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
    HealthProfileView()
}
