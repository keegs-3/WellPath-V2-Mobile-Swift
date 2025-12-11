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
            NavigationLink(destination: BiomarkerEntryDetailView(
                entry: entry,
                biomarkerName: biomarkerName,
                unit: viewModel.displayUnit,
                color: color,
                rangeInfo: rangeLoader.rangeInfo,
                viewModel: viewModel
            )) {
                BiomarkerEntryRow(
                    entry: entry,
                    unit: viewModel.displayUnit,
                    rangeInfo: rangeLoader.rangeInfo
                )
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
                // FHIR-relevant fields
                let labName: String?
                let labReferenceLow: Double?
                let labReferenceHigh: Double?
                let collectionMethod: String?

                enum CodingKeys: String, CodingKey {
                    case id
                    case value
                    case unit
                    case sampleTime = "sample_time"
                    case sourceType = "source"
                    case notes
                    case createdAt = "created_at"
                    case labName = "lab_name"
                    case labReferenceLow = "lab_reference_range_low"
                    case labReferenceHigh = "lab_reference_range_high"
                    case collectionMethod = "collection_method"
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
                    createdAt: sample.createdAt ?? sample.sampleTime,
                    labName: sample.labName,
                    labReferenceLow: sample.labReferenceLow,
                    labReferenceHigh: sample.labReferenceHigh,
                    collectionMethod: sample.collectionMethod,
                    deviceInfo: nil,  // TODO: Parse JSONB if needed
                    metadata: nil     // TODO: Parse JSONB if needed
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

    // FHIR-relevant fields
    let labName: String?
    let labReferenceLow: Double?
    let labReferenceHigh: Double?
    let collectionMethod: String?
    let deviceInfo: [String: Any]?
    let metadata: [String: Any]?

    var canDelete: Bool {
        // Allow deletion of manual entries and healthkit entries
        source == "manual" || source == "healthkit" || source == "healthkit_fhir"
    }

    /// Formatted lab reference range string
    var labReferenceRangeString: String? {
        guard labReferenceLow != nil || labReferenceHigh != nil else { return nil }

        if let low = labReferenceLow, let high = labReferenceHigh {
            return "\(formatValue(low)) - \(formatValue(high))"
        } else if let low = labReferenceLow {
            return "> \(formatValue(low))"
        } else if let high = labReferenceHigh {
            return "< \(formatValue(high))"
        }
        return nil
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

// MARK: - Entry Detail View

struct BiomarkerEntryDetailView: View {
    let entry: BiomarkerEntry
    let biomarkerName: String
    let unit: String
    let color: Color
    let rangeInfo: BiomarkerRangeInfo?
    @ObservedObject var viewModel: BiomarkerHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Value card
                valueCard

                // Entry details card
                detailsCard

                // Lab information card (if available)
                if hasLabInfo {
                    labInfoCard
                }

                // Delete button
                if entry.canDelete {
                    deleteButton
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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

    // MARK: - Value Card

    private var valueCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatValue(entry.value))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.primary)
                Text(formatUnit(entry.unit))
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            if let status = rangeStatus {
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 10, height: 10)
                    Text(status.name)
                        .font(.subheadline)
                        .foregroundColor(status.color)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(biomarkerName) Details")
                .font(.headline)

            BiomarkerDetailRow(label: "Recorded", value: formatDateTime(entry.recordedAt))
            BiomarkerDetailRow(label: "Source", value: formatSource(entry.source))
            BiomarkerDetailRow(label: "Added to WellPath", value: formatDateTime(entry.createdAt))

            if let notes = entry.notes, !notes.isEmpty {
                BiomarkerDetailRow(label: "Notes", value: notes)
            }

            BiomarkerDetailRow(label: "Entry ID", value: entry.id.uuidString)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Lab Info Card

    private var hasLabInfo: Bool {
        entry.labName != nil || entry.labReferenceLow != nil || entry.labReferenceHigh != nil || entry.collectionMethod != nil
    }

    private var labInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "building.2")
                    .foregroundColor(color)
                Text("Lab Information")
                    .font(.headline)
            }

            if let labName = entry.labName {
                BiomarkerDetailRow(label: "Laboratory", value: labName)
            }

            if let rangeString = entry.labReferenceRangeString {
                BiomarkerDetailRow(label: "Lab Reference Range", value: "\(rangeString) \(formatUnit(entry.unit))")
            }

            if let method = entry.collectionMethod {
                BiomarkerDetailRow(label: "Collection Method", value: formatCollectionMethod(method))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: {
            showingDeleteAlert = true
        }) {
            HStack {
                Image(systemName: "trash")
                Text("Delete Entry")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(10)
        }
    }

    // MARK: - Actions

    private func deleteEntry() async {
        await viewModel.deleteEntries([entry])
        dismiss()
    }

    // MARK: - Formatting

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func formatUnit(_ rawUnit: String) -> String {
        BiomarkerValueLoader.formatUnitForDisplay(rawUnit)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatSource(_ source: String) -> String {
        switch source.lowercased() {
        case "healthkit", "healthkit_fhir":
            return "HealthKit"
        case "wellpath", "wellpath_input", "manual":
            return "WellPath"
        default:
            return source.capitalized
        }
    }

    private func formatCollectionMethod(_ method: String) -> String {
        switch method.lowercased() {
        case "blood_draw", "blood draw", "venipuncture":
            return "Blood Draw"
        case "finger_prick", "finger prick", "capillary":
            return "Finger Prick"
        case "urine":
            return "Urine Sample"
        case "saliva":
            return "Saliva Sample"
        default:
            return method.capitalized
        }
    }
}

// MARK: - Helper Views

private struct BiomarkerDetailRow: View {
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

// MARK: - Preview

#Preview {
    BiomarkerDataManagementView(
        biomarkerName: "Albumin",
        sampleClinicalType: "biomarker_albumin",
        unit: "g/dL",
        color: .blue
    )
}
