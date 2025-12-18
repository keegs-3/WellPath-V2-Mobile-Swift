//
//  BodyMeasurementsDataManagementView.swift
//  WellPath
//
//  Data management view for Body Measurements (Waist/Hip) entries
//  Lists paired entries with waist, hip, and calculated ratio
//

import SwiftUI
import Supabase

struct BodyMeasurementsDataManagementView: View {
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BodyMeasurementsDataViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var expandedDates: Set<Date> = []
    @State private var showingDateFilter = false
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    private let icon = "ruler"

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
                .navigationTitle("All Body Measurements")
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
                .alert("Delete Measurement Entries?", isPresented: $showingDeleteAlert) {
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
            Text("No body measurement data found")
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
    private func entryRow(entry: BodyMeasurementEntry) -> some View {
        if editMode == .inactive {
            NavigationLink(destination: BodyMeasurementEntryDetailView(entry: entry, viewModel: viewModel, color: color)) {
                BodyMeasurementEntryRow(entry: entry, icon: icon, color: color)
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
                    BodyMeasurementEntryRow(entry: entry, icon: icon, color: color)
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

struct BodyMeasurementEntryRow: View {
    let entry: BodyMeasurementEntry
    let icon: String
    let color: Color

    // Display the value as entered (no conversion)
    private var displayWaist: Double? {
        entry.waist
    }

    private var displayHip: Double? {
        entry.hip
    }

    // Use the entry's original unit
    private var unitString: String {
        entry.displayUnit
    }

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 4) {
                // Show waist and hip values in their original units
                HStack(spacing: 12) {
                    if let waist = displayWaist {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("W:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", waist))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    if let hip = displayHip {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("H:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", hip))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    Text(unitString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Show ratio if both values exist
                if let ratio = entry.ratio {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ratioColor(ratio))
                            .frame(width: 6, height: 6)
                        Text("Ratio: \(String(format: "%.2f", ratio))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text(formatTime(entry.recordedAt))
                .font(.caption)
                .foregroundColor(.secondary)
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

    private func ratioColor(_ ratio: Double) -> Color {
        if ratio < 0.80 {
            return .green
        } else if ratio < 0.90 {
            return .yellow
        } else if ratio < 1.0 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Entry Detail View

struct BodyMeasurementEntryDetailView: View {
    let entry: BodyMeasurementEntry
    @ObservedObject var viewModel: BodyMeasurementsDataViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    // Display values as entered (no conversion)
    private var displayWaist: Double? {
        entry.waist
    }

    private var displayHip: Double? {
        entry.hip
    }

    // Use entry's original unit
    private var unitString: String {
        entry.displayUnit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Body Measurement Entry Details")
                        .font(.headline)

                    if let waist = displayWaist {
                        MeasurementDetailRow(label: "Waist Circumference", value: "\(String(format: "%.1f", waist)) \(unitString)")
                    }
                    if let hip = displayHip {
                        MeasurementDetailRow(label: "Hip Circumference", value: "\(String(format: "%.1f", hip)) \(unitString)")
                    }
                    if let ratio = entry.ratio {
                        MeasurementDetailRow(label: "Waist-to-Hip Ratio", value: String(format: "%.2f", ratio))
                        MeasurementDetailRow(label: "Classification", value: classifyRatio(ratio))
                    }
                    MeasurementDetailRow(label: "Date", value: formatDate(entry.recordedAt))
                    MeasurementDetailRow(label: "Time", value: formatTime(entry.recordedAt))
                    MeasurementDetailRow(label: "Source", value: formatSource(entry.source))
                    MeasurementDetailRow(label: "Date Added", value: formatDateTime(entry.createdAt))
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

    private func classifyRatio(_ ratio: Double) -> String {
        if ratio < 0.80 {
            return "Low Risk"
        } else if ratio < 0.90 {
            return "Moderate Risk"
        } else if ratio < 1.0 {
            return "High Risk"
        } else {
            return "Very High Risk"
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

private struct MeasurementDetailRow: View {
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
class BodyMeasurementsDataViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [BodyMeasurementEntry]] = [:]
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadData() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            struct PatientSampleRow: Codable {
                let id: UUID
                let quantityType: String?
                let quantityValue: Double?
                let quantityUnit: String?
                let startTime: Date
                let source: String
                let createdAt: Date?
                let eventInstanceId: UUID?

                enum CodingKeys: String, CodingKey {
                    case id
                    case quantityType = "quantity_type"
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                    case source
                    case createdAt = "created_at"
                    case eventInstanceId = "event_instance_id"
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

            // Load waist readings
            let waistData = try await supabase
                .from("patient_quantity_samples")
                .select()
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: QuantityTypes.waistCircumference)
                .order("start_time", ascending: false)
                .execute()
                .data

            let waistReadings = try decoder.decode([PatientSampleRow].self, from: waistData)

            // Load hip readings
            let hipData = try await supabase
                .from("patient_quantity_samples")
                .select()
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: QuantityTypes.hipCircumference)
                .order("start_time", ascending: false)
                .execute()
                .data

            let hipReadings = try decoder.decode([PatientSampleRow].self, from: hipData)

            // Match waist and hip readings by event_instance_id or timestamp
            var entries: [BodyMeasurementEntry] = []
            var usedHipIds: Set<UUID> = []

            for waist in waistReadings {
                guard let waistValue = waist.quantityValue else { continue }

                // Find matching hip reading
                let matchingHip = hipReadings.first { hip in
                    guard !usedHipIds.contains(hip.id) else { return false }
                    guard let _ = hip.quantityValue else { return false }

                    if let waistEventId = waist.eventInstanceId, let hipEventId = hip.eventInstanceId {
                        return waistEventId == hipEventId
                    }
                    // Fallback to timestamp matching (within 1 minute)
                    return abs(waist.startTime.timeIntervalSince(hip.startTime)) < 60
                }

                let hipValue = matchingHip?.quantityValue
                if let hip = matchingHip {
                    usedHipIds.insert(hip.id)
                }

                // Calculate ratio if both values exist
                let ratio: Double? = if let hip = hipValue, hip > 0 {
                    waistValue / hip
                } else {
                    nil
                }

                let entry = BodyMeasurementEntry(
                    id: waist.id,
                    waistId: waist.id,
                    hipId: matchingHip?.id,
                    eventInstanceId: waist.eventInstanceId,
                    waist: waistValue,
                    hip: hipValue,
                    waistUnit: waist.quantityUnit,
                    hipUnit: matchingHip?.quantityUnit,
                    ratio: ratio,
                    recordedAt: waist.startTime,
                    source: waist.source,
                    createdAt: waist.createdAt ?? waist.startTime
                )
                entries.append(entry)
            }

            // Add any unmatched hip readings
            for hip in hipReadings where !usedHipIds.contains(hip.id) {
                guard let hipValue = hip.quantityValue else { continue }

                let entry = BodyMeasurementEntry(
                    id: hip.id,
                    waistId: nil,
                    hipId: hip.id,
                    eventInstanceId: hip.eventInstanceId,
                    waist: nil,
                    hip: hipValue,
                    waistUnit: nil,
                    hipUnit: hip.quantityUnit,
                    ratio: nil,
                    recordedAt: hip.startTime,
                    source: hip.source,
                    createdAt: hip.createdAt ?? hip.startTime
                )
                entries.append(entry)
            }

            // Sort by date descending
            entries.sort { $0.recordedAt > $1.recordedAt }

            // Group by date
            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.recordedAt)
            }

            print("Loaded \(entries.count) body measurement entries from patient_quantity_samples")

        } catch {
            print("Error loading body measurements data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [BodyMeasurementEntry]) async {
        do {
            let patientId = try await supabase.auth.session.user.id

            for entry in entries {
                // Delete waist sample if exists
                if let waistId = entry.waistId {
                    try await supabase
                        .from("patient_quantity_samples")
                        .delete()
                        .eq("id", value: waistId)
                        .eq("patient_id", value: patientId)
                        .execute()
                }

                // Delete hip sample if exists
                if let hipId = entry.hipId {
                    try await supabase
                        .from("patient_quantity_samples")
                        .delete()
                        .eq("id", value: hipId)
                        .eq("patient_id", value: patientId)
                        .execute()
                }

                print("Deleted body measurement entry: \(entry.id)")
            }

            await loadData()

            // Notify other views that biometric data changed
            NotificationCenter.default.post(name: .biometricDataDidChange, object: nil)

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Model

struct BodyMeasurementEntry: Identifiable {
    let id: UUID
    let waistId: UUID?
    let hipId: UUID?
    let eventInstanceId: UUID?
    let waist: Double?  // value as entered (not converted)
    let hip: Double?    // value as entered (not converted)
    let waistUnit: String?  // original unit from database (e.g., "inch", "centimeter")
    let hipUnit: String?    // original unit from database
    let ratio: Double?
    let recordedAt: Date
    let source: String
    let createdAt: Date

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }

    // Convert database unit to display string
    var displayUnit: String {
        let unit = waistUnit ?? hipUnit ?? "centimeter"
        switch unit.lowercased() {
        case "inch", "inches", "in":
            return "in"
        case "centimeter", "centimeters", "cm":
            return "cm"
        default:
            return unit
        }
    }
}

#Preview {
    BodyMeasurementsDataManagementView(color: .cyan)
}
