//
//  ProteinDataManagementView.swift
//  WellPath
//
//  Protein-specific data management view showing entries grouped by date with source
//

import SwiftUI
import Supabase

struct ProteinDataManagementView: View {
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProteinDataManagementViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var expandedDates: Set<Date> = []
    @State private var showingDateFilter = false
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

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
                .navigationTitle("All Protein Data")
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
                .alert("Delete Protein Entries?", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        selectedEntries.removeAll()
                    }
                    Button("Delete", role: .destructive) {
                        Task {
                            await deleteSelectedEntries()
                        }
                    }
                } message: {
                    Text("This will permanently delete \(selectedEntries.count) protein entry(ies).")
                }
                .task {
                    await viewModel.loadProteinData()
                    // Expand all dates on load
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
            Text("No protein data found")
                .foregroundColor(.secondary)
                .padding()
        } else {
            proteinDataList
        }
    }

    private var proteinDataList: some View {
        List {
            ForEach(filteredDates, id: \.self) { date in
                Section {
                    if expandedDates.contains(date) {
                        ForEach(viewModel.entriesByDate[date] ?? []) { entry in
                            proteinEntryRow(entry: entry)
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
    private func proteinEntryRow(entry: ProteinEntry) -> some View {
        if editMode == .inactive {
            // Normal mode: NavigationLink to detail
            NavigationLink(destination: ProteinEntryDetailView(entry: entry, color: color, viewModel: viewModel)) {
                ProteinEntryRow(entry: entry, color: color)
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
            // Edit mode: Button to select/deselect
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

                    ProteinEntryRow(entry: entry, color: color)
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
                    // Select all deletable entries
                    for (_, entries) in viewModel.entriesByDate {
                        for entry in entries where entry.canDelete {
                            selectedEntries.insert(entry.id)
                        }
                    }
                } else {
                    // Delete selected
                    showingDeleteAlert = true
                }
            }
            .foregroundColor(selectedEntries.isEmpty ? .blue : .red)
        } else {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
            }
        }
    }

    @ViewBuilder
    private var filterButton: some View {
        if !viewModel.sortedDates.isEmpty && editMode == .inactive {
            Button(action: {
                showingDateFilter = true
            }) {
                Image(systemName: (filterStartDate != nil || filterEndDate != nil) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundColor(color)
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

struct ProteinEntryRow: View {
    let entry: ProteinEntry
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(entry.proteinGrams))g")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                // Type and timing on second line
                if let typeName = entry.proteinTypeName, let timing = entry.timingName {
                    Text("\(typeName) / \(timing)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let typeName = entry.proteinTypeName {
                    Text(typeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let timing = entry.timingName {
                    Text(timing)
                        .font(.caption)
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
                // WellPath logo in rounded square with gradient
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

struct ProteinEntryDetailView: View {
    let entry: ProteinEntry
    let color: Color
    @ObservedObject var viewModel: ProteinDataManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Entry details card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Protein Entry Details")
                        .font(.headline)

                    DetailRow(label: "Amount", value: "\(Int(entry.proteinGrams))g")

                    if let typeName = entry.proteinTypeName {
                        DetailRow(label: "Protein Type", value: typeName)
                    }

                    DetailRow(label: "Date", value: formatDate(entry.entryDate))

                    DetailRow(label: "Source", value: formatSource(entry.source))

                    if let timing = entry.timingName {
                        DetailRow(label: "Meal Timing", value: timing)
                    }
                    DetailRow(label: "Date Added", value: formatDateTime(entry.createdAt))
                    DetailRow(label: "Entry ID", value: entry.id.uuidString)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                // Delete button
                if entry.canDelete {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
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
                    await deleteEntry()
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func deleteEntry() async {
        await viewModel.deleteEntries([entry])
        dismiss()
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
        case "healthkit":
            return "HealthKit"
        case "wellpath", "wellpath_input":
            return "WellPath"
        default:
            return source.capitalized
        }
    }
}

// MARK: - View Model

@MainActor
class ProteinDataManagementViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [ProteinEntry]] = [:]
    @Published var isLoading = false

    let supabase = SupabaseManager.shared.client

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadProteinData() async {
        isLoading = true

        do {
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                isLoading = false
                return
            }

            // Custom decoder for date handling
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

            // Query patient_samples for protein entries
            let query = supabase
                .from("patient_samples")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: QuantityTypes.proteinGrams)
                .order("start_time", ascending: false)

            let data = try await query.execute().data
            let samples = try decoder.decode([RawProteinSample].self, from: data)

            print("✅ Loaded \(samples.count) protein samples from patient_samples")

            // Build lookup cache for reference keys to display names
            var typeDisplayNames: [String: String] = [:]
            var timingDisplayNames: [String: String] = [:]

            // Collect unique type and timing keys from metadata
            var typeKeys: Set<String> = []
            var timingKeys: Set<String> = []

            for sample in samples {
                if let typeKey = sample.metadata?[ProteinMetadataKeys.proteinType]?.stringValue {
                    typeKeys.insert(typeKey)
                }
                if let timingKey = sample.metadata?[FoodMetadataKeys.foodTiming]?.stringValue {
                    timingKeys.insert(timingKey)
                }
            }

            // Fetch display names for types
            if !typeKeys.isEmpty {
                struct ReferenceData: Codable {
                    let reference_key: String
                    let display_name: String
                }

                let refQuery = supabase
                    .from("data_entry_fields_reference")
                    .select("reference_key, display_name")
                    .in("reference_key", values: Array(typeKeys))

                let refData = try await refQuery.execute().data
                let references = try decoder.decode([ReferenceData].self, from: refData)

                for ref in references {
                    typeDisplayNames[ref.reference_key] = ref.display_name
                }
            }

            // Fetch display names for timings
            if !timingKeys.isEmpty {
                struct ReferenceData: Codable {
                    let reference_key: String
                    let display_name: String
                }

                let refQuery = supabase
                    .from("data_entry_fields_reference")
                    .select("reference_key, display_name")
                    .in("reference_key", values: Array(timingKeys))

                let refData = try await refQuery.execute().data
                let references = try decoder.decode([ReferenceData].self, from: refData)

                for ref in references {
                    timingDisplayNames[ref.reference_key] = ref.display_name
                }
            }

            // Convert samples to ProteinEntry models
            var proteinEntries: [ProteinEntry] = []

            for sample in samples {
                guard let quantityValue = sample.quantityValue else { continue }

                // Extract type and timing from metadata
                let typeKey = sample.metadata?[ProteinMetadataKeys.proteinType]?.stringValue
                let timingKey = sample.metadata?[FoodMetadataKeys.foodTiming]?.stringValue

                let proteinEntry = ProteinEntry(
                    id: sample.id,
                    patientId: patientId,
                    entryDate: sample.startTime,
                    createdAt: sample.createdAt ?? sample.startTime,
                    source: sample.source,
                    proteinGrams: quantityValue,
                    proteinTypeKey: typeKey,
                    proteinTypeName: typeKey.flatMap { typeDisplayNames[$0] },
                    timingKey: timingKey,
                    timingName: timingKey.flatMap { timingDisplayNames[$0] }
                )
                proteinEntries.append(proteinEntry)
            }

            print("✅ Assembled \(proteinEntries.count) protein entries")

            // Group by date
            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: proteinEntries) { entry in
                calendar.startOfDay(for: entry.entryDate)
            }

        } catch {
            print("Error loading protein data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [ProteinEntry]) async {
        do {
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                return
            }

            // Delete from patient_samples by sample ID
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

                print("Deleted protein sample: \(entry.id)")
            }

            // Reload data
            await loadProteinData()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Models

/// Raw sample data from patient_samples table
struct RawProteinSample: Codable {
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

/// Protein entry view model
struct ProteinEntry: Identifiable {
    let id: UUID
    let patientId: UUID
    let entryDate: Date
    let createdAt: Date
    let source: String
    let proteinGrams: Double
    let proteinTypeKey: String?
    let proteinTypeName: String?
    let timingKey: String?
    let timingName: String?

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }
}

// MARK: - AnyJSON String Extension

extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
}
