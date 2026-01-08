//
//  TherapeuticsExploreView.swift
//  WellPath
//
//  Searchable browse of sample_therapeutic_types by type.
//  Shows education content and "Add to My Therapeutics" action.
//

import SwiftUI

struct TherapeuticsExploreView: View {
    let therapeuticType: TherapeuticType

    @StateObject private var viewModel = TherapeuticsExploreViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedTherapeutic: TherapeuticsBase?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $searchText, placeholder: "Search \(therapeuticType.displayNamePlural.lowercased())...")
                .padding()

            // Category filter chips
            if !viewModel.categories.isEmpty {
                CategoryChipsView(
                    categories: viewModel.categories,
                    selectedCategory: $selectedCategory
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Results
            if viewModel.isLoading {
                loadingView
            } else if filteredTherapeutics.isEmpty {
                emptyStateView
            } else {
                therapeuticsList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(therapeuticType.displayNamePlural)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedTherapeutic) { therapeutic in
            TherapeuticAboutSheet(therapeutic: therapeutic)
        }
        .task {
            await viewModel.loadTherapeutics(type: therapeuticType)
        }
    }

    // MARK: - Filtered Results

    private var filteredTherapeutics: [TherapeuticsBase] {
        var results = viewModel.therapeutics

        // Filter by search
        if !searchText.isEmpty {
            results = results.filter {
                $0.therapeuticName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by category
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        return results
    }

    // MARK: - Therapeutics List

    private var therapeuticsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                Text("\(filteredTherapeutics.count) \(therapeuticType.displayNamePlural)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ForEach(filteredTherapeutics) { therapeutic in
                    TherapeuticExploreCard(therapeutic: therapeutic) {
                        selectedTherapeutic = therapeutic
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading \(therapeuticType.displayNamePlural.lowercased())...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(.headline)

            Text("Try a different search or category")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Category Chips View

struct CategoryChipsView: View {
    let categories: [String]
    @Binding var selectedCategory: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All chip
                CategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .cornerRadius(16)
        }
    }
}

// MARK: - Therapeutic Explore Card

struct TherapeuticExploreCard: View {
    let therapeutic: TherapeuticsBase
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(therapeutic.type.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: therapeutic.type.icon)
                        .font(.title3)
                        .foregroundColor(therapeutic.type.color)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(therapeutic.therapeuticName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let category = therapeutic.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !therapeutic.doseRangeDescription.isEmpty {
                        Text(therapeutic.doseRangeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ViewModel

@MainActor
class TherapeuticsExploreViewModel: ObservableObject {
    @Published var therapeutics: [TherapeuticsBase] = []
    @Published var categories: [String] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadTherapeutics(type: TherapeuticType) async {
        isLoading = true

        do {
            therapeutics = try await supabase
                .from("sample_therapeutic_types")
                .select()
                .eq("therapeutic_type", value: type.rawValue)
                .eq("is_active", value: true)
                .order("therapeutic_name")
                .execute()
                .value

            // Extract unique categories
            let uniqueCategories = Set(therapeutics.compactMap { $0.category })
            categories = uniqueCategories.sorted()

        } catch {
            self.error = error.localizedDescription
            print("TherapeuticsExploreViewModel: Error - \(error)")
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        TherapeuticsExploreView(therapeuticType: .supplement)
    }
}
