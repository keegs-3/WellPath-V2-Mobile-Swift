//
//  NutritionDataManagementView.swift
//  WellPath
//
//  Unified data management view for all nutrition entries
//  Shows all food entries with filter tabs: All | Protein | Vegetables | Fruits | Legumes | Grains
//

import SwiftUI
import Supabase

// MARK: - Nutrition Category

enum NutritionCategory: String, CaseIterable, Identifiable {
    case all = "all"
    case protein = "protein"
    case vegetables = "vegetables"
    case fruits = "fruits"
    case legumes = "legumes"
    case wholeGrains = "whole_grains"
    case nutsSeeds = "nuts_seeds"
    case fiber = "fiber"
    case fats = "fats"
    case water = "water"
    case caffeine = "caffeine"
    case alcohol = "alcohol"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .protein: return "Protein"
        case .vegetables: return "Veggies"
        case .fruits: return "Fruits"
        case .legumes: return "Legumes"
        case .wholeGrains: return "Grains"
        case .nutsSeeds: return "Nuts"
        case .fiber: return "Fiber"
        case .fats: return "Fats"
        case .water: return "Water"
        case .caffeine: return "Caffeine"
        case .alcohol: return "Alcohol"
        }
    }

    var icon: String {
        switch self {
        case .all: return "leaf.fill"
        case .protein: return "fish.fill"
        case .vegetables: return "carrot.fill"
        case .fruits: return "apple.logo"
        case .legumes: return "leaf.fill"
        case .wholeGrains: return "basket.fill"
        case .nutsSeeds: return "seal.fill"
        case .fiber: return "leaf.circle.fill"
        case .fats: return "drop.fill"
        case .water: return "waterbottle.fill"
        case .caffeine: return "cup.and.saucer.fill"
        case .alcohol: return "wineglass.fill"
        }
    }

    var quantityTypes: [String] {
        switch self {
        case .all:
            return [
                QuantityTypes.proteinGrams,
                QuantityTypes.vegetablesServings,
                QuantityTypes.fruitsServings,
                QuantityTypes.legumesServings,
                QuantityTypes.wholeGrainsServings,
                QuantityTypes.nutsSeedsServings,
                QuantityTypes.fiberGrams,
                QuantityTypes.fatGrams,
                QuantityTypes.waterMl,
                QuantityTypes.caffeineMg,
                QuantityTypes.alcoholDrinks
            ]
        case .protein:
            return [QuantityTypes.proteinGrams]
        case .vegetables:
            return [QuantityTypes.vegetablesServings]
        case .fruits:
            return [QuantityTypes.fruitsServings]
        case .legumes:
            return [QuantityTypes.legumesServings]
        case .wholeGrains:
            return [QuantityTypes.wholeGrainsServings]
        case .nutsSeeds:
            return [QuantityTypes.nutsSeedsServings]
        case .fiber:
            return [QuantityTypes.fiberGrams]
        case .fats:
            return [QuantityTypes.fatGrams]
        case .water:
            return [QuantityTypes.waterMl]
        case .caffeine:
            return [QuantityTypes.caffeineMg]
        case .alcohol:
            return [QuantityTypes.alcoholDrinks]
        }
    }

    var metadataTypeKey: String? {
        switch self {
        case .all: return nil
        case .protein: return "protein_type"
        case .vegetables: return "vegetables_type"
        case .fruits: return "fruits_type"
        case .legumes: return "legumes_type"
        case .wholeGrains: return "whole_grains_type"
        case .nutsSeeds: return "nuts_seeds_type"
        case .fiber: return "fiber_source"
        case .fats: return "fat_type"
        case .water: return nil  // Water doesn't have types
        case .caffeine: return "caffeine_type"
        case .alcohol: return "alcohol_type"
        }
    }

    func formatValue(_ value: Double, quantityType: String) -> String {
        switch quantityType {
        case QuantityTypes.proteinGrams:
            return "\(Int(value))g"
        case QuantityTypes.fiberGrams:
            return "\(Int(value))g"
        case QuantityTypes.fatGrams:
            return "\(Int(value))g"
        case QuantityTypes.waterMl:
            let oz = value / 29.5735  // Convert ml to oz
            return String(format: "%.0f oz", oz)
        case QuantityTypes.caffeineMg:
            return "\(Int(value)) mg"
        case QuantityTypes.alcoholDrinks:
            let intValue = Int(value)
            return intValue == 1 ? "1 drink" : "\(intValue) drinks"
        default:
            return String(format: "%.1f servings", value)
        }
    }

    static func from(quantityType: String) -> NutritionCategory {
        switch quantityType {
        case QuantityTypes.proteinGrams:
            return .protein
        case QuantityTypes.vegetablesServings:
            return .vegetables
        case QuantityTypes.fruitsServings:
            return .fruits
        case QuantityTypes.legumesServings:
            return .legumes
        case QuantityTypes.wholeGrainsServings:
            return .wholeGrains
        case QuantityTypes.nutsSeedsServings:
            return .nutsSeeds
        case QuantityTypes.fiberGrams:
            return .fiber
        case QuantityTypes.fatGrams:
            return .fats
        case QuantityTypes.waterMl:
            return .water
        case QuantityTypes.caffeineMg:
            return .caffeine
        case QuantityTypes.alcoholDrinks:
            return .alcohol
        default:
            return .all
        }
    }
}

// MARK: - Nutrition Entry Model

struct NutritionEntry: Identifiable {
    let id: UUID
    let patientId: UUID
    let quantityType: String
    let startTime: Date
    let createdAt: Date
    let source: String
    let typeName: String?
    let timingName: String?
    let eventInstanceId: UUID?
    // Original entry values (what user entered)
    let displayValue: Double
    let displayUnit: String
    // Canonical values (after conversion for storage)
    let canonicalValue: Double
    let canonicalUnit: String
    // Macro data for mini donut chart
    let proteinGrams: Double?
    let carbGrams: Double?
    let fatGrams: Double?
    // Food info from food_log (if linked via event_instance_id)
    let foodName: String?
    let mealType: String?
    let portionGrams: Double?
    let calories: Double?
    // All categories present in this event (for multi-category foods)
    let allCategories: [NutritionCategory]

    var category: NutritionCategory {
        NutritionCategory.from(quantityType: quantityType)
    }

    /// Format the original entry value with its unit
    var formattedValue: String {
        formatValueWithUnit(displayValue, unit: displayUnit)
    }

    /// Format the canonical value with its unit (for display when different from original)
    var formattedCanonicalValue: String {
        formatValueWithUnit(canonicalValue, unit: canonicalUnit)
    }

    /// Whether canonical differs from display (worth showing both)
    var hasConvertedValue: Bool {
        displayUnit != canonicalUnit
    }

    private func formatValueWithUnit(_ value: Double, unit: String) -> String {
        let formattedNum: String
        if value >= 100 || value == floor(value) {
            formattedNum = String(format: "%.0f", value)
        } else if value >= 10 {
            formattedNum = String(format: "%.1f", value)
        } else {
            formattedNum = String(format: "%.2f", value).replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        }

        // Format unit for display
        let displayUnitStr: String
        switch unit.lowercased() {
        case "gallon_us", "gal": displayUnitStr = "gal"
        case "fluid_ounce_us", "fl_oz", "oz": displayUnitStr = "oz"
        case "milliliter", "ml": displayUnitStr = "mL"
        case "liter", "l": displayUnitStr = "L"
        case "cup_us", "cups": displayUnitStr = "cups"
        case "glass", "glasses": displayUnitStr = "glasses"
        case "gram", "g": displayUnitStr = "g"
        case "milligram", "mg": displayUnitStr = "mg"
        case "serving", "servings": displayUnitStr = value == 1 ? "serving" : "servings"
        case "drink", "drinks": displayUnitStr = value == 1 ? "drink" : "drinks"
        default: displayUnitStr = unit
        }

        return "\(formattedNum) \(displayUnitStr)"
    }

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }

    var hasMacroData: Bool {
        (proteinGrams ?? 0) > 0 || (carbGrams ?? 0) > 0 || (fatGrams ?? 0) > 0
    }

    var hasFoodInfo: Bool {
        foodName != nil
    }

    var displayName: String {
        foodName ?? formattedValue
    }

    var mealTypeDisplay: String {
        mealType?.capitalized ?? ""
    }

    var categoryIcon: String {
        category.icon
    }

    var sourceDisplay: String {
        switch source.lowercased() {
        case "healthkit": return "Apple Health"
        case "wellpath", "wellpath_input": return "WellPath"
        default: return source.capitalized
        }
    }

    /// Check if this entry belongs to a specific category (for filtering)
    func belongsToCategory(_ cat: NutritionCategory) -> Bool {
        if cat == .all { return true }
        return allCategories.contains(cat)
    }
}

// MARK: - Food Log Info (for linking quantity samples to food_log entries)

struct FoodLogInfo {
    let foodName: String?
    let mealType: String?
    let portionGrams: Double?
}

// MARK: - Main View

struct NutritionDataManagementView: View {
    let color: Color
    var initialCategory: NutritionCategory = .all

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NutritionDataManagementViewModel()
    @State private var selectedCategory: NutritionCategory = .all
    @State private var hasSetInitialCategory = false
    @State private var editMode: EditMode = .inactive
    @State private var expandedDates: Set<Date> = []
    @State private var showingDateFilter = false
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    private var filteredEntries: [Date: [NutritionEntry]] {
        var result: [Date: [NutritionEntry]] = [:]

        for (date, entries) in viewModel.entriesByDate {
            // Filter by date range
            if let start = filterStartDate, date < Calendar.current.startOfDay(for: start) {
                continue
            }
            if let end = filterEndDate, date > Calendar.current.startOfDay(for: end) {
                continue
            }

            // Filter by category - use belongsToCategory() so multi-category foods appear in all relevant tabs
            let categoryFiltered = entries.filter { $0.belongsToCategory(selectedCategory) }

            if !categoryFiltered.isEmpty {
                result[date] = categoryFiltered
            }
        }

        return result
    }

    private var sortedDates: [Date] {
        filteredEntries.keys.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category tabs
                categoryTabsView

                // Content
                contentView
            }
            .navigationTitle("All Nutrition Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarButton
                }

                ToolbarItem(placement: .topBarLeading) {
                    filterButton
                }

                ToolbarItem(placement: .primaryAction) {
                    editButton
                }
            }
            .sheet(isPresented: $showingDateFilter) {
                DateFilterView(startDate: $filterStartDate, endDate: $filterEndDate, color: color)
            }
            .alert("Delete Nutrition Entries?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    selectedEntries.removeAll()
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSelectedEntries()
                    }
                }
            } message: {
                Text("This will permanently delete \(selectedEntries.count) entry(ies).")
            }
            .task {
                // Set initial category once on load
                if !hasSetInitialCategory {
                    selectedCategory = initialCategory
                    hasSetInitialCategory = true
                }
                await viewModel.loadAllNutritionData()
                expandedDates = Set(sortedDates)
            }
        }
    }

    // MARK: - Category Tabs

    private var categoryTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NutritionCategory.allCases) { category in
                    categoryTab(category)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func categoryTab(_ category: NutritionCategory) -> some View {
        let isSelected = selectedCategory == category
        let count = countForCategory(category)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))

                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func countForCategory(_ category: NutritionCategory) -> Int {
        // Use belongsToCategory() so multi-category foods are counted in all relevant tabs
        return viewModel.entriesByDate.values.flatMap { $0 }.filter { $0.belongsToCategory(category) }.count
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if sortedDates.isEmpty {
            emptyStateView
        } else {
            entriesList
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCategory.icon)
                .font(.system(size: 48))
                .foregroundColor(color.opacity(0.5))

            Text("No \(selectedCategory == .all ? "nutrition" : selectedCategory.displayName.lowercased()) data found")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entriesList: some View {
        List {
            ForEach(sortedDates, id: \.self) { date in
                Section {
                    if expandedDates.contains(date) {
                        ForEach(filteredEntries[date] ?? []) { entry in
                            entryRow(entry: entry)
                        }
                    }
                } header: {
                    sectionHeader(for: date)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
    }

    @ViewBuilder
    private func entryRow(entry: NutritionEntry) -> some View {
        if editMode == .inactive {
            NavigationLink(destination: NutritionEntryDetailView(entry: entry, color: color, viewModel: viewModel)) {
                NutritionEntryRow(entry: entry, color: color, showCategory: selectedCategory == .all)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if entry.canDelete {
                    Button(role: .destructive) {
                        selectedEntries = [entry.id]
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        } else {
            Button(action: {
                if entry.canDelete {
                    if selectedEntries.contains(entry.id) {
                        selectedEntries.remove(entry.id)
                    } else {
                        selectedEntries.insert(entry.id)
                    }
                }
            }) {
                HStack(spacing: 12) {
                    if entry.canDelete {
                        Image(systemName: selectedEntries.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedEntries.contains(entry.id) ? .blue : .gray)
                            .font(.system(size: 22))
                    }
                    NutritionEntryRow(entry: entry, color: color, showCategory: selectedCategory == .all)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(for date: Date) -> some View {
        Button(action: {
            withAnimation {
                if expandedDates.contains(date) {
                    expandedDates.remove(date)
                } else {
                    expandedDates.insert(date)
                }
            }
        }) {
            HStack {
                Text(formatSectionDate(date))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: expandedDates.contains(date) ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var leadingToolbarButton: some View {
        if editMode == .active {
            Button(selectedEntries.isEmpty ? "Select All" : "Delete (\(selectedEntries.count))") {
                if selectedEntries.isEmpty {
                    for entries in filteredEntries.values {
                        for entry in entries where entry.canDelete {
                            selectedEntries.insert(entry.id)
                        }
                    }
                } else {
                    showingDeleteAlert = true
                }
            }
            .foregroundColor(selectedEntries.isEmpty ? .blue : .red)
        } else {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
            }
        }
    }

    @ViewBuilder
    private var filterButton: some View {
        if !viewModel.sortedDates.isEmpty && editMode == .inactive {
            Button(action: { showingDateFilter = true }) {
                Image(systemName: (filterStartDate != nil || filterEndDate != nil) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundColor(color)
            }
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if !sortedDates.isEmpty {
            Button(editMode == .active ? "Done" : "Edit") {
                withAnimation {
                    if editMode == .active {
                        selectedEntries.removeAll()
                    }
                    editMode = editMode == .active ? .inactive : .active
                }
            }
        }
    }

    // MARK: - Helpers

    private func deleteSelectedEntries() async {
        let entriesToDelete = viewModel.entriesByDate.values
            .flatMap { $0 }
            .filter { selectedEntries.contains($0.id) }

        await viewModel.deleteEntries(entriesToDelete)
        selectedEntries.removeAll()

        withAnimation {
            editMode = .inactive
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Entry Row

struct NutritionEntryRow: View {
    let entry: NutritionEntry
    let color: Color
    let showCategory: Bool

    // Use nutrition pillar color from MetricsUIConfig
    private var nutritionColor: Color {
        MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Mini macro donut on LEFT (40px) - if macro data available
            if entry.hasMacroData {
                MiniMacroDonut(
                    proteinGrams: entry.proteinGrams ?? 0,
                    carbGrams: entry.carbGrams ?? 0,
                    fatGrams: entry.fatGrams ?? 0,
                    size: 40
                )
            } else {
                // Placeholder for non-macro entries (water, caffeine, etc.)
                categoryPlaceholder
            }

            // Entry details
            VStack(alignment: .leading, spacing: 4) {
                // Line 1: Display name + ALL category icons
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // Show icons for ALL categories in this event
                    ForEach(entry.allCategories, id: \.self) { cat in
                        Image(systemName: cat.icon)
                            .font(.caption2)
                            .foregroundColor(nutritionColor)
                    }
                }

                // Line 2: Calories + meal badge + time
                HStack(spacing: 8) {
                    if let cal = entry.calories, cal > 0 {
                        Text("\(Int(cal)) cal")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } else if let typeName = entry.typeName {
                        // Fallback to type name if no calories
                        Text(typeName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !entry.mealTypeDisplay.isEmpty {
                        Text(entry.mealTypeDisplay)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                            .foregroundColor(.secondary)
                    }

                    Text(formatTime(entry.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var categoryPlaceholder: some View {
        ZStack {
            Circle()
                .fill(nutritionColor.opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: entry.categoryIcon)
                .font(.system(size: 18))
                .foregroundColor(nutritionColor)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Entry Detail View

struct NutritionEntryDetailView: View {
    let entry: NutritionEntry
    let color: Color
    @ObservedObject var viewModel: NutritionDataManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    // Use nutrition pillar color
    private var nutritionColor: Color {
        MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Category icons on their own row (above food name to prevent wrapping)
                        if !entry.allCategories.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(entry.allCategories, id: \.self) { cat in
                                    Image(systemName: cat.icon)
                                        .font(.title2)
                                        .foregroundColor(nutritionColor)
                                }
                                Spacer()
                            }
                        }

                        // Food name
                        Text(entry.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        // Meal type and portion info
                        HStack(spacing: 8) {
                            if !entry.mealTypeDisplay.isEmpty {
                                Label(entry.mealTypeDisplay, systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            // Show portion grams for food entries, otherwise formatted value
                            if let portion = entry.portionGrams, portion > 0 {
                                Text("\(Int(portion)) g")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else if !entry.hasFoodInfo {
                                Text(entry.formattedValue)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Macro breakdown (if available)
                    if entry.hasMacroData {
                        Divider()

                        HStack(spacing: 0) {
                            if let cal = entry.calories, cal > 0 {
                                macroColumn("Calories", "\(Int(cal))", "flame.fill", .orange)
                                Divider().frame(height: 50)
                            }
                            macroColumn("Protein", formatMacroGrams(entry.proteinGrams ?? 0), "p.circle.fill", MiniMacroDonut.proteinColor)
                            Divider().frame(height: 50)
                            macroColumn("Carbs", formatMacroGrams(entry.carbGrams ?? 0), "c.circle.fill", MiniMacroDonut.carbColor)
                            Divider().frame(height: 50)
                            macroColumn("Fat", formatMacroGrams(entry.fatGrams ?? 0), "f.circle.fill", MiniMacroDonut.fatColor)
                        }

                        // Larger donut chart
                        MiniMacroDonut(
                            proteinGrams: entry.proteinGrams ?? 0,
                            carbGrams: entry.carbGrams ?? 0,
                            fatGrams: entry.fatGrams ?? 0,
                            size: 100
                        )
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    // Amount row - show portion grams for food entries, otherwise original value
                    HStack {
                        Text("Amount")
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let portion = entry.portionGrams, portion > 0 {
                                Text("\(Int(portion)) g")
                                    .fontWeight(.medium)
                            } else {
                                Text(entry.formattedValue)
                                    .fontWeight(.medium)
                                if entry.hasConvertedValue {
                                    Text("(\(entry.formattedCanonicalValue))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Categories already shown as icons at top - no need to repeat here

                    if let typeName = entry.typeName {
                        metadataRow("Type", typeName)
                    }

                    metadataRow("Date", formatDate(entry.startTime))
                    metadataRow("Time", formatTime(entry.startTime))
                    metadataRow("Added", formatDateTime(entry.createdAt))
                    metadataRow("Source", formatSource(entry.source))
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Delete button
                if entry.canDelete {
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
            }
            .padding()
        }
        .navigationTitle("Entry Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Entry?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteEntries([entry])
                    dismiss()
                }
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
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatSource(_ source: String) -> String {
        switch source.lowercased() {
        case "healthkit": return "Apple Health"
        case "wellpath", "wellpath_input": return "WellPath"
        default: return source.capitalized
        }
    }

    /// Format macro grams - show 1 decimal if not a whole number, otherwise show whole number
    private func formatMacroGrams(_ value: Double) -> String {
        if value == 0 {
            return "0g"
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number - show without decimal
            return "\(Int(value))g"
        } else {
            // Has decimal - show 1 decimal place
            return String(format: "%.1fg", value)
        }
    }
}

// MARK: - View Model

@MainActor
class NutritionDataManagementViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [NutritionEntry]] = [:]
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client
    private var referenceCache: [String: String] = [:]
    private var unitSymbolCache: [String: String] = [:]  // unit_id -> symbol (e.g., "fluid_ounce" -> "fl oz")

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadAllNutritionData() async {
        isLoading = true

        do {
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                isLoading = false
                return
            }

            let decoder = createDateDecoder()

            // All nutrition quantity types (including alcohol for caloric tracking)
            // Include carbGrams for macro donut calculation
            let nutritionTypes = [
                QuantityTypes.proteinGrams,
                QuantityTypes.carbGrams,
                QuantityTypes.vegetablesServings,
                QuantityTypes.fruitsServings,
                QuantityTypes.legumesServings,
                QuantityTypes.wholeGrainsServings,
                QuantityTypes.nutsSeedsServings,
                QuantityTypes.fiberGrams,
                QuantityTypes.fatGrams,
                QuantityTypes.waterMl,
                QuantityTypes.caffeineMg,
                QuantityTypes.alcoholDrinks
            ]

            // Query all nutrition samples
            let query = supabase
                .from("patient_quantity_samples")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .in("quantity_type", values: nutritionTypes)
                .order("start_time", ascending: false)

            let data = try await query.execute().data
            let samples = try decoder.decode([RawNutritionSample].self, from: data)

            print("Loaded \(samples.count) nutrition samples")

            // Collect all reference keys
            var referenceKeys: Set<String> = []
            for sample in samples {
                guard let metadata = sample.metadata else { continue }

                // Type keys
                for key in ["protein_type", "vegetables_type", "fruits_type", "legumes_type", "whole_grains_type", "nuts_seeds_type", "fiber_source", "fat_type", "caffeine_type", "alcohol_type"] {
                    if let value = metadata[key]?.stringValue {
                        referenceKeys.insert(value)
                    }
                }

                // Timing keys
                if let timing = metadata["food_timing"]?.stringValue ?? metadata["protein_timing"]?.stringValue {
                    referenceKeys.insert(timing)
                }
            }

            // Load reference display names
            if !referenceKeys.isEmpty {
                await loadReferenceDisplayNames(keys: Array(referenceKeys))
            }

            // Collect all unique unit_ids and load their display symbols
            var unitIds: Set<String> = []
            for sample in samples {
                if let unit = sample.quantityUnit {
                    unitIds.insert(unit)
                }
                if let canonicalUnit = sample.canonicalUnit {
                    unitIds.insert(canonicalUnit)
                }
            }
            if !unitIds.isEmpty {
                await loadUnitSymbols(unitIds: Array(unitIds))
            }

            // Collect all event_instance_ids to fetch food_log entries
            let eventIds = samples.compactMap { $0.eventInstanceId }
            let uniqueEventIds = Array(Set(eventIds))

            // Fetch food_log entries from patient_category_samples
            var foodLogLookup: [UUID: FoodLogInfo] = [:]
            if !uniqueEventIds.isEmpty {
                foodLogLookup = await loadFoodLogEntries(eventIds: uniqueEventIds, patientId: patientId)
            }

            // Group samples by event_instance_id
            // Key insight: ONE food entry creates MULTIPLE samples (protein, fat, fiber, servings, etc.)
            // We want ONE row per food entry, not one row per sample
            var samplesByEventId: [UUID: [RawNutritionSample]] = [:]
            var samplesWithoutEventId: [RawNutritionSample] = []

            for sample in samples {
                if let eventId = sample.eventInstanceId {
                    samplesByEventId[eventId, default: []].append(sample)
                } else {
                    // Samples without event_instance_id get their own entry (water, caffeine direct logs)
                    samplesWithoutEventId.append(sample)
                }
            }

            // Convert to entries - ONE entry per event_instance_id
            var entries: [NutritionEntry] = []
            let calendar = Calendar.current

            // Process grouped samples (food entries with multiple nutrients)
            for (eventId, eventSamples) in samplesByEventId {
                guard !eventSamples.isEmpty else { continue }

                // Collect data from ALL samples in this event
                var totalProtein: Double = 0
                var totalCarbs: Double = 0
                var totalFat: Double = 0
                var categories: Set<NutritionCategory> = []
                var typeName: String?
                var timingName: String?

                // Use the first sample as the base for common fields
                // But look for the "primary" sample (the one with food info or most meaningful type)
                let baseSample = eventSamples.first!

                for sample in eventSamples {
                    guard let quantityType = sample.quantityType else { continue }
                    let value = sample.canonicalValue ?? sample.quantityValue ?? 0
                    guard value > 0 else { continue }

                    // Accumulate macros
                    if quantityType == QuantityTypes.proteinGrams {
                        totalProtein += value
                    } else if quantityType == QuantityTypes.carbGrams {
                        totalCarbs += value
                    } else if quantityType == QuantityTypes.fatGrams {
                        totalFat += value
                    }

                    // Collect categories
                    let category = NutritionCategory.from(quantityType: quantityType)
                    if category != .all {
                        categories.insert(category)
                    }

                    // Extract type/timing from metadata (prefer first found)
                    if let metadata = sample.metadata {
                        if typeName == nil {
                            for key in ["protein_type", "vegetables_type", "fruits_type", "legumes_type", "whole_grains_type", "nuts_seeds_type", "fiber_source", "fat_type", "caffeine_type", "alcohol_type"] {
                                if let value = metadata[key]?.stringValue {
                                    typeName = referenceCache[value]
                                    break
                                }
                            }
                        }
                        if timingName == nil {
                            if let timing = metadata["food_timing"]?.stringValue ?? metadata["protein_timing"]?.stringValue {
                                timingName = referenceCache[timing]
                            }
                        }
                    }
                }

                // Get food info from food_log lookup
                let foodInfo = foodLogLookup[eventId]

                // Calculate calories from macros: P*4 + C*4 + F*9
                let calculatedCalories: Double? = {
                    let total = totalProtein * 4 + totalCarbs * 4 + totalFat * 9
                    return total > 0 ? total : nil
                }()

                // Sort categories for consistent display order
                let sortedCats = categories.sorted { $0.rawValue < $1.rawValue }

                // Determine the primary quantity type for display
                // Prioritize: protein > servings (veggies, fruits, etc.) > other
                let primaryQuantityType = eventSamples.first { $0.quantityType == QuantityTypes.proteinGrams }?.quantityType
                    ?? eventSamples.first { [QuantityTypes.vegetablesServings, QuantityTypes.fruitsServings, QuantityTypes.legumesServings, QuantityTypes.wholeGrainsServings].contains($0.quantityType ?? "") }?.quantityType
                    ?? baseSample.quantityType ?? "unknown"

                // Use the original entry values (quantity_value/quantity_unit) for display
                // These are what the user actually entered
                // Look up unit symbols from units_base for proper display (e.g., "fl oz" instead of "fluid_ounce")
                let displayVal = baseSample.quantityValue ?? baseSample.canonicalValue ?? 0
                let displayUnitStr = getUnitSymbol(for: baseSample.quantityUnit ?? baseSample.canonicalUnit)
                let canonicalVal = baseSample.canonicalValue ?? baseSample.quantityValue ?? 0
                let canonicalUnitStr = getUnitSymbol(for: baseSample.canonicalUnit ?? baseSample.quantityUnit)

                let entry = NutritionEntry(
                    id: baseSample.id,
                    patientId: patientId,
                    quantityType: primaryQuantityType,
                    startTime: baseSample.startTime,
                    createdAt: baseSample.createdAt ?? baseSample.startTime,
                    source: baseSample.source,
                    typeName: typeName,
                    timingName: timingName,
                    eventInstanceId: eventId,
                    displayValue: displayVal,
                    displayUnit: displayUnitStr,
                    canonicalValue: canonicalVal,
                    canonicalUnit: canonicalUnitStr,
                    proteinGrams: totalProtein > 0 ? totalProtein : nil,
                    carbGrams: totalCarbs > 0 ? totalCarbs : nil,
                    fatGrams: totalFat > 0 ? totalFat : nil,
                    foodName: foodInfo?.foodName,
                    mealType: foodInfo?.mealType ?? timingName,
                    portionGrams: foodInfo?.portionGrams,
                    calories: calculatedCalories,
                    allCategories: sortedCats
                )
                entries.append(entry)
            }

            // Process standalone samples (water, caffeine, etc. without event_instance_id)
            for sample in samplesWithoutEventId {
                guard let quantityType = sample.quantityType else { continue }
                let value = sample.canonicalValue ?? sample.quantityValue ?? 0
                guard value > 0 else { continue }

                // Get type name from metadata
                var typeName: String?
                var timingName: String?
                if let metadata = sample.metadata {
                    for key in ["protein_type", "vegetables_type", "fruits_type", "legumes_type", "whole_grains_type", "nuts_seeds_type", "fiber_source", "fat_type", "caffeine_type", "alcohol_type"] {
                        if let value = metadata[key]?.stringValue {
                            typeName = referenceCache[value]
                            break
                        }
                    }
                    if let timing = metadata["food_timing"]?.stringValue ?? metadata["protein_timing"]?.stringValue {
                        timingName = referenceCache[timing]
                    }
                }

                let category = NutritionCategory.from(quantityType: quantityType)
                let cats: [NutritionCategory] = category != .all ? [category] : []

                // Use the original entry values for display
                // Look up unit symbols from units_base for proper display
                let displayVal = sample.quantityValue ?? sample.canonicalValue ?? 0
                let displayUnitStr = getUnitSymbol(for: sample.quantityUnit ?? sample.canonicalUnit)
                let canonicalVal = sample.canonicalValue ?? sample.quantityValue ?? 0
                let canonicalUnitStr = getUnitSymbol(for: sample.canonicalUnit ?? sample.quantityUnit)

                let entry = NutritionEntry(
                    id: sample.id,
                    patientId: patientId,
                    quantityType: quantityType,
                    startTime: sample.startTime,
                    createdAt: sample.createdAt ?? sample.startTime,
                    source: sample.source,
                    typeName: typeName,
                    timingName: timingName,
                    eventInstanceId: nil,
                    displayValue: displayVal,
                    displayUnit: displayUnitStr,
                    canonicalValue: canonicalVal,
                    canonicalUnit: canonicalUnitStr,
                    proteinGrams: nil,
                    carbGrams: nil,
                    fatGrams: nil,
                    foodName: nil,
                    mealType: timingName,
                    portionGrams: nil,
                    calories: nil,
                    allCategories: cats
                )
                entries.append(entry)
            }

            // Sort entries by start time (descending) before grouping by date
            entries.sort { $0.startTime > $1.startTime }

            // Group by date
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.startTime)
            }

            print("Created \(entries.count) nutrition entries from \(samples.count) samples")

        } catch {
            print("Error loading nutrition data: \(error)")
        }

        isLoading = false
    }

    private func loadFoodLogEntries(eventIds: [UUID], patientId: UUID) async -> [UUID: FoodLogInfo] {
        var result: [UUID: FoodLogInfo] = [:]

        do {
            struct RawFoodLog: Codable {
                let eventInstanceId: UUID?
                let categoryValue: String?
                let metadata: [String: AnyJSON]?

                enum CodingKeys: String, CodingKey {
                    case eventInstanceId = "event_instance_id"
                    case categoryValue = "category_value"
                    case metadata
                }
            }

            let eventIdStrings = eventIds.map { $0.uuidString }
            let query = supabase
                .from("patient_category_samples")
                .select("event_instance_id, category_value, metadata")
                .eq("patient_id", value: patientId.uuidString)
                .eq("category_type", value: "food_log")
                .in("event_instance_id", values: eventIdStrings)

            let data = try await query.execute().data
            let decoder = createDateDecoder()
            let foodLogs = try decoder.decode([RawFoodLog].self, from: data)

            for log in foodLogs {
                guard let eventId = log.eventInstanceId else { continue }

                let foodName = log.metadata?["food_name"]?.stringValue
                let mealType = log.metadata?["meal_type"]?.stringValue ?? log.categoryValue
                let portionGrams = log.metadata?["portion_grams"]?.doubleValue

                result[eventId] = FoodLogInfo(
                    foodName: foodName,
                    mealType: mealType,
                    portionGrams: portionGrams
                )
            }

            print("Loaded \(result.count) food_log entries")

        } catch {
            print("Error loading food_log entries: \(error)")
        }

        return result
    }

    private func loadReferenceDisplayNames(keys: [String]) async {
        do {
            struct ReferenceData: Codable {
                let reference_key: String
                let display_name: String
            }

            let query = supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name")
                .in("reference_key", values: keys)

            let data = try await query.execute().data
            let decoder = createDateDecoder()
            let references = try decoder.decode([ReferenceData].self, from: data)

            for ref in references {
                referenceCache[ref.reference_key] = ref.display_name
            }

        } catch {
            print("Error loading reference data: \(error)")
        }
    }

    private func loadUnitSymbols(unitIds: [String]) async {
        do {
            struct UnitData: Codable {
                let unit_id: String
                let symbol: String
            }

            let query = supabase
                .from("units_base")
                .select("unit_id, symbol")
                .in("unit_id", values: unitIds)

            let data = try await query.execute().data
            let decoder = createDateDecoder()
            let units = try decoder.decode([UnitData].self, from: data)

            for unit in units {
                unitSymbolCache[unit.unit_id] = unit.symbol
            }

            print("Loaded \(units.count) unit symbols")

        } catch {
            print("Error loading unit symbols: \(error)")
        }
    }

    /// Get display symbol for a unit, with fallback to raw value
    private func getUnitSymbol(for unitId: String?) -> String {
        guard let unitId = unitId else { return "" }
        return unitSymbolCache[unitId] ?? unitId
    }

    func deleteEntries(_ entries: [NutritionEntry]) async {
        do {
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                return
            }

            // Collect unique event_instance_ids to delete all related data
            var eventIdsToDelete: Set<UUID> = []
            var singleEntryIds: [UUID] = []

            for entry in entries {
                guard entry.patientId == patientId else {
                    print("Attempted to delete entry that doesn't belong to current user")
                    continue
                }

                if let eventId = entry.eventInstanceId {
                    eventIdsToDelete.insert(eventId)
                } else {
                    // No event_instance_id, delete just this single entry
                    singleEntryIds.append(entry.id)
                }
            }

            // Delete all quantity samples for each event_instance_id
            for eventId in eventIdsToDelete {
                // Delete all quantity samples with this event_instance_id
                try await supabase
                    .from("patient_quantity_samples")
                    .delete()
                    .eq("event_instance_id", value: eventId.uuidString)
                    .eq("patient_id", value: patientId.uuidString)
                    .execute()

                // Delete the food_log entry from patient_category_samples
                try await supabase
                    .from("patient_category_samples")
                    .delete()
                    .eq("event_instance_id", value: eventId.uuidString)
                    .eq("patient_id", value: patientId.uuidString)
                    .execute()

                print("Deleted all samples for event_instance_id: \(eventId)")
            }

            // Delete single entries without event_instance_id
            for entryId in singleEntryIds {
                try await supabase
                    .from("patient_quantity_samples")
                    .delete()
                    .eq("id", value: entryId.uuidString)
                    .eq("patient_id", value: patientId.uuidString)
                    .execute()

                print("Deleted single nutrition sample: \(entryId)")
            }

            await loadAllNutritionData()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }

    private func createDateDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }
}

// MARK: - Raw Sample Model

private struct RawNutritionSample: Codable {
    let id: UUID
    let patientId: UUID
    let startTime: Date
    let endTime: Date
    let quantityValue: Double?
    let quantityUnit: String?
    let quantityType: String?
    let canonicalValue: Double?
    let canonicalUnit: String?
    let metadata: [String: AnyJSON]?
    let source: String
    let createdAt: Date?
    let eventInstanceId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case quantityType = "quantity_type"
        case canonicalValue = "canonical_value"
        case canonicalUnit = "canonical_unit"
        case metadata
        case source
        case createdAt = "created_at"
        case eventInstanceId = "event_instance_id"
    }
}

// MARK: - AnyJSON Extension (doubleValue and intValue - stringValue is in ProteinDataManagementView)

extension AnyJSON {
    var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .integer(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .integer(let value):
            return value
        case .double(let value):
            return Int(value)
        default:
            return nil
        }
    }
}

#Preview {
    NutritionDataManagementView(color: .orange)
}
