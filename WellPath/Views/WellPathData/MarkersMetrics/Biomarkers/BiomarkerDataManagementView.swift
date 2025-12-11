//
//  BiomarkerDataManagementView.swift
//  WellPath
//
//  Data management view for biomarker entries
//  Shows history from patient_clinical_samples with swipe-to-delete and bulk delete
//

import SwiftUI
import Supabase

// MARK: - Data Management View

struct BiomarkerDataManagementView: View {
    let biomarkerName: String
    let sampleClinicalType: String  // The actual quantity_type for patient_samples queries
    let unit: String
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BiomarkerHistoryViewModel
    @StateObject private var rangeLoader = BiomarkerValueLoader()
    @State private var expandedDates: Set<Date> = []
    @State private var editMode: EditMode = .inactive
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    init(biomarkerName: String, sampleClinicalType: String, unit: String, color: Color) {
        self.biomarkerName = biomarkerName
        self.sampleClinicalType = sampleClinicalType
        self.unit = unit
        self.color = color
        _viewModel = StateObject(wrappedValue: BiomarkerHistoryViewModel(
            biomarkerName: biomarkerName,
            sampleClinicalType: sampleClinicalType,
            unit: unit
        ))
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("All \(biomarkerName) Data")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
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

                    ToolbarItem(placement: .primaryAction) {
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
                }
                .alert("Delete \(biomarkerName) Entries?", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        selectedEntries.removeAll()
                    }
                    Button("Delete", role: .destructive) {
                        Task {
                            let entriesToDelete = viewModel.entriesByDate.values
                                .flatMap { $0 }
                                .filter { selectedEntries.contains($0.id) }
                            await viewModel.deleteEntries(entriesToDelete)
                            selectedEntries.removeAll()
                            editMode = .inactive
                        }
                    }
                } message: {
                    Text("This will permanently delete \(selectedEntries.count) entry(ies).")
                }
                .task {
                    await viewModel.loadData()
                    await rangeLoader.loadValue(for: biomarkerName)
                    expandedDates = Set(viewModel.sortedDates)
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView().padding()
        } else if viewModel.sortedDates.isEmpty {
            Text("No \(biomarkerName.lowercased()) data found")
                .foregroundColor(.secondary)
                .padding()
        } else {
            List {
                ForEach(viewModel.sortedDates, id: \.self) { date in
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
    }

    @ViewBuilder
    private func entryRow(entry: BiomarkerEntry) -> some View {
        if editMode == .inactive {
            BiomarkerEntryRow(
                entry: entry,
                unit: viewModel.displayUnit,
                rangeInfo: rangeLoader.rangeInfo
            )
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
                    BiomarkerEntryRow(
                        entry: entry,
                        unit: viewModel.displayUnit,
                        rangeInfo: rangeLoader.rangeInfo
                    )
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

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - View Model

@MainActor
class BiomarkerHistoryViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [BiomarkerEntry]] = [:]
    @Published var isLoading = false
    @Published var displayUnit: String

    private let supabase = SupabaseManager.shared.client
    let biomarkerName: String
    let sampleClinicalType: String  // The actual quantity_type for patient_samples queries
    let defaultUnit: String

    init(biomarkerName: String, sampleClinicalType: String, unit: String) {
        self.biomarkerName = biomarkerName
        self.sampleClinicalType = sampleClinicalType
        self.defaultUnit = unit
        self.displayUnit = unit
    }

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadData() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            struct PatientClinicalSampleRow: Codable {
                let id: UUID
                let value: Double?
                let unit: String?
                let sampleTime: Date
                let sourceType: String?
                let notes: String?
                let createdAt: Date?

                enum CodingKeys: String, CodingKey {
                    case id
                    case value
                    case unit
                    case sampleTime = "sample_time"
                    case sourceType = "source_type"
                    case notes
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

            // Query patient_clinical_samples using the actual clinical_type (e.g., "biomarker_albumin")
            let data = try await supabase
                .from("patient_clinical_samples")
                .select()
                .eq("patient_id", value: patientId)
                .eq("clinical_type", value: sampleClinicalType)
                .order("sample_time", ascending: false)
                .execute()
                .data

            let samples = try decoder.decode([PatientClinicalSampleRow].self, from: data)

            var entries: [BiomarkerEntry] = []
            for sample in samples {
                guard let value = sample.value else { continue }

                let storedUnit = sample.unit ?? defaultUnit

                let entry = BiomarkerEntry(
                    id: sample.id,
                    value: value,
                    unit: storedUnit,
                    recordedAt: sample.sampleTime,
                    source: sample.sourceType ?? "manual",
                    notes: sample.notes,
                    createdAt: sample.createdAt ?? sample.sampleTime
                )
                entries.append(entry)
            }

            // Update displayUnit based on what's in the data
            if let firstEntry = entries.first {
                displayUnit = BiomarkerValueLoader.formatUnitForDisplay(firstEntry.unit)
            }

            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.recordedAt)
            }

            print("Loaded \(entries.count) \(biomarkerName) entries")

        } catch {
            print("Error loading \(biomarkerName) data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [BiomarkerEntry]) async {
        do {
            let patientId = try await supabase.auth.session.user.id

            for entry in entries {
                try await supabase
                    .from("patient_clinical_samples")
                    .delete()
                    .eq("id", value: entry.id)
                    .eq("patient_id", value: patientId)
                    .execute()

                print("Deleted \(biomarkerName) sample: \(entry.id)")
            }

            await loadData()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Entry Model

struct BiomarkerEntry: Identifiable {
    let id: UUID
    let value: Double
    let unit: String
    let recordedAt: Date
    let source: String
    let notes: String?
    let createdAt: Date

    var canDelete: Bool {
        // Allow deletion of manual entries and healthkit entries
        source == "manual" || source == "healthkit" || source == "healthkit_fhir"
    }
}

// MARK: - Entry Row

struct BiomarkerEntryRow: View {
    let entry: BiomarkerEntry
    let unit: String
    let rangeInfo: BiomarkerRangeInfo?

    private var displayUnit: String {
        let entryUnit = entry.unit
        if entryUnit.isEmpty || entryUnit == unit {
            return BiomarkerValueLoader.formatUnitForDisplay(unit)
        }
        return BiomarkerValueLoader.formatUnitForDisplay(entryUnit)
    }

    private var rangeStatus: (name: String, color: Color)? {
        guard let rangeInfo = rangeInfo else { return nil }

        for range in rangeInfo.sortedRanges {
            let low = range.rangeLow ?? rangeInfo.realisticLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? rangeInfo.realisticHigh ?? Double.greatestFiniteMagnitude

            if entry.value >= low && entry.value < high {
                return (range.rangeName, range.color)
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(entry.value))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(displayUnit)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Range status indicator
                    if let status = rangeStatus {
                        Circle()
                            .fill(status.color)
                            .frame(width: 8, height: 8)
                    }
                }

                HStack(spacing: 4) {
                    Text(formatTime(entry.recordedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let status = rangeStatus {
                        Text("• \(status.name)")
                            .font(.caption2)
                            .foregroundColor(status.color)
                    }
                }
            }

            Spacer()

            if let notes = entry.notes, !notes.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: some View {
        Group {
            if entry.source == "healthkit" || entry.source == "healthkit_fhir" {
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
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    BiomarkerDataManagementView(
        biomarkerName: "Albumin",
        sampleClinicalType: "biomarker_albumin",
        unit: "g/dL",
        color: .blue
    )
}
