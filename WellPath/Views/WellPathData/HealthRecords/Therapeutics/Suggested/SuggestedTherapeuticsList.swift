//
//  SuggestedTherapeuticsList.swift
//  WellPath
//
//  List view showing therapeutic suggestions with rationale.
//  Each suggestion shows why it's recommended based on patient scores
//  and provides quick add functionality.
//

import SwiftUI

struct SuggestedTherapeuticsList: View {
    @ObservedObject var viewModel: SuggestedTherapeuticsViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.suggestions.isEmpty {
                        emptyStateView
                    } else {
                        suggestionsList
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Suggested Therapeutics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading suggestions...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("No Suggestions Right Now")
                .font(.headline)

            Text("Your scores and biomarkers look good! We'll notify you if we identify any therapeutic opportunities.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        VStack(spacing: 12) {
            // Header with count
            HStack {
                Text("\(viewModel.suggestionCount) Suggestions")
                    .font(.headline)
                Spacer()
                Text("Based on your health data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)

            // Grouped by type
            ForEach(TherapeuticType.primaryCases, id: \.self) { type in
                if let suggestions = viewModel.suggestionsByType[type], !suggestions.isEmpty {
                    typeSection(type: type, suggestions: suggestions)
                }
            }
        }
    }

    // MARK: - Type Section

    @ViewBuilder
    private func typeSection(type: TherapeuticType, suggestions: [SuggestedTherapeutic]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                Text(type.displayNamePlural)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(suggestions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // Suggestion cards
            ForEach(suggestions, id: \.therapeuticName) { suggestion in
                SuggestionCard(suggestion: suggestion, color: type.color)
            }
        }
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let suggestion: SuggestedTherapeutic
    let color: Color

    @State private var showingAboutSheet = false
    @State private var showingAddWizard = false
    @State private var isExpanded = false
    @StateObject private var therapeuticsVM = TherapeuticsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: suggestion.type.icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                // Name and category
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.therapeuticName)
                        .font(.headline)

                    if let category = suggestion.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Relevance indicator
                relevanceIndicator
            }

            // Triggering score badge
            if let score = suggestion.triggeringScore {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text("\(suggestion.triggeringScoreDisplay): \(suggestion.scoreStatusDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let value = suggestion.scoreValue {
                        Text("(\(Int(value)))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Rationale (expandable)
            if let rationale = suggestion.rationale, !rationale.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Why this is suggested")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        Text(rationale)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    showingAboutSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Learn More")
                    }
                    .font(.subheadline)
                    .foregroundColor(color)
                }

                Spacer()

                Button {
                    showingAddWizard = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(color)
                    .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingAboutSheet) {
            therapeuticAboutSheet
        }
        .sheet(isPresented: $showingAddWizard) {
            AddTherapeuticWizard(preselectedTherapeutic: createTherapeuticsBase())
        }
        .task {
            await therapeuticsVM.loadTherapeuticsBase()
        }
    }

    // MARK: - Relevance Indicator

    private var relevanceIndicator: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= (suggestion.relevance ?? 0) ? color : Color.gray.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - About Sheet

    @ViewBuilder
    private var therapeuticAboutSheet: some View {
        if let base = findTherapeuticsBase() {
            TherapeuticAboutSheet(therapeutic: base)
        } else {
            // Fallback if not found in loaded base
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: suggestion.type.icon)
                        .font(.system(size: 48))
                        .foregroundColor(color)

                    Text(suggestion.therapeuticName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let category = suggestion.category {
                        Text(category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let rationale = suggestion.rationale {
                        Text(rationale)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle(suggestion.therapeuticName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showingAboutSheet = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func findTherapeuticsBase() -> TherapeuticsBase? {
        therapeuticsVM.therapeuticsBase.first { $0.therapeuticName == suggestion.therapeuticName }
    }

    private func createTherapeuticsBase() -> TherapeuticsBase? {
        // Try to find from loaded base first
        if let base = findTherapeuticsBase() {
            return base
        }

        // Create a minimal base for the wizard
        return TherapeuticsBase(
            id: UUID(),
            therapeuticName: suggestion.therapeuticName,
            therapeuticType: suggestion.therapeuticType,
            category: suggestion.category,
            overview: suggestion.rationale,
            recommendationText: nil,
            therapeuticOperator: nil,
            therapeuticDoseMin: nil,
            therapeuticDoseMax: nil,
            therapeuticUnit: nil,
            therapeuticUnitSymbol: nil,
            therapeuticDoseRollup: nil,
            therapeuticFrequencyDays: nil,
            therapeuticTiming: nil,
            linkedEvidence: nil,
            ageMin: nil,
            ageMax: nil,
            gender: nil,
            isActive: true,
            createdAt: nil,
            updatedAt: nil,
            mechanismOfAction: nil,
            benefits: nil,
            risksWarnings: nil,
            contraindications: nil,
            dosingGuidance: nil,
            timingGuidance: nil,
            longevityRelevance: nil,
            researchSummary: nil,
            commonBrands: nil,
            aiContext: nil
        )
    }
}

// MARK: - Preview

#Preview {
    SuggestedTherapeuticsList(
        viewModel: SuggestedTherapeuticsViewModel(),
        color: Color(hex: "F4D284") ?? .yellow
    )
}
