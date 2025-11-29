//
//  LogExceptionView.swift
//  WellPath
//
//  Form for logging life exceptions that affect plan adherence.
//  Allows users to document circumstances that prevent them from following their health plan.
//

import SwiftUI

struct LogExceptionView: View {
    @ObservedObject var viewModel: HealthProfileViewModel
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var exceptionType: PlanExceptionType = .lifeEvent
    @State private var reason: String = ""
    @State private var affectedPillars: Set<String> = []
    @State private var isTemporary: Bool = true
    @State private var startDate: Date = Date()
    @State private var expectedEndDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Available pillars
    private let pillars = [
        ("sleep", "Sleep", "moon.zzz.fill"),
        ("nutrition", "Nutrition", "leaf.fill"),
        ("movement", "Movement", "figure.run"),
        ("stress", "Stress", "heart.circle.fill"),
        ("cognitive", "Cognitive", "brain.head.profile"),
        ("connection", "Connection", "person.2.fill")
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Intro section
                Section {
                    introCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Exception type
                Section {
                    exceptionTypePicker
                } header: {
                    Text("What's happening?")
                }

                // Reason (optional)
                Section {
                    TextField("Tell us more (optional)", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Details")
                } footer: {
                    Text("This helps us better understand your situation and provide relevant support.")
                }

                // Affected pillars
                Section {
                    affectedPillarsPicker
                } header: {
                    Text("Which areas are affected?")
                } footer: {
                    Text("Leave empty if all areas are affected.")
                }

                // Duration
                Section {
                    durationPicker
                } header: {
                    Text("Duration")
                }

                // What this means
                Section {
                    infoCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Log Life Exception")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveException()
                    }
                    .disabled(isSaving)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Intro Card

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Life Happens")
                    .font(.headline)
            }

            Text("Sometimes circumstances prevent us from following our health plans. That's okay! Documenting these events helps us understand your journey and adjust expectations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding()
    }

    // MARK: - Exception Type Picker

    private var exceptionTypePicker: some View {
        VStack(spacing: 12) {
            ForEach(PlanExceptionType.allCases, id: \.self) { type in
                Button {
                    exceptionType = type
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: type.iconName)
                            .font(.title3)
                            .foregroundColor(exceptionType == type ? .blue : .secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.body)
                                .foregroundColor(.primary)

                            Text(type.examples)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if exceptionType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Affected Pillars Picker

    private var affectedPillarsPicker: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(pillars, id: \.0) { pillar in
                Button {
                    if affectedPillars.contains(pillar.0) {
                        affectedPillars.remove(pillar.0)
                    } else {
                        affectedPillars.insert(pillar.0)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: pillar.2)
                            .font(.caption)

                        Text(pillar.1)
                            .font(.subheadline)

                        Spacer()

                        if affectedPillars.contains(pillar.0) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(affectedPillars.contains(pillar.0) ? .blue : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(affectedPillars.contains(pillar.0) ? Color.blue.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(affectedPillars.contains(pillar.0) ? Color.blue : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(spacing: 12) {
            DatePicker("Started", selection: $startDate, displayedComponents: .date)

            Toggle("This is temporary", isOn: $isTemporary)

            if isTemporary {
                DatePicker("Expected to resolve by", selection: $expectedEndDate, in: startDate..., displayedComponents: .date)
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                Text("What this means")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.secondary)

            Text("Your original health goals remain unchanged. During this exception period, affected metrics will be marked as excused rather than failed. This preserves data integrity while acknowledging real-life circumstances.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Save Action

    private func saveException() {
        isSaving = true

        Task {
            do {
                let pillarsArray = affectedPillars.isEmpty ? nil : Array(affectedPillars)
                let endDate = isTemporary ? expectedEndDate : nil

                try await viewModel.logException(
                    type: exceptionType,
                    reason: reason,
                    affectedPillars: pillarsArray,
                    startDate: startDate,
                    endDate: endDate
                )

                await MainActor.run {
                    isSaving = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    LogExceptionView(viewModel: HealthProfileViewModel()) {
        print("Dismissed")
    }
}
