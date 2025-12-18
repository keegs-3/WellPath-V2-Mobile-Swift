//
//  FoodLogDataManagementView.swift
//  WellPath
//
//  Unified view showing all food log entries with macro donut charts
//  Displays food_log entries from patient_category_samples with usda_foods data
//

import SwiftUI
import Supabase

// MARK: - Meal Type Filter

enum MealTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    var filterValue: String? {
        switch self {
        case .all: return nil
        case .breakfast: return "breakfast"
        case .lunch: return "lunch"
        case .dinner: return "dinner"
        case .snack: return "snack"
        }
    }

    var icon: String {
        switch self {
        case .all: return "fork.knife"
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        case .snack: return .green
        }
    }
}

// MARK: - Food Log Entry Model

struct FoodLogEntry: Identifiable {
    let id: UUID
    let foodName: String
    let mealType: String
    let portionGrams: Double
    let startTime: Date
    let createdAt: Date
    let source: String
    // Nutrition data (scaled by portion)
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
    let calories: Double
    // Food category info
    let isVegetable: Bool
    let isFruit: Bool
    let isProtein: Bool
    let isLegume: Bool
    let isWholeGrain: Bool

    var categoryIcon: String {
        if isProtein { return "fish.fill" }
        if isVegetable { return "carrot.fill" }
        if isFruit { return "apple.logo" }
        if isLegume { return "leaf.fill" }
        if isWholeGrain { return "basket.fill" }
        return "fork.knife"
    }

    var categoryColor: Color {
        if isProtein { return Color(red: 0.8, green: 0.5, blue: 0.3) }
        if isVegetable { return Color(red: 0.3, green: 0.7, blue: 0.4) }
        if isFruit { return Color(red: 0.9, green: 0.4, blue: 0.4) }
        if isLegume { return Color(red: 0.6, green: 0.5, blue: 0.3) }
        if isWholeGrain { return Color(red: 0.7, green: 0.6, blue: 0.4) }
        return .blue
    }

    var mealTypeDisplay: String {
        mealType.capitalized
    }
}

// MARK: - Main View

struct FoodLogDataManagementView: View {
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodLogDataManagementViewModel()
    @State private var selectedFilter: MealTypeFilter = .all
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var editMode: EditMode = .inactive
    @State private var showingAddFood = false

    private var filteredEntriesByDate: [Date: [FoodLogEntry]] {
        if selectedFilter == .all {
            return viewModel.entriesByDate
        }
        guard let filterValue = selectedFilter.filterValue else {
            return viewModel.entriesByDate
        }
        var filtered: [Date: [FoodLogEntry]] = [:]
        for (date, entries) in viewModel.entriesByDate {
            let matchingEntries = entries.filter { $0.mealType == filterValue }
            if !matchingEntries.isEmpty {
                filtered[date] = matchingEntries
            }
        }
        return filtered
    }

    private var sortedDates: [Date] {
        filteredEntriesByDate.keys.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                filterTabsView

                if viewModel.isLoading {
                    loadingView
                } else if filteredEntriesByDate.isEmpty {
                    emptyStateView
                } else {
                    entriesList
                }
            }
            .navigationTitle("Food Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddFood = true } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.entriesByDate.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                                if editMode == .inactive {
                                    selectedEntries.removeAll()
                                }
                            }
                        } label: {
                            Text(editMode == .active ? "Done" : "Edit")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
        .task {
            await viewModel.loadFoodLogs()
        }
        .sheet(isPresented: $showingAddFood) {
            FoodEntryView()
        }
        .alert("Delete Entries", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSelectedEntries()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(selectedEntries.count) selected \(selectedEntries.count == 1 ? "entry" : "entries")?")
        }
    }

    // MARK: - Filter Tabs

    private var filterTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MealTypeFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 12))
                            Text(filter.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? filter.color : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemBackground))
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
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "fork.knife")
                    .font(.system(size: 36))
                    .foregroundColor(color)
            }

            Text(selectedFilter == .all ? "No Food Logged" : "No \(selectedFilter.rawValue) Entries")
                .font(.title3)
                .fontWeight(.medium)

            Text("Tap + to log a food")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entries List

    private var entriesList: some View {
        List {
            ForEach(sortedDates, id: \.self) { date in
                Section {
                    ForEach(filteredEntriesByDate[date] ?? [], id: \.id) { entry in
                        if editMode == .active {
                            FoodLogEntryRow(entry: entry, isSelected: selectedEntries.contains(entry.id), editMode: editMode)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedEntries.contains(entry.id) {
                                        selectedEntries.remove(entry.id)
                                    } else {
                                        selectedEntries.insert(entry.id)
                                    }
                                }
                        } else {
                            NavigationLink(destination: FoodLogDetailView(entry: entry, onDelete: {
                                Task {
                                    await viewModel.deleteEntries(ids: [entry.id])
                                }
                            })) {
                                FoodLogEntryRow(entry: entry, isSelected: false, editMode: editMode)
                            }
                        }
                    }
                } header: {
                    Text(formatSectionDate(date))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if editMode == .active && !selectedEntries.isEmpty {
                deleteButton
            }
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete \(selectedEntries.count) \(selectedEntries.count == 1 ? "Entry" : "Entries")")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Helpers

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    private func deleteSelectedEntries() async {
        await viewModel.deleteEntries(ids: Array(selectedEntries))
        selectedEntries.removeAll()
        editMode = .inactive
    }
}

// MARK: - Entry Row

struct FoodLogEntryRow: View {
    let entry: FoodLogEntry
    let isSelected: Bool
    let editMode: EditMode

    var body: some View {
        HStack(spacing: 12) {
            // Selection circle in edit mode
            if editMode == .active {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title2)
            }

            // Mini macro donut
            MiniMacroDonut(
                proteinGrams: entry.proteinGrams,
                carbGrams: entry.carbGrams,
                fatGrams: entry.fatGrams,
                size: 40
            )

            // Entry details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.foodName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Image(systemName: entry.categoryIcon)
                        .font(.caption)
                        .foregroundColor(entry.categoryColor)
                }

                HStack(spacing: 8) {
                    Text("\(Int(entry.calories)) cal")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(entry.mealTypeDisplay)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundColor(.secondary)

                    Text(formatTime(entry.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Chevron
            if editMode == .inactive {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Detail View

struct FoodLogDetailView: View {
    let entry: FoodLogEntry
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.foodName)
                                .font(.title2)
                                .fontWeight(.semibold)

                            HStack(spacing: 8) {
                                Label(entry.mealTypeDisplay, systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("\(Int(entry.portionGrams))g portion")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: entry.categoryIcon)
                            .font(.title)
                            .foregroundColor(entry.categoryColor)
                    }

                    Divider()

                    // Macro breakdown
                    HStack(spacing: 0) {
                        macroColumn("Calories", "\(Int(entry.calories))", "flame.fill", .orange)
                        Divider().frame(height: 50)
                        macroColumn("Protein", "\(Int(entry.proteinGrams))g", "p.circle.fill", MiniMacroDonut.proteinColor)
                        Divider().frame(height: 50)
                        macroColumn("Carbs", "\(Int(entry.carbGrams))g", "c.circle.fill", MiniMacroDonut.carbColor)
                        Divider().frame(height: 50)
                        macroColumn("Fat", "\(Int(entry.fatGrams))g", "f.circle.fill", MiniMacroDonut.fatColor)
                    }

                    // Larger donut chart
                    MiniMacroDonut(
                        proteinGrams: entry.proteinGrams,
                        carbGrams: entry.carbGrams,
                        fatGrams: entry.fatGrams,
                        size: 100
                    )
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    metadataRow("Date", formatDate(entry.startTime))
                    metadataRow("Time", formatTime(entry.startTime))
                    metadataRow("Added", formatDateTime(entry.createdAt))
                    metadataRow("Source", entry.source == "wellpath_input" ? "WellPath" : entry.source.capitalized)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Delete button
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Entry")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Food Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Entry?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func macroColumn(_ label: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - View Model

@MainActor
class FoodLogDataManagementViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [FoodLogEntry]] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadFoodLogs() async {
        isLoading = true
        error = nil

        do {
            guard let patientId = try? await supabase.auth.session.user.id else {
                isLoading = false
                return
            }

            // Query food logs with joined usda_foods data
            let query = """
            SELECT
                pcs.id,
                pcs.start_time,
                pcs.created_at,
                pcs.source,
                pcs.metadata,
                uf.description as food_description,
                uf.protein_g,
                uf.fat_total_g,
                uf.carbs_g,
                uf.calories,
                uf.is_vegetable,
                uf.is_fruit,
                uf.is_protein,
                uf.is_legume,
                uf.is_whole_grain
            FROM patient_category_samples pcs
            LEFT JOIN usda_foods uf ON (pcs.metadata->>'usda_food_id')::uuid = uf.id
            WHERE pcs.patient_id = '\(patientId.uuidString)'
            AND pcs.category_type = 'food_log'
            ORDER BY pcs.start_time DESC
            LIMIT 500
            """

            let rows: [FoodLogRow] = try await supabase
                .rpc("execute_sql", params: ["query": query])
                .execute()
                .value

            // Group by date
            let calendar = Calendar.current
            var grouped: [Date: [FoodLogEntry]] = [:]

            for row in rows {
                let entry = row.toFoodLogEntry()
                let dateKey = calendar.startOfDay(for: entry.startTime)

                if grouped[dateKey] == nil {
                    grouped[dateKey] = []
                }
                grouped[dateKey]?.append(entry)
            }

            entriesByDate = grouped
            isLoading = false

        } catch {
            // Fallback: query directly without join
            await loadFoodLogsFallback()
        }
    }

    private func loadFoodLogsFallback() async {
        do {
            guard let patientId = try? await supabase.auth.session.user.id else {
                isLoading = false
                return
            }

            // Query food logs
            let rows: [FoodLogRowSimple] = try await supabase
                .from("patient_category_samples")
                .select("id, start_time, created_at, source, metadata")
                .eq("patient_id", value: patientId.uuidString)
                .eq("category_type", value: "food_log")
                .order("start_time", ascending: false)
                .limit(500)
                .execute()
                .value

            // Get unique food IDs
            let foodIds = rows.compactMap { $0.metadata?.usdaFoodId }
            let uniqueFoodIds = Array(Set(foodIds))

            // Fetch food data
            var foodCache: [String: USDAFoodData] = [:]
            if !uniqueFoodIds.isEmpty {
                let foods: [USDAFoodData] = try await supabase
                    .from("usda_foods")
                    .select("id, description, protein_g, fat_total_g, carbs_g, calories, is_vegetable, is_fruit, is_protein, is_legume, is_whole_grain")
                    .in("id", values: uniqueFoodIds)
                    .execute()
                    .value

                for food in foods {
                    foodCache[food.id.uuidString.lowercased()] = food
                }
            }

            // Convert to entries
            let calendar = Calendar.current
            var grouped: [Date: [FoodLogEntry]] = [:]

            for row in rows {
                guard let metadata = row.metadata,
                      let foodIdStr = metadata.usdaFoodId,
                      let food = foodCache[foodIdStr.lowercased()] else { continue }

                let portionGrams = metadata.portionGrams ?? 100
                let scale = portionGrams / 100.0

                let entry = FoodLogEntry(
                    id: row.id,
                    foodName: metadata.foodName ?? food.description,
                    mealType: metadata.mealType ?? "snack",
                    portionGrams: portionGrams,
                    startTime: row.startTime,
                    createdAt: row.createdAt ?? row.startTime,
                    source: row.source ?? "wellpath_input",
                    proteinGrams: (Double(food.proteinG) ?? 0) * scale,
                    carbGrams: (Double(food.carbsG) ?? 0) * scale,
                    fatGrams: (Double(food.fatTotalG) ?? 0) * scale,
                    calories: (Double(food.calories) ?? 0) * scale,
                    isVegetable: food.isVegetable ?? false,
                    isFruit: food.isFruit ?? false,
                    isProtein: food.isProtein ?? false,
                    isLegume: food.isLegume ?? false,
                    isWholeGrain: food.isWholeGrain ?? false
                )

                let dateKey = calendar.startOfDay(for: entry.startTime)
                if grouped[dateKey] == nil {
                    grouped[dateKey] = []
                }
                grouped[dateKey]?.append(entry)
            }

            entriesByDate = grouped
            isLoading = false

        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("Error loading food logs: \(error)")
        }
    }

    func deleteEntries(ids: [UUID]) async {
        do {
            for id in ids {
                try await supabase
                    .from("patient_category_samples")
                    .delete()
                    .eq("id", value: id.uuidString)
                    .execute()
            }

            // Remove from local state
            for (date, entries) in entriesByDate {
                entriesByDate[date] = entries.filter { !ids.contains($0.id) }
                if entriesByDate[date]?.isEmpty == true {
                    entriesByDate.removeValue(forKey: date)
                }
            }

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Data Models

private struct FoodLogRow: Codable {
    let id: UUID
    let startTime: Date
    let createdAt: Date?
    let source: String?
    let metadata: FoodLogMetadataRow?
    let foodDescription: String?
    let proteinG: String?
    let fatTotalG: String?
    let carbsG: String?
    let calories: String?
    let isVegetable: Bool?
    let isFruit: Bool?
    let isProtein: Bool?
    let isLegume: Bool?
    let isWholeGrain: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case createdAt = "created_at"
        case source
        case metadata
        case foodDescription = "food_description"
        case proteinG = "protein_g"
        case fatTotalG = "fat_total_g"
        case carbsG = "carbs_g"
        case calories
        case isVegetable = "is_vegetable"
        case isFruit = "is_fruit"
        case isProtein = "is_protein"
        case isLegume = "is_legume"
        case isWholeGrain = "is_whole_grain"
    }

    func toFoodLogEntry() -> FoodLogEntry {
        let portionGrams = metadata?.portionGrams ?? 100
        let scale = portionGrams / 100.0

        return FoodLogEntry(
            id: id,
            foodName: metadata?.foodName ?? foodDescription ?? "Unknown Food",
            mealType: metadata?.mealType ?? "snack",
            portionGrams: portionGrams,
            startTime: startTime,
            createdAt: createdAt ?? startTime,
            source: source ?? "wellpath_input",
            proteinGrams: (Double(proteinG ?? "0") ?? 0) * scale,
            carbGrams: (Double(carbsG ?? "0") ?? 0) * scale,
            fatGrams: (Double(fatTotalG ?? "0") ?? 0) * scale,
            calories: (Double(calories ?? "0") ?? 0) * scale,
            isVegetable: isVegetable ?? false,
            isFruit: isFruit ?? false,
            isProtein: isProtein ?? false,
            isLegume: isLegume ?? false,
            isWholeGrain: isWholeGrain ?? false
        )
    }
}

private struct FoodLogMetadataRow: Codable {
    let foodName: String?
    let mealType: String?
    let portionGrams: Double?
    let usdaFoodId: String?

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case mealType = "meal_type"
        case portionGrams = "portion_grams"
        case usdaFoodId = "usda_food_id"
    }
}

private struct FoodLogRowSimple: Codable {
    let id: UUID
    let startTime: Date
    let createdAt: Date?
    let source: String?
    let metadata: FoodLogMetadataRow?

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case createdAt = "created_at"
        case source
        case metadata
    }
}

private struct USDAFoodData: Codable {
    let id: UUID
    let description: String
    let proteinG: String
    let fatTotalG: String
    let carbsG: String
    let calories: String
    let isVegetable: Bool?
    let isFruit: Bool?
    let isProtein: Bool?
    let isLegume: Bool?
    let isWholeGrain: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case proteinG = "protein_g"
        case fatTotalG = "fat_total_g"
        case carbsG = "carbs_g"
        case calories
        case isVegetable = "is_vegetable"
        case isFruit = "is_fruit"
        case isProtein = "is_protein"
        case isLegume = "is_legume"
        case isWholeGrain = "is_whole_grain"
    }
}

#Preview {
    FoodLogDataManagementView(color: .blue)
}
