//
//  ProposedChangesView.swift
//  WellPath
//
//  Shows proposed survey response changes based on tracked data.
//  Users can accept or keep current responses for each change.
//

import SwiftUI

struct ProposedChangesView: View {
    @ObservedObject var viewModel: ReassessmentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.proposedChanges.isEmpty {
                    emptyView
                } else {
                    contentView
                }
            }
            .navigationTitle("Suggested Updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Accept All") {
                        Task {
                            await viewModel.acceptAllChanges()
                        }
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header explanation
                headerCard

                // Changes grouped by section
                ForEach(Array(viewModel.proposedChangesBySection.keys.sorted()), id: \.self) { sectionId in
                    if let changes = viewModel.proposedChangesBySection[sectionId] {
                        sectionGroup(sectionId: sectionId, changes: changes)
                    }
                }

                // Done button
                doneButton
            }
            .padding()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("Based on your tracked data")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("We've analyzed your tracked metrics and suggest updating these survey responses. Accept to use the new values, or keep your original responses.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Section Group

    private func sectionGroup(sectionId: String, changes: [SurveyProposedChange]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text(formatSectionName(sectionId))
                .font(.headline)
                .foregroundColor(.primary)
                .textCase(.uppercase)

            Divider()

            // Changes in this section
            ForEach(changes) { change in
                ProposedChangeCard(
                    change: change,
                    isAccepted: viewModel.acceptedChangeIds.contains(change.id),
                    isKept: viewModel.keptChangeIds.contains(change.id),
                    onAccept: {
                        Task {
                            await viewModel.acceptChange(change)
                        }
                    },
                    onKeep: {
                        viewModel.keepCurrentResponse(change)
                    }
                )
            }
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        let totalChanges = viewModel.proposedChanges.count
        let addressedChanges = viewModel.acceptedChangeIds.count + viewModel.keptChangeIds.count
        let allAddressed = addressedChanges == totalChanges

        return Button {
            dismiss()
        } label: {
            HStack {
                Image(systemName: allAddressed ? "checkmark.circle.fill" : "arrow.left")
                Text(allAddressed ? "Done" : "Review Later")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(allAddressed ? Color.green : Color.blue)
            .cornerRadius(12)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("No Suggested Updates")
                .font(.headline)
            Text("Your survey responses match your tracked data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Helpers

    private func formatSectionName(_ sectionId: String) -> String {
        // Convert section_id like "nutrition" to "Nutrition"
        sectionId.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Proposed Change Card

struct ProposedChangeCard: View {
    let change: SurveyProposedChange
    let isAccepted: Bool
    let isKept: Bool
    let onAccept: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text
            Text(change.questionText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            // Current vs Proposed comparison
            HStack(spacing: 12) {
                // Current value
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text(change.currentOptionText ?? "Not set")
                        .font(.caption)
                        .foregroundColor(isKept ? .blue : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isKept ? Color.blue.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isKept ? Color.blue : Color.clear, lineWidth: 1)
                        )
                }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Proposed value
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text(change.proposedOptionText)
                        .font(.caption)
                        .foregroundColor(isAccepted ? .green : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isAccepted ? Color.green.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isAccepted ? Color.green : Color.clear, lineWidth: 1)
                        )
                }
            }

            // Source metric info
            if let metricId = change.sourceMetricId {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                    Text("Your tracked avg: \(formatTrackedValue(change.trackedValue, metricId: metricId))")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            // Action buttons
            if !isAccepted && !isKept {
                HStack(spacing: 8) {
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text("Accept")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                    }

                    Button {
                        onKeep()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Keep Current")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                // Show status
                HStack {
                    if isAccepted {
                        Label("Accepted", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if isKept {
                        Label("Keeping current", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    // Undo button
                    Button("Undo") {
                        if isAccepted {
                            onKeep() // This will remove from accepted and toggle to kept
                        } else {
                            onAccept() // This will remove from kept and toggle to accepted
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func formatTrackedValue(_ value: Double, metricId: String) -> String {
        // Format based on metric type
        if metricId.contains("PROTEIN") || metricId.contains("CALORIES") {
            return "\(Int(value))g/day"
        } else if metricId.contains("SLEEP") {
            let hours = value / 60 // Assuming minutes
            return String(format: "%.1fh/night", hours)
        } else if metricId.contains("STEPS") {
            return "\(Int(value)) steps/day"
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    ProposedChangesView(viewModel: ReassessmentViewModel())
}
