//
//  BodyWeightDataManagementView.swift
//  WellPath
//
//  Data management view for Body Weight entries
//  Lists all entries with edit/delete capabilities
//

import SwiftUI
import Supabase

struct BodyWeightDataManagementView: View {
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BodyWeightDataViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var expandedDates: Set<Date> = []
    @State private var showingDateFilter = false
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    private let icon = "scalemass"

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
                .navigationTitle("All Body Weight Data")
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
                .alert("Delete Body Weight Entries?", isPresented: $showingDeleteAlert) {
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
            Text("No body weight data found")
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
    private func entryRow(entry: BodyWeightEntry) -> some View {
        if editMode == .inactive {
            NavigationLink(destination: BodyWeightEntryDetailView(entry: entry, viewModel: viewModel, color: color)) {
                BodyWeightEntryRow(entry: entry, icon: icon)
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
                    BodyWeightEntryRow(entry: entry, icon: icon)
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

struct BodyWeightEntryRow: View {
    let entry: BodyWeightEntry
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(entry.value))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(entry.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(formatTime(entry.recordedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Entry Detail View

struct BodyWeightEntryDetailView: View {
    let entry: BodyWeightEntry
    @ObservedObject var viewModel: BodyWeightDataViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Body Weight Entry Details")
                        .font(.headline)

                    DetailRow(label: "Value", value: "\(formatValue(entry.value)) \(entry.unit)")
                    DetailRow(label: "Date", value: formatDate(entry.recordedAt))
                    DetailRow(label: "Time", value: formatTime(entry.recordedAt))
                    DetailRow(label: "Source", value: formatSource(entry.source))
                    DetailRow(label: "Date Added", value: formatDateTime(entry.createdAt))
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

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
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

// MARK: - View Model

@MainActor
class BodyWeightDataViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [BodyWeightEntry]] = [:]
    @Published var isLoading = false
    @Published var preferredUnit: WeightDisplayUnit = .lb

    private let supabase = SupabaseManager.shared.client
    private let unitService = UnitConversionService.shared

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadData() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // Load user's unit preferences
            await unitService.loadUserPreferences()
            preferredUnit = unitService.preferredWeightUnit

            // Query patient_quantity_samples for bodyweight
            struct PatientSampleRow: Codable {
                let id: UUID
                let quantityValue: Double?
                let quantityUnit: String?
                let startTime: Date
                let source: String
                let createdAt: Date?

                enum CodingKeys: String, CodingKey {
                    case id
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                    case source
                    case createdAt = "created_at"
                }
            }

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

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            let data = try await supabase
                .from("patient_quantity_samples")
                .select()
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: QuantityTypes.weight)
                .order("start_time", ascending: false)
                .execute()
                .data

            let samples = try decoder.decode([PatientSampleRow].self, from: data)

            // Convert to BodyWeightEntry with user's preferred unit
            var entries: [BodyWeightEntry] = []
            for sample in samples {
                guard let value = sample.quantityValue else { continue }

                // Convert to user's preferred unit
                let storedUnit = sample.quantityUnit ?? "kilogram"
                let converted = unitService.convertWeightToPreferred(value: value, fromUnit: storedUnit)

                let entry = BodyWeightEntry(
                    id: sample.id,
                    value: converted.value,
                    unit: converted.unit,
                    recordedAt: sample.startTime,
                    source: sample.source,
                    createdAt: sample.createdAt ?? sample.startTime
                )
                entries.append(entry)
            }

            // Group by date
            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.recordedAt)
            }

            print("Loaded \(entries.count) body weight entries in \(preferredUnit.rawValue)")

        } catch {
            print("Error loading body weight data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [BodyWeightEntry]) async {
        do {
            let patientId = try await supabase.auth.session.user.id

            for entry in entries {
                try await supabase
                    .from("patient_quantity_samples")
                    .delete()
                    .eq("id", value: entry.id)
                    .eq("patient_id", value: patientId)
                    .execute()

                print("Deleted body weight sample: \(entry.id)")
            }

            await loadData()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Model

struct BodyWeightEntry: Identifiable {
    let id: UUID
    let value: Double
    let unit: String
    let recordedAt: Date
    let source: String
    let createdAt: Date

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }
}

#Preview {
    BodyWeightDataManagementView(color: .cyan)
}
