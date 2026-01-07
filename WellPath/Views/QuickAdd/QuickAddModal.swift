//
//  QuickAddModal.swift
//  WellPath
//
//  Quick add modal for logging goal progress from anywhere
//

import SwiftUI

struct QuickAddModal: View {
    @StateObject private var viewModel = GoalsViewModel()
    @State private var selectedGoal: PatientGoal?
    @State private var showQuickEntry = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(40)
                } else if viewModel.activeGoals.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No Active Goals")
                            .font(.headline)

                        Text("Goals will appear here once assigned by your clinician.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    // Goals Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(viewModel.activeGoals) { goal in
                            QuickAddGoalButton(
                                goal: goal,
                                progress: viewModel.progress(for: goal.goalId)
                            ) {
                                selectedGoal = goal
                                showQuickEntry = true
                            }
                        }
                    }
                    .padding()
                }

                Spacer()

                // Full Entry Link
                NavigationLink {
                    TrackedMetricsEntryView()
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("Full Entry")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task {
                await viewModel.loadGoals()
            }
            .sheet(isPresented: $showQuickEntry) {
                if let goal = selectedGoal {
                    QuickEntrySheet(
                        goal: goal,
                        currentValue: viewModel.actualValue(for: goal.goalId),
                        onSubmit: { value in
                            Task {
                                let success = await viewModel.logQuickEntry(goalId: goal.goalId, value: value)
                                if success {
                                    showQuickEntry = false
                                    // Small delay then dismiss parent
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    dismiss()
                                }
                            }
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
        }
    }
}

// MARK: - Quick Add Goal Button

struct QuickAddGoalButton: View {
    let goal: PatientGoal
    let progress: GoalProgress?
    let onTap: () -> Void

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var progressPercent: Double {
        progress?.displayProgress ?? 0
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon with mini progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: min(progressPercent / 100, 1.0))
                        .stroke(Color(hex: pillar.color) ?? .green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: pillar.icon)
                        .font(.title2)
                        .foregroundColor(Color(hex: pillar.color) ?? .green)
                }

                // Label
                Text(goal.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Progress text
                Text("\(Int(progressPercent))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickAddModal()
}
