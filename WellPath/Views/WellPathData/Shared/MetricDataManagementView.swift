//
//  MetricDataManagementView.swift
//  WellPath
//
//  Unified data management view for all tracked metrics
//  Supports simple values (servings, grams, steps) and duration-based entries
//

import SwiftUI
import Supabase

// MARK: - Metric Configuration

/// Configuration for how a metric's data should be displayed and managed
struct MetricDataConfig {
    let metricName: String
    let quantityTypes: [String]
    let color: Color
    let icon: String

    /// How to format the primary value for display
    let valueFormatter: (Double, String?) -> String

    /// Metadata fields to display (key in metadata, display label, reference category for lookup)
    let metadataFields: [MetadataFieldConfig]

    /// Whether this is a duration-based metric (shows start/end times)
    let isDuration: Bool

    struct MetadataFieldConfig {
        let metadataKey: String
        let displayLabel: String
        let referenceCategory: String?  // If nil, display raw value

        init(_ metadataKey: String, label: String, category: String? = nil) {
            self.metadataKey = metadataKey
            self.displayLabel = label
            self.referenceCategory = category
        }
    }
}

// MARK: - Predefined Configurations

extension MetricDataConfig {

    // MARK: - Simple Value Metrics (Nutrition)

    static func legumes(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Legumes",
            quantityTypes: [QuantityTypes.legumesServings],
            color: color,
            icon: "leaf.fill",
            valueFormatter: { value, _ in String(format: "%.1f servings", value) },
            metadataFields: [
                MetadataFieldConfig("legumes_type", label: "Type", category: "legumes_types"),
                MetadataFieldConfig("food_timing", label: "Meal", category: "meal_timings")
            ],
            isDuration: false
        )
    }

    static func vegetables(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Vegetables",
            quantityTypes: [QuantityTypes.vegetablesServings],
            color: color,
            icon: "carrot.fill",
            valueFormatter: { value, _ in String(format: "%.1f servings", value) },
            metadataFields: [
                MetadataFieldConfig("vegetables_type", label: "Type", category: "vegetables_types"),
                MetadataFieldConfig("food_timing", label: "Meal", category: "meal_timings")
            ],
            isDuration: false
        )
    }

    static func wholeGrains(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Whole Grains",
            quantityTypes: [QuantityTypes.wholeGrainsServings],
            color: color,
            icon: "basket.fill",
            valueFormatter: { value, _ in String(format: "%.1f servings", value) },
            metadataFields: [
                MetadataFieldConfig("whole_grains_type", label: "Type", category: "whole_grains_types"),
                MetadataFieldConfig("food_timing", label: "Meal", category: "meal_timings")
            ],
            isDuration: false
        )
    }

    static func fruits(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Fruits",
            quantityTypes: [QuantityTypes.fruitsServings],
            color: color,
            icon: "apple.logo",
            valueFormatter: { value, _ in String(format: "%.1f servings", value) },
            metadataFields: [
                MetadataFieldConfig("fruits_type", label: "Type", category: "fruits_types"),
                MetadataFieldConfig("food_timing", label: "Meal", category: "meal_timings")
            ],
            isDuration: false
        )
    }

    static func protein(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Protein",
            quantityTypes: [QuantityTypes.proteinGrams],
            color: color,
            icon: "fork.knife",
            valueFormatter: { value, _ in "\(Int(value))g" },
            metadataFields: [
                MetadataFieldConfig("protein_type", label: "Type", category: "protein_types"),
                MetadataFieldConfig("protein_timing", label: "Meal", category: "meal_timings")
            ],
            isDuration: false
        )
    }

    // MARK: - Simple Value Metrics (Movement)

    static func steps(color: Color) -> MetricDataConfig {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        return MetricDataConfig(
            metricName: "Steps",
            quantityTypes: [QuantityTypes.steps],
            color: color,
            icon: "figure.walk",
            valueFormatter: { value, _ in
                formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
            },
            metadataFields: [],  // Steps typically have no metadata
            isDuration: false
        )
    }

    // MARK: - Biometrics

    static func bodyweight(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Body Weight",
            quantityTypes: [QuantityTypes.weight],
            color: color,
            icon: "scalemass",
            valueFormatter: { value, unit in
                // Value is stored in canonical unit (pounds)
                let displayUnit = unit ?? "lb"
                if displayUnit == "kg" || displayUnit == "kilogram" {
                    return String(format: "%.1f kg", value)
                } else {
                    return String(format: "%.1f lb", value)
                }
            },
            metadataFields: [],  // Body weight has no metadata
            isDuration: false
        )
    }

    // MARK: - Duration Metrics

    static func strengthTraining(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Strength Training",
            quantityTypes: [QuantityTypes.strengthDuration],
            color: color,
            icon: "dumbbell.fill",
            valueFormatter: { value, _ in
                let totalMinutes = Int(value)
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                if hours > 0 {
                    return "\(hours)h \(minutes)m"
                } else {
                    return "\(minutes) min"
                }
            },
            metadataFields: [
                MetadataFieldConfig("workout_type", label: "Type", category: "strength_types"),
                MetadataFieldConfig("muscle_groups", label: "Muscle Group", category: "muscle_groups"),
                MetadataFieldConfig("intensity", label: "Intensity", category: "intensity_levels")
            ],
            isDuration: true
        )
    }

    static func cardio(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Cardio",
            quantityTypes: [QuantityTypes.cardioDuration],
            color: color,
            icon: "heart.fill",
            valueFormatter: { value, _ in
                let totalMinutes = Int(value)
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                if hours > 0 {
                    return "\(hours)h \(minutes)m"
                } else {
                    return "\(minutes) min"
                }
            },
            metadataFields: [
                MetadataFieldConfig("cardio_type", label: "Type", category: "cardio_types"),
                MetadataFieldConfig("intensity", label: "Intensity", category: "intensity_levels")
            ],
            isDuration: true
        )
    }

    static func yoga(color: Color) -> MetricDataConfig {
        MetricDataConfig(
            metricName: "Yoga",
            quantityTypes: [QuantityTypes.yogaDuration],
            color: color,
            icon: "figure.yoga",
            valueFormatter: { value, _ in
                let totalMinutes = Int(value)
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                if hours > 0 {
                    return "\(hours)h \(minutes)m"
                } else {
                    return "\(minutes) min"
                }
            },
            metadataFields: [
                MetadataFieldConfig("yoga_type", label: "Type", category: "yoga_types")
            ],
            isDuration: true
        )
    }
}

// MARK: - Main View

struct MetricDataManagementView: View {
    let config: MetricDataConfig

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MetricDataManagementViewModel
    @State private var editMode: EditMode = .inactive
    @State private var expandedDates: Set<Date> = []
    @State private var showingDateFilter = false
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    init(config: MetricDataConfig) {
        self.config = config
        _viewModel = StateObject(wrappedValue: MetricDataManagementViewModel(config: config))
    }

    var filteredDates: [Date] {
        var dates = viewModel.sortedDates
        if let start = filterStartDate {
            dates = dates.filter { $0 >= Calendar.current.startOfDay(for: start) }
        }
        if let end = filterEndDate {
            dates = dates.filter { $0 <= Calendar.current.startOfDay(for: end) }
        }
        return dates
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("All \(config.metricName) Data")
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
                    DateFilterView(startDate: $filterStartDate, endDate: $filterEndDate, color: config.color)
                }
                .alert("Delete \(config.metricName) Entries?", isPresented: $showingDeleteAlert) {
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
                    await viewModel.loadData()
                    expandedDates = Set(filteredDates)
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
                .padding()
        } else if filteredDates.isEmpty {
            Text("No \(config.metricName.lowercased()) data found")
                .foregroundColor(.secondary)
                .padding()
        } else {
            dataList
        }
    }

    private var dataList: some View {
        List {
            ForEach(filteredDates, id: \.self) { date in
                Section {
                    if expandedDates.contains(date) {
                        ForEach(viewModel.entriesByDate[date] ?? []) { entry in
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
    private func entryRow(entry: MetricEntry) -> some View {
        if editMode == .inactive {
            NavigationLink(destination: MetricEntryDetailView(entry: entry, config: config, viewModel: viewModel)) {
                MetricEntryRow(entry: entry, config: config)
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
                    MetricEntryRow(entry: entry, config: config)
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

    @ViewBuilder
    private var leadingToolbarButton: some View {
        if editMode == .active {
            Button(selectedEntries.isEmpty ? "Select All" : "Delete (\(selectedEntries.count))") {
                if selectedEntries.isEmpty {
                    for (_, entries) in viewModel.entriesByDate {
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
                    .foregroundColor(config.color)
            }
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if !viewModel.sortedDates.isEmpty {
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

struct MetricEntryRow: View {
    let entry: MetricEntry
    let config: MetricDataConfig

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                // Primary value
                Text(config.valueFormatter(entry.value, entry.unit))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                // Metadata summary
                if !entry.displayMetadata.isEmpty {
                    Text(entry.displayMetadata.map { $0.value }.joined(separator: " / "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Time for duration metrics
                if config.isDuration {
                    Text(formatTime(entry.startTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: some View {
        Group {
            if entry.source == "healthkit" {
                Image(systemName: "heart.text.square.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.4, blue: 0.5), Color(red: 1.0, green: 0.2, blue: 0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 24, height: 24)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.95), Color(white: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 24, height: 24)

                    Image("black_green")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                .frame(width: 24, height: 24)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Entry Detail View

struct MetricEntryDetailView: View {
    let entry: MetricEntry
    let config: MetricDataConfig
    @ObservedObject var viewModel: MetricDataManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(config.metricName) Entry Details")
                        .font(.headline)

                    MetricDetailRow(label: "Value", value: config.valueFormatter(entry.value, entry.unit))

                    // Display all resolved metadata
                    ForEach(entry.displayMetadata, id: \.key) { item in
                        MetricDetailRow(label: item.label, value: item.value)
                    }

                    MetricDetailRow(label: "Date", value: formatDate(entry.startTime))

                    if config.isDuration {
                        MetricDetailRow(label: "Start Time", value: formatTime(entry.startTime))
                        MetricDetailRow(label: "End Time", value: formatTime(entry.endTime))
                    }

                    MetricDetailRow(label: "Source", value: formatSource(entry.source))
                    MetricDetailRow(label: "Date Added", value: formatDateTime(entry.createdAt))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                if entry.canDelete {
                    Button(action: { showingDeleteAlert = true }) {
                        Label("Delete Entry", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
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
            Text("This cannot be undone.")
        }
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

    private func formatSource(_ source: String) -> String {
        switch source.lowercased() {
        case "healthkit": return "Apple Health"
        case "wellpath", "wellpath_input": return "WellPath"
        default: return source.capitalized
        }
    }
}

struct MetricDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - View Model

@MainActor
class MetricDataManagementViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [MetricEntry]] = [:]
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client
    private let config: MetricDataConfig
    private var referenceCache: [String: String] = [:]  // reference_key -> display_name

    init(config: MetricDataConfig) {
        self.config = config
    }

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadData() async {
        isLoading = true

        do {
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                isLoading = false
                return
            }

            let decoder = createDateDecoder()

            // Query patient_samples
            let query = supabase
                .from("patient_samples")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .in("quantity_type", values: config.quantityTypes)
                .order("start_time", ascending: false)

            let data = try await query.execute().data
            let samples = try decoder.decode([RawMetricSample].self, from: data)

            print("Loaded \(samples.count) \(config.metricName) samples")

            // Collect all reference keys that need lookup
            var referenceKeysToLookup: Set<String> = []
            for sample in samples {
                guard let metadata = sample.metadata else { continue }
                for field in config.metadataFields where field.referenceCategory != nil {
                    if let key = metadata[field.metadataKey]?.stringValue {
                        referenceKeysToLookup.insert(key)
                    }
                }
            }

            // Batch lookup reference display names
            if !referenceKeysToLookup.isEmpty {
                await loadReferenceDisplayNames(keys: Array(referenceKeysToLookup))
            }

            // Convert samples to MetricEntry models
            var entries: [MetricEntry] = []

            for sample in samples {
                guard let quantityValue = sample.quantityValue else { continue }

                // Resolve metadata display values
                var displayMetadata: [MetricEntry.DisplayMetadataItem] = []

                for field in config.metadataFields {
                    if let rawValue = sample.metadata?[field.metadataKey]?.stringValue {
                        let displayValue: String
                        if field.referenceCategory != nil {
                            displayValue = referenceCache[rawValue] ?? rawValue
                        } else {
                            displayValue = rawValue
                        }
                        displayMetadata.append(MetricEntry.DisplayMetadataItem(
                            key: field.metadataKey,
                            label: field.displayLabel,
                            value: displayValue
                        ))
                    }
                }

                let entry = MetricEntry(
                    id: sample.id,
                    patientId: patientId,
                    value: quantityValue,
                    unit: sample.quantityUnit,
                    startTime: sample.startTime,
                    endTime: sample.endTime,
                    source: sample.source,
                    createdAt: sample.createdAt ?? sample.startTime,
                    displayMetadata: displayMetadata
                )
                entries.append(entry)
            }

            // Group by date
            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.startTime)
            }

        } catch {
            print("Error loading \(config.metricName) data: \(error)")
        }

        isLoading = false
    }

    private func loadReferenceDisplayNames(keys: [String]) async {
        do {
            struct ReferenceData: Codable {
                let reference_key: String
                let display_name: String
            }

            let query = supabase
                .from("data_entry_fields_reference")
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

    func deleteEntries(_ entries: [MetricEntry]) async {
        do {
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                return
            }

            for entry in entries {
                guard entry.patientId == patientId else {
                    print("Attempted to delete entry that doesn't belong to current user")
                    continue
                }

                try await supabase
                    .from("patient_samples")
                    .delete()
                    .eq("id", value: entry.id.uuidString)
                    .eq("patient_id", value: patientId.uuidString)
                    .execute()

                print("Deleted \(config.metricName) sample: \(entry.id)")
            }

            await loadData()

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

// MARK: - Models

struct RawMetricSample: Codable {
    let id: UUID
    let patientId: UUID
    let sampleType: String
    let startTime: Date
    let endTime: Date
    let quantityValue: Double?
    let quantityUnit: String?
    let quantityType: String?
    let metadata: [String: AnyJSON]?
    let source: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case sampleType = "sample_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case quantityType = "quantity_type"
        case metadata
        case source
        case createdAt = "created_at"
    }
}

struct MetricEntry: Identifiable {
    let id: UUID
    let patientId: UUID
    let value: Double
    let unit: String?
    let startTime: Date
    let endTime: Date
    let source: String
    let createdAt: Date
    let displayMetadata: [DisplayMetadataItem]

    struct DisplayMetadataItem {
        let key: String
        let label: String
        let value: String
    }

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }
}

// Note: DateFilterView is defined in SleepDataManagementView.swift and reused here
