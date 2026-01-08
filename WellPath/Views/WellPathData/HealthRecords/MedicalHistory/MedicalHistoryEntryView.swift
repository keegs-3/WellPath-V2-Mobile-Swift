//
//  MedicalHistoryEntryView.swift
//  WellPath
//
//  Entry point for Medical History section.
//  Shows Personal History and Family History cards.
//  Tracks completion status for gating Screenings.
//

import SwiftUI

struct MedicalHistoryEntryView: View {
    var color: Color = .red

    @StateObject private var viewModel = MedicalHistoryViewModel()
    @State private var showPersonalHistory = false
    @State private var showFamilyHistory = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Completion Status Card
                if !viewModel.isFullyComplete {
                    completionStatusCard
                }

                // Personal History Card
                NavigationLink(destination: PersonalHistoryView(viewModel: viewModel, color: color)) {
                    HistorySectionCard(
                        title: "Personal History",
                        subtitle: viewModel.isPersonalComplete
                            ? "\(viewModel.personalConditionCount) conditions recorded"
                            : "Add your own medical conditions",
                        icon: "person.fill",
                        color: color,
                        isComplete: viewModel.isPersonalComplete,
                        conditionCount: viewModel.personalConditionCount
                    )
                }
                .buttonStyle(.plain)

                // Family History Card
                NavigationLink(destination: FamilyHistoryView(viewModel: viewModel, color: color)) {
                    HistorySectionCard(
                        title: "Family History",
                        subtitle: viewModel.isFamilyComplete
                            ? "\(viewModel.familyConditionCount) conditions recorded"
                            : "Add conditions from family members",
                        icon: "person.3.fill",
                        color: color,
                        isComplete: viewModel.isFamilyComplete,
                        conditionCount: viewModel.familyConditionCount
                    )
                }
                .buttonStyle(.plain)

                // Information Card
                infoCard
            }
            .padding()
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Medical History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .task {
            await viewModel.loadAll()
        }
    }

    // MARK: - Completion Status Card

    private var completionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "checklist")
                        .font(.title3)
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Complete Your Medical History")
                        .font(.headline)

                    Text("Required before setting up screenings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Progress indicators
            HStack(spacing: 16) {
                StatusChip(
                    label: "Personal",
                    isComplete: viewModel.isPersonalComplete,
                    color: color
                )

                StatusChip(
                    label: "Family",
                    isComplete: viewModel.isFamilyComplete,
                    color: color
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Why we ask")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("Your medical history helps personalize your health recommendations and determine appropriate screening schedules. Family history is especially important for assessing your risk for conditions like cancer and heart disease.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - History Section Card

struct HistorySectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isComplete: Bool
    let conditionCount: Int

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Count badge if has conditions
            if conditionCount > 0 {
                Text("\(conditionCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)
            }

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let label: String
    let isComplete: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isComplete ? .green : .secondary)

            Text(label)
                .font(.caption)
                .foregroundColor(isComplete ? .primary : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isComplete ? Color.green.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
        )
    }
}

#Preview {
    NavigationStack {
        MedicalHistoryEntryView()
    }
}
