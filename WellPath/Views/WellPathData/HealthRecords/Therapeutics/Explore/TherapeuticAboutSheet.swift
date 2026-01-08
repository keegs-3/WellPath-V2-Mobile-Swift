//
//  TherapeuticAboutSheet.swift
//  WellPath
//
//  Education modal for a therapeutic from sample_therapeutic_types.
//  Uses the same pattern as MetricEducationModal but loads by therapeutic_id.
//

import SwiftUI

struct TherapeuticAboutSheet: View {
    let therapeutic: TherapeuticsBase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = MetricEducationContentLoader()
    @State private var showChatModal = false
    @State private var showAddWizard = false

    private var color: Color {
        therapeutic.type.color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loader.isLoading {
                        loadingView
                    } else if let content = loader.content {
                        educationContent(content)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for add button
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(therapeutic.therapeuticName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showChatModal = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(color)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                addButton
            }
            .sheet(isPresented: $showChatModal) {
                EducationQAModal(
                    viewId: "THERAPEUTIC_\(therapeutic.therapeuticType ?? "UNKNOWN")",
                    viewName: therapeutic.therapeuticName,
                    color: color
                )
            }
            .sheet(isPresented: $showAddWizard) {
                TherapeuticFormView(preselectedTherapeutic: therapeutic)
            }
        }
        .task {
            await loader.loadContent(forTherapeuticViewId: therapeutic.viewId)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Educational content for \(therapeutic.therapeuticName) will be available soon.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Education Content

    @ViewBuilder
    private func educationContent(_ content: MetricEducationContent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header card with therapeutic info
            headerCard

            // About Section (expandable)
            if content.aboutShort != nil || content.aboutFull != nil {
                ExpandableEducationSection(
                    title: "About",
                    icon: "info.circle.fill",
                    shortContent: content.aboutShort,
                    fullContent: content.aboutFull,
                    color: color
                )
            }

            // Longevity Impact (expandable)
            if content.longevityImpactShort != nil || content.longevityImpactFull != nil {
                ExpandableEducationSection(
                    title: "Longevity Impact",
                    icon: "heart.fill",
                    shortContent: content.longevityImpactShort,
                    fullContent: content.longevityImpactFull,
                    color: color
                )
            }

            // Quick Tips
            if let tips = content.quickTips, !tips.isEmpty {
                QuickTipsSection(
                    tips: tips,
                    color: color
                )
            }

            // Chiron Chat Prompt
            chatPromptSection
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: therapeutic.type.icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(therapeutic.therapeuticName)
                    .font(.headline)

                if let category = therapeutic.category {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(therapeutic.type.displayName)
                        .font(.caption)
                        .foregroundColor(color)

                    if !therapeutic.doseRangeDescription.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(therapeutic.doseRangeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Chiron Chat Prompt

    private var chatPromptSection: some View {
        Button {
            showChatModal = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Have questions?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("Ask your Personal Longevity Guide")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Button

    private var addButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(uiColor: .systemGroupedBackground).opacity(0), Color(uiColor: .systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            Button {
                showAddWizard = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to My Therapeutics")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

#Preview {
    TherapeuticAboutSheet(
        therapeutic: TherapeuticsBase(
            id: UUID(),
            therapeuticName: "NMN",
            therapeuticType: "SUP",
            category: "NAD+ Precursor",
            overview: "NMN is a precursor to NAD+",
            recommendationText: nil,
            therapeuticOperator: nil,
            therapeuticDoseMin: 500,
            therapeuticDoseMax: 1000,
            therapeuticUnit: "mg",
            therapeuticUnitSymbol: "mg",
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
    )
}
