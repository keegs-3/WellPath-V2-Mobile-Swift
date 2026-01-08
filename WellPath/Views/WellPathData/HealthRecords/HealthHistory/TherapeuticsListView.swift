//
//  TherapeuticsListView.swift
//  WellPath
//
//  Main view for managing therapeutics (medications, supplements, peptides).
//  Shows grouped lists with ability to add/edit/discontinue.
//

import SwiftUI

struct TherapeuticsListView: View {
    @StateObject private var viewModel = TherapeuticsViewModel()
    @State private var showAddTherapeutic = false
    @State private var selectedTherapeutic: PatientTherapeutic?
    @State private var selectedType: TherapeuticType = .medication
    @State private var showingInactive = false

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                // Type picker
                Picker("Type", selection: $selectedType) {
                    ForEach(TherapeuticType.primaryCases) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    contentView
                }
            }
        }
        .navigationTitle("Therapeutics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showAddTherapeutic = true
                    } label: {
                        Label("Add \(selectedType.displayName)", systemImage: "plus")
                    }

                    Divider()

                    Toggle("Show Discontinued", isOn: $showingInactive)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddTherapeutic) {
            TherapeuticSearchView()
        }
        .sheet(item: $selectedTherapeutic) { therapeutic in
            EditTherapeuticView(therapeutic: therapeutic)
        }
        .task {
            await viewModel.loadTherapeutics()
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        let therapeutics = therapeuticsForSelectedType
        let active = therapeutics.filter { $0.isActive == true }
        let inactive = therapeutics.filter { $0.isActive == false }

        return Group {
            if active.isEmpty && (!showingInactive || inactive.isEmpty) {
                emptyStateView
            } else {
                therapeuticsList(active: active, inactive: inactive)
            }
        }
    }

    private var therapeuticsForSelectedType: [PatientTherapeutic] {
        switch selectedType {
        case .medication:
            return viewModel.medications
        case .supplement:
            return viewModel.supplements
        case .peptide:
            return viewModel.peptides
        case .hormone:
            return viewModel.hormones
        case .other:
            return []
        }
    }

    // MARK: - Therapeutics List

    private func therapeuticsList(active: [PatientTherapeutic], inactive: [PatientTherapeutic]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Active section
                if !active.isEmpty {
                    sectionHeader("Active", icon: "checkmark.circle.fill", color: .green)

                    ForEach(active) { therapeutic in
                        TherapeuticCard(therapeutic: therapeutic) {
                            selectedTherapeutic = therapeutic
                        }
                    }
                }

                // Inactive section
                if showingInactive && !inactive.isEmpty {
                    sectionHeader("Discontinued", icon: "xmark.circle.fill", color: .gray)

                    ForEach(inactive) { therapeutic in
                        TherapeuticCard(therapeutic: therapeutic) {
                            selectedTherapeutic = therapeutic
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedType.icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No \(selectedType.displayName)s")
                .font(.title3)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showAddTherapeutic = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add \(selectedType.displayName)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(selectedType.color)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateMessage: String {
        switch selectedType {
        case .medication:
            return "Track your prescription and over-the-counter medications here."
        case .supplement:
            return "Keep track of vitamins, minerals, and other supplements you take."
        case .peptide:
            return "Log peptide therapies for tracking and adherence."
        case .hormone:
            return "Track hormone therapies like TRT, estrogen, thyroid, and more."
        case .other:
            return "Add other therapeutics here."
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading therapeutics...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button("Try Again") {
                Task { await viewModel.loadTherapeutics() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        selectedType.color.opacity(0.3),
                        selectedType.color.opacity(0.2),
                        selectedType.color.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)

                Spacer()
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut, value: selectedType)
    }
}

// MARK: - Therapeutic Card

struct TherapeuticCard: View {
    let therapeutic: PatientTherapeutic
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(therapeutic.type.color.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: therapeutic.type.icon)
                            .font(.title3)
                            .foregroundColor(therapeutic.type.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(therapeutic.therapeuticName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let category = therapeutic.category {
                            Text(category)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Status
                    if therapeutic.isActive == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }

                // Dosing info
                HStack(spacing: 16) {
                    if !therapeutic.doseDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dose")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(therapeutic.doseDescription)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    if !therapeutic.frequencyDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Frequency")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(therapeutic.frequencyDescription)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Timing badges
                if !therapeutic.timingDescription.isEmpty {
                    HStack(spacing: 6) {
                        if therapeutic.timingMorning == true {
                            TimingBadge(text: "AM", color: .orange)
                        }
                        if therapeutic.timingMidday == true {
                            TimingBadge(text: "Noon", color: .yellow)
                        }
                        if therapeutic.timingEvening == true {
                            TimingBadge(text: "PM", color: .blue)
                        }
                        if therapeutic.timingBedtime == true {
                            TimingBadge(text: "Bed", color: .purple)
                        }
                        if therapeutic.timingWithFood == true {
                            TimingBadge(text: "With Food", color: .green)
                        }
                    }
                }

                // Reason for taking
                if let reason = therapeutic.reasonForTaking, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .opacity(therapeutic.isActive == true ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
    }
}

struct TimingBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

#Preview {
    NavigationStack {
        TherapeuticsListView()
    }
}
