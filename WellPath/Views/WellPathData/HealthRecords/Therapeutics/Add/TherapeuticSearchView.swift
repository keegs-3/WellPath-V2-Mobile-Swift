//
//  TherapeuticSearchView.swift
//  WellPath
//
//  Search-first add flow for therapeutics.
//  Allows searching, filtering by type, and adding custom entries.
//

import SwiftUI

struct TherapeuticSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TherapeuticsViewModel()

    @State private var searchText = ""
    @State private var selectedType: TherapeuticType?
    @State private var showingAddCustom = false

    private var filteredTherapeutics: [TherapeuticsBase] {
        viewModel.searchTherapeuticsBase(query: searchText, type: selectedType)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Type filter chips
                filterChips

                // Results or empty state
                if viewModel.therapeuticsBase.isEmpty {
                    loadingView
                } else if filteredTherapeutics.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Add Therapeutic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCustom) {
                TherapeuticFormView(preselectedTherapeutic: nil)
            }
        }
        .task {
            await viewModel.loadTherapeuticsBase()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search medications, supplements...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All filter
                FilterChip(
                    label: "All",
                    isSelected: selectedType == nil,
                    color: .gray
                ) {
                    selectedType = nil
                }

                // Type filters
                ForEach(TherapeuticType.primaryCases) { type in
                    FilterChip(
                        label: type.displayNamePlural,
                        isSelected: selectedType == type,
                        color: type.color
                    ) {
                        selectedType = (selectedType == type) ? nil : type
                    }
                }

                // Custom button
                FilterChip(
                    label: "Custom",
                    isSelected: false,
                    color: .purple,
                    icon: "plus"
                ) {
                    showingAddCustom = true
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            // Show popular/suggested when no search
            if searchText.isEmpty {
                popularSection
            }

            // Search results
            ForEach(filteredTherapeutics.prefix(50)) { therapeutic in
                NavigationLink(destination: TherapeuticFormView(preselectedTherapeutic: therapeutic)) {
                    TherapeuticSearchRow(therapeutic: therapeutic)
                }
            }

            // Show more indicator
            if filteredTherapeutics.count > 50 {
                HStack {
                    Spacer()
                    Text("Showing 50 of \(filteredTherapeutics.count) results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // Add custom option at bottom
            if !searchText.isEmpty {
                addCustomRow
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Popular Section

    private var popularSection: some View {
        Section {
            // Common supplements
            let popular = [
                "Vitamin D3", "Omega-3", "Magnesium", "Vitamin B12",
                "CoQ10", "NAC", "NMN", "Creatine"
            ]

            ForEach(popular, id: \.self) { name in
                if let therapeutic = viewModel.therapeuticsBase.first(where: { $0.therapeuticName == name }) {
                    NavigationLink(destination: TherapeuticFormView(preselectedTherapeutic: therapeutic)) {
                        TherapeuticSearchRow(therapeutic: therapeutic)
                    }
                }
            }
        } header: {
            Text("Popular")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Add Custom Row

    private var addCustomRow: some View {
        Button {
            showingAddCustom = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Custom Therapeutic")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("Can't find what you're looking for?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color.purple.opacity(0.05))
    }

    // MARK: - Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading therapeutics...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No results for \"\(searchText)\"")
                .font(.headline)

            Text("Try a different search term or add a custom therapeutic")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showingAddCustom = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Therapeutic")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.purple)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Row

struct TherapeuticSearchRow: View {
    let therapeutic: TherapeuticsBase

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill(therapeutic.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: therapeutic.type.icon)
                    .font(.body)
                    .foregroundColor(therapeutic.type.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(therapeutic.therapeuticName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Text(therapeutic.type.displayName)
                        .font(.caption)
                        .foregroundColor(therapeutic.type.color)

                    if let category = therapeutic.category {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Dose hint
            if !therapeutic.doseRangeDescription.isEmpty {
                Text(therapeutic.doseRangeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TherapeuticSearchView()
}
