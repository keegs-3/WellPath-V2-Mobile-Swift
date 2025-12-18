//
//  WorkoutDataManagementView.swift
//  WellPath
//
//  Unified data management view for all workout entries
//  Shows all workouts with category filter tabs
//

import SwiftUI

// MARK: - Filter Options

enum WorkoutFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case cardio = "Cardio"
    case strength = "Strength"
    case hiit = "HIIT"
    case mobility = "Mobility"

    var id: String { rawValue }

    var quantityTypes: [String] {
        switch self {
        case .all: return ["cardio", "strength_training", "hiit", "mobility"]
        case .cardio: return ["cardio"]
        case .strength: return ["strength_training"]
        case .hiit: return ["hiit"]
        case .mobility: return ["mobility"]
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .cardio: return .red
        case .strength: return .orange
        case .hiit: return .purple
        case .mobility: return .teal
        }
    }

    var icon: String {
        switch self {
        case .all: return "figure.mixed.cardio"
        case .cardio: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .hiit: return "bolt.heart.fill"
        case .mobility: return "figure.flexibility"
        }
    }

    var categoryConfig: WorkoutCategoryConfig? {
        switch self {
        case .all: return nil
        case .cardio: return .cardio
        case .strength: return .strength
        case .hiit: return .hiit
        case .mobility: return .mobility
        }
    }
}

// MARK: - Unified Workout Data Management View

struct WorkoutDataManagementView: View {
    /// Initial filter (optional, defaults to .all)
    let initialFilter: WorkoutFilter?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutDataManagementViewModel()
    @State private var selectedFilter: WorkoutFilter = .all
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var editMode: EditMode = .inactive
    @State private var showingEntrySheet = false
    @State private var showingCategoryPicker = false
    @State private var selectedCategoryForEntry: WorkoutCategoryConfig?

    /// Unified init (no filter = all workouts)
    init() {
        self.initialFilter = nil
    }

    /// Init with pre-selected filter (backwards compatible)
    init(category: String, categoryName: String, color: Color) {
        switch category {
        case "cardio": self.initialFilter = .cardio
        case "strength": self.initialFilter = .strength
        case "hiit": self.initialFilter = .hiit
        case "mobility": self.initialFilter = .mobility
        default: self.initialFilter = .all
        }
    }

    /// Filtered entries based on selected tab
    private var filteredEntriesByDate: [Date: [WorkoutEntry]] {
        if selectedFilter == .all {
            return viewModel.entriesByDate
        }
        let allowedTypes = selectedFilter.quantityTypes
        var filtered: [Date: [WorkoutEntry]] = [:]
        for (date, entries) in viewModel.entriesByDate {
            let matchingEntries = entries.filter { allowedTypes.contains($0.quantityType) }
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
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if let config = selectedFilter.categoryConfig {
                            // Specific category selected - go directly to entry
                            selectedCategoryForEntry = config
                            showingEntrySheet = true
                        } else {
                            // "All" selected - show category picker
                            showingCategoryPicker = true
                        }
                    } label: {
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
        .onAppear {
            if let initial = initialFilter {
                selectedFilter = initial
            }
        }
        .task {
            await viewModel.loadAllEntries()
        }
        .sheet(isPresented: $showingCategoryPicker) {
            WorkoutCategoryPickerSheet { config in
                selectedCategoryForEntry = config
                showingCategoryPicker = false
                showingEntrySheet = true
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingEntrySheet) {
            if let config = selectedCategoryForEntry {
                WorkoutEntryView(config: config)
            }
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
                ForEach(WorkoutFilter.allCases) { filter in
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
                    .fill(selectedFilter.color.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: selectedFilter.icon)
                    .font(.system(size: 36))
                    .foregroundColor(selectedFilter.color)
            }

            Text(selectedFilter == .all ? "No Workouts" : "No \(selectedFilter.rawValue) Workouts")
                .font(.title3)
                .fontWeight(.medium)

            Text("Tap + to log a workout")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
                            // Edit mode: tap to select
                            WorkoutEntryRow(
                                entry: entry,
                                isSelected: selectedEntries.contains(entry.id),
                                editMode: editMode
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedEntries.contains(entry.id) {
                                    selectedEntries.remove(entry.id)
                                } else {
                                    selectedEntries.insert(entry.id)
                                }
                            }
                        } else {
                            // Normal mode: navigate to detail
                            NavigationLink(destination: WorkoutDetailView(entry: entry, onDelete: {
                                Task {
                                    await viewModel.deleteEntries(ids: [entry.id])
                                }
                            })) {
                                WorkoutEntryRow(
                                    entry: entry,
                                    isSelected: false,
                                    editMode: editMode
                                )
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(formatSectionDate(date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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

    // MARK: - Helper Methods

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

struct WorkoutEntryRow: View {
    let entry: WorkoutEntry
    let isSelected: Bool
    let editMode: EditMode

    private var categoryColor: Color {
        switch entry.quantityType {
        case "cardio": return .red
        case "strength_training": return .orange
        case "hiit": return .purple
        case "mobility": return .teal
        default: return .blue
        }
    }

    private var categoryIcon: String {
        switch entry.quantityType {
        case "cardio": return "figure.run"
        case "strength_training": return "dumbbell.fill"
        case "hiit": return "bolt.heart.fill"
        case "mobility": return "figure.flexibility"
        default: return "figure.mixed.cardio"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection circle in edit mode
            if editMode == .active {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? categoryColor : .secondary)
                    .font(.title2)
            }

            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // Entry details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    if let duration = entry.durationMinutes {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(categoryColor)
                    }

                    Text(formatTime(entry.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Source indicator and chevron
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.caption)
                    .foregroundColor(categoryColor)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins) min"
        }
    }
}

// MARK: - View Model

@MainActor
class WorkoutDataManagementViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [WorkoutEntry]] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadAllEntries() async {
        isLoading = true
        error = nil

        do {
            guard let patientId = try? await supabase.auth.session.user.id else {
                isLoading = false
                return
            }

            let allTypes = ["cardio", "strength_training", "hiit", "mobility"]

            let rows: [WorkoutSampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("id, quantity_type, quantity_value, start_time, end_time, source, metadata")
                .eq("patient_id", value: patientId.uuidString)
                .in("quantity_type", values: allTypes)
                .order("start_time", ascending: false)
                .execute()
                .value

            // Group by date
            let calendar = Calendar.current
            var grouped: [Date: [WorkoutEntry]] = [:]

            for row in rows {
                let entry = WorkoutEntry(from: row)
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
            print("❌ Error loading workout entries: \(error)")
        }
    }

    func deleteEntries(ids: [UUID]) async {
        do {
            for id in ids {
                try await supabase
                    .from("patient_quantity_samples")
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
            print("❌ Error deleting entries: \(error)")
        }
    }
}

// MARK: - Models

struct WorkoutSampleRow: Codable {
    let id: UUID
    let quantityType: String
    let quantityValue: Double?
    let startTime: Date
    let endTime: Date?
    let source: String?
    let metadata: WorkoutMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case quantityType = "quantity_type"
        case quantityValue = "quantity_value"
        case startTime = "start_time"
        case endTime = "end_time"
        case source
        case metadata
    }
}

struct WorkoutMetadata: Codable {
    let workoutSubtype: String?
    let intensity: String?
    let muscleGroups: [String]?
    let caloriesBurned: Double?
    let distanceMeters: Double?

    enum CodingKeys: String, CodingKey {
        case workoutSubtype = "workout_subtype"
        case intensity
        case muscleGroups = "muscle_groups"
        case caloriesBurned = "calories_burned"
        case distanceMeters = "distance_meters"
    }
}

struct WorkoutEntry: Identifiable {
    let id: UUID
    let quantityType: String
    let durationMinutes: Double?
    let startTime: Date
    let endTime: Date?
    let workoutSubtype: String?
    let intensity: String?
    let caloriesBurned: Double?
    let distanceMeters: Double?
    let source: String?

    var displayName: String {
        if let subtype = workoutSubtype {
            return subtype.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return quantityType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    init(from row: WorkoutSampleRow) {
        self.id = row.id
        self.quantityType = row.quantityType
        self.durationMinutes = row.quantityValue
        self.startTime = row.startTime
        self.endTime = row.endTime
        self.workoutSubtype = row.metadata?.workoutSubtype
        self.intensity = row.metadata?.intensity
        self.caloriesBurned = row.metadata?.caloriesBurned
        self.distanceMeters = row.metadata?.distanceMeters
        self.source = row.source
    }
}

// MARK: - Category Picker Sheet

struct WorkoutCategoryPickerSheet: View {
    let onSelect: (WorkoutCategoryConfig) -> Void

    @Environment(\.dismiss) private var dismiss

    private let categories: [WorkoutCategoryConfig] = [
        .cardio, .strength, .hiit, .mobility
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Workout Type")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(categories) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(category.color.opacity(0.15))
                                        .frame(width: 60, height: 60)

                                    Image(systemName: category.icon)
                                        .font(.system(size: 28))
                                        .foregroundColor(category.color)
                                }

                                Text(category.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WorkoutDataManagementView()
}
