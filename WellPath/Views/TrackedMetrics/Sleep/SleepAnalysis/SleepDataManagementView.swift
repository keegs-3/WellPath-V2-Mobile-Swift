//
//  SleepDataManagementView.swift
//  WellPath
//
//  Sleep-specific data management view showing periods grouped by type per day
//

import SwiftUI

struct SleepDataManagementView: View {
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SleepDataManagementViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var expandedDates: Set<Date> = []
    @State private var showingDateFilter = false
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var showingDeleteAllAlert = false
    @State private var periodsToDeleteFromCard: [SleepPeriodData] = []
    @State private var showingDeleteCardAlert = false
    @State private var selectedPeriods: Set<UUID> = []

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
                .navigationTitle("All Sleep Data")
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
                .alert("Delete All Sleep Data?", isPresented: $showingDeleteAllAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete All", role: .destructive) {
                        Task {
                            await deleteAllData()
                        }
                    }
                } message: {
                    Text("This will permanently delete all sleep periods from your WellPath account. This action cannot be undone.")
                }
                .alert("Delete Sleep Periods?", isPresented: $showingDeleteCardAlert) {
                    Button("Cancel", role: .cancel) {
                        periodsToDeleteFromCard = []
                    }
                    Button("Delete", role: .destructive) {
                        Task {
                            if !periodsToDeleteFromCard.isEmpty {
                                await viewModel.deletePeriods(periodsToDeleteFromCard)
                                periodsToDeleteFromCard = []
                            } else {
                                // Delete selected periods
                                let periodsToDelete = viewModel.summariesByDate.values
                                    .flatMap { $0.periodTypeSummaries }
                                    .flatMap { $0.periods }
                                    .filter { selectedPeriods.contains($0.id) }
                                await viewModel.deletePeriods(periodsToDelete)
                                selectedPeriods.removeAll()
                            }
                        }
                    }
                } message: {
                    let count = !periodsToDeleteFromCard.isEmpty ? periodsToDeleteFromCard.count : selectedPeriods.count
                    Text("This will permanently delete \(count) sleep period(s).")
                }
                .task {
                    await viewModel.loadSleepData()
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
            Text("No sleep data found")
                .foregroundColor(.secondary)
                .padding()
        } else {
            sleepDataList
        }
    }

    private var sleepDataList: some View {
        List {
            ForEach(filteredDates, id: \.self) { date in
                sleepSection(for: date)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func sleepSection(for date: Date) -> some View {
        if let daySummary = viewModel.summariesByDate[date] {
            Section {
                if expandedDates.contains(date) {
                    ForEach(daySummary.periodTypeSummaries) { summary in
                        periodSummaryRow(summary: summary)
                    }
                }
            } header: {
                sectionHeader(for: date)
            }
        }
    }

    @ViewBuilder
    private func periodSummaryRow(summary: SleepPeriodTypeSummary) -> some View {
        // Only select periods of THIS TYPE (summary.periods already filtered to this type)
        let deletablePeriods = summary.periods.filter { $0.canDelete }
        let deletablePeriodIds = Set(deletablePeriods.map { $0.id })
        let allSelected = !deletablePeriods.isEmpty && deletablePeriodIds.isSubset(of: selectedPeriods)

        if editMode == .inactive {
            NavigationLink(destination: SleepPeriodListView(
                date: viewModel.summariesByDate.first(where: { $0.value.periodTypeSummaries.contains(where: { $0.id == summary.id }) })?.key ?? Date(),
                periodType: summary.periodType,
                periods: summary.periods,
                color: color,
                viewModel: viewModel
            )) {
                SleepPeriodTypeSummaryRow(
                    summary: summary,
                    color: color,
                    editMode: editMode,
                    showChevron: false,
                    isSelected: false,
                    onSelect: {}
                )
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !deletablePeriods.isEmpty {
                    Button(role: .destructive) {
                        periodsToDeleteFromCard = deletablePeriods
                        showingDeleteCardAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        } else {
            // In edit mode: button to select/deselect ALL periods of THIS TYPE only
            Button(action: {
                if allSelected {
                    selectedPeriods.subtract(deletablePeriodIds)
                } else {
                    selectedPeriods.formUnion(deletablePeriodIds)
                }
            }) {
                SleepPeriodTypeSummaryRow(
                    summary: summary,
                    color: color,
                    editMode: editMode,
                    showChevron: false,
                    isSelected: allSelected,
                    onSelect: {}
                )
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
            Button(selectedPeriods.isEmpty ? "Select All" : "Delete (\(selectedPeriods.count))") {
                if selectedPeriods.isEmpty {
                    // Select all deletable periods
                    for (_, daySummary) in viewModel.summariesByDate {
                        for typeSummary in daySummary.periodTypeSummaries {
                            for period in typeSummary.periods where period.canDelete {
                                selectedPeriods.insert(period.id)
                            }
                        }
                    }
                } else {
                    // Delete selected
                    showingDeleteCardAlert = true
                }
            }
            .foregroundColor(selectedPeriods.isEmpty ? .blue : .red)
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
                        // Clear selection when exiting edit mode
                        selectedPeriods.removeAll()
                    }
                    editMode = editMode == .active ? .inactive : .active
                }
            }
        }
    }

    private func deleteAllData() async {
        // Collect all deletable periods
        var allPeriods: [SleepPeriodData] = []
        for (_, daySummary) in viewModel.summariesByDate {
            for typeSummary in daySummary.periodTypeSummaries {
                allPeriods.append(contentsOf: typeSummary.periods.filter { $0.canDelete })
            }
        }

        await viewModel.deletePeriods(allPeriods)

        // Exit edit mode after deletion
        withAnimation {
            editMode = .inactive
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d – d"

        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: date)!

        let startDay = calendar.component(.day, from: date)
        let endDay = calendar.component(.day, from: endDate)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let monthStr = monthFormatter.string(from: date)

        return "\(monthStr) \(startDay)–\(endDay)"
    }
}

// MARK: - Period Type Summary Row

struct SleepPeriodTypeSummaryRow: View {
    let summary: SleepPeriodTypeSummary
    let color: Color
    let editMode: EditMode
    let showChevron: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Edit mode selection circle
            if editMode == .active {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 22))
            }

            // App icon based on source
            if summary.source == "healthkit" {
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

            VStack(alignment: .leading, spacing: 0) {
                Text(summary.periodType.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("\(summary.count) \(summary.count == 1 ? "interval" : "intervals") (\(formatDuration(summary.totalDuration)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Only show chevron if requested and not in edit mode
            if showChevron && editMode == .inactive {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        // Duration is already in MINUTES from aggregation (not seconds)
        let totalMinutes = Int(duration)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)hr \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - Period List View

struct SleepPeriodListView: View {
    let date: Date
    let periodType: SleepPeriodType
    let periods: [SleepPeriodData]
    let color: Color
    @ObservedObject var viewModel: SleepDataManagementViewModel
    @State private var editMode: EditMode = .inactive
    @State private var periodToDelete: SleepPeriodData?
    @State private var showingDeleteAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var selectedPeriods: Set<UUID> = []
    @State private var durationsByEvent: [UUID: TimeInterval] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(formatDate(date))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))

            List {
                ForEach(periods) { period in
                    SleepPeriodListRow(
                        period: period,
                        duration: durationsByEvent[period.id],
                        color: color,
                        editMode: editMode,
                        isSelected: selectedPeriods.contains(period.id),
                        onToggleSelection: {
                            if selectedPeriods.contains(period.id) {
                                selectedPeriods.remove(period.id)
                            } else {
                                selectedPeriods.insert(period.id)
                            }
                        },
                        viewModel: viewModel
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if period.canDelete {
                            Button(role: .destructive) {
                                periodToDelete = period
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("\(periodType.displayName) Intervals")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if editMode == .active {
                    Button(selectedPeriods.isEmpty ? "Select All" : "Delete (\(selectedPeriods.count))") {
                        if selectedPeriods.isEmpty {
                            // Select all deletable periods
                            for period in periods where period.canDelete {
                                selectedPeriods.insert(period.id)
                            }
                        } else {
                            // Delete selected
                            showingDeleteAllAlert = true
                        }
                    }
                    .foregroundColor(selectedPeriods.isEmpty ? .blue : .red)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(editMode == .active ? "Done" : "Edit") {
                    withAnimation {
                        if editMode == .active {
                            selectedPeriods.removeAll()
                        }
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
            }
        }
        .alert("Delete Period?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                periodToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let period = periodToDelete {
                    Task {
                        await viewModel.deletePeriods([period])
                        periodToDelete = nil
                    }
                }
            }
        } message: {
            Text("This will permanently delete this sleep period.")
        }
        .alert("Delete Periods?", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSelectedPeriods()
                }
            }
        } message: {
            Text("This will permanently delete \(selectedPeriods.count) period(s).")
        }
        .task {
            await loadDurations()
        }
    }

    private func deleteSelectedPeriods() async {
        let periodsToDelete = periods.filter { selectedPeriods.contains($0.id) }
        await viewModel.deletePeriods(periodsToDelete)
        selectedPeriods.removeAll()

        // Exit edit mode after deletion
        withAnimation {
            editMode = .inactive
        }
    }

    private func loadDurations() async {
        do {
            let entryIds = periods.map { $0.id.uuidString }

            // Use same custom decoder as loadSleepData
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

            // Query patient_sleep_events for durations using sleep_data_entry_id (which is the entry ID)
            let eventsQuery = viewModel.supabase
                .from("patient_sleep_events")
                .select()
                .in("sleep_data_entry_id", values: entryIds)

            let eventsData = try await eventsQuery.execute().data
            let sleepEvents = try decoder.decode([PatientSleepEvent].self, from: eventsData)

            // Build durations map keyed by entry ID (sleep_data_entry_id)
            var durations: [UUID: TimeInterval] = [:]
            for event in sleepEvents {
                durations[event.sleepDataEntryId] = event.durationMinutes
            }
            durationsByEvent = durations
            print("📊 Loaded \(durations.count) durations for \(periods.count) periods")
        } catch {
            print("❌ Error loading durations: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Period List Row (with delete functionality)

struct SleepPeriodListRow: View {
    let period: SleepPeriodData
    let duration: TimeInterval?
    let color: Color
    let editMode: EditMode
    let isSelected: Bool
    let onToggleSelection: () -> Void
    @ObservedObject var viewModel: SleepDataManagementViewModel

    var body: some View {
        Group {
            if editMode == .inactive {
                NavigationLink(destination: SleepPeriodDetailView(
                    period: period,
                    color: color,
                    viewModel: viewModel
                )) {
                    HStack(spacing: 12) {
                        SleepPeriodRow(period: period, duration: duration, color: color)
                    }
                }
            } else {
                Button(action: {
                    if period.canDelete {
                        onToggleSelection()
                    }
                }) {
                    HStack(spacing: 12) {
                        if period.canDelete {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .blue : .gray)
                                .font(.system(size: 22))
                        }

                        SleepPeriodRow(period: period, duration: duration, color: color)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Period Row

struct SleepPeriodRow: View {
    let period: SleepPeriodData
    let duration: TimeInterval?
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Duration on the left
            VStack(alignment: .leading, spacing: 4) {
                if let duration = duration {
                    Text(formatDuration(duration))
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("--")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, alignment: .leading)

            Spacer()

            // Time range on the right
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTimeRange(start: period.startTime, end: period.endTime))
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        // Duration is in minutes
        let totalMinutes = Int(duration)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

// MARK: - Period Detail View

struct SleepPeriodDetailView: View {
    let period: SleepPeriodData
    let color: Color
    @ObservedObject var viewModel: SleepDataManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Entry details card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sleep Period Details")
                        .font(.headline)

                    SleepDetailRow(label: "Period Type", value: period.periodType.displayName)
                    SleepDetailRow(label: "Start Time", value: formatTime(period.startTime))
                    SleepDetailRow(label: "End Time", value: formatTime(period.endTime))
                    SleepDetailRow(label: "Duration", value: formatDuration(period.duration))
                    SleepDetailRow(label: "Source", value: period.source.capitalized)
                    SleepDetailRow(label: "Date Added to WellPath", value: formatDateTime(period.createdAt))
                    SleepDetailRow(label: "Event ID", value: period.id.uuidString)

                    if let sessionId = period.sleepSessionId {
                        SleepDetailRow(label: "Session ID", value: sessionId.uuidString)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                // Delete button
                if period.canDelete {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
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
        .navigationTitle("Period Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Period?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deletePeriod()
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func deletePeriod() async {
        await viewModel.deletePeriods([period])
        dismiss()
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours)hr \(minutes)min"
    }
}

// MARK: - Helper Views

private struct SleepDetailRow: View {
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
class SleepDataManagementViewModel: ObservableObject {
    @Published var summariesByDate: [Date: SleepDaySummary] = [:]
    @Published var isLoading = false

    let supabase = SupabaseManager.shared.client

    var sortedDates: [Date] {
        summariesByDate.keys.sorted(by: >)
    }

    func loadSleepData() async {
        isLoading = true

        do {
            // Get current patient ID
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                isLoading = false
                return
            }

            // Create custom decoder
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

            // Query new patient_sleep_data_entries table
            print("🔍 Querying sleep data for patient: \(patientId)")
            let sleepDataQuery = supabase
                .from("patient_sleep_data_entries")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .order("period_end", ascending: false)

            let sleepData = try await sleepDataQuery.execute().data
            print("📦 Raw sleep data size: \(sleepData.count) bytes")
            let allEntries = try decoder.decode([PatientSleepDataEntry].self, from: sleepData)
            print("✅ Decoded \(allEntries.count) sleep data entries")

            // Fetch all period type references
            let uniqueTypeIds = Set(allEntries.compactMap { $0.periodTypeId }).compactMap { UUID(uuidString: $0) }

            struct ReferenceData: Codable {
                let id: UUID
                let reference_key: String
            }

            var typeCache: [String: String] = [:]
            if !uniqueTypeIds.isEmpty {
                let refQuery = supabase
                    .from("data_entry_fields_reference")
                    .select("id, reference_key")
                    .in("id", values: uniqueTypeIds.map { $0.uuidString })

                let refData = try await refQuery.execute().data
                let references = try decoder.decode([ReferenceData].self, from: refData)
                for ref in references {
                    typeCache[ref.id.uuidString.lowercased()] = ref.reference_key
                }
            }
            print("📋 Type cache contains \(typeCache.count) mappings")

            // Query patient_sleep_events for session IDs and entry dates
            let eventsQuery = supabase
                .from("patient_sleep_events")
                .select()
                .eq("patient_id", value: patientId.uuidString)

            let eventsData = try await eventsQuery.execute().data
            let sleepEvents = try decoder.decode([PatientSleepEvent].self, from: eventsData)

            // Create a map of sleep_data_entry_id to event info
            var eventInfoMap: [UUID: (sessionId: UUID?, entryDate: Date)] = [:]
            for event in sleepEvents {
                eventInfoMap[event.sleepDataEntryId] = (event.sleepSessionId, event.entryDate)
            }

            // Build period data from sleep data entries
            var periods: [SleepPeriodData] = []
            var skippedCount = 0
            for entry in allEntries {
                guard let entryId = entry.id,
                      let typeId = entry.periodTypeId,
                      let referenceKey = typeCache[typeId],
                      let periodType = SleepPeriodType(rawValue: referenceKey) else {
                    skippedCount += 1
                    print("⚠️ Skipped entry - id: \(entry.id != nil), typeId: \(entry.periodTypeId != nil), refKey: \(entry.periodTypeId != nil ? typeCache[entry.periodTypeId!] != nil : false)")
                    continue
                }

                let duration = entry.periodEnd.timeIntervalSince(entry.periodStart)
                let eventInfo = eventInfoMap[entryId]

                let period = SleepPeriodData(
                    id: entryId,  // Use the unique entry ID, not eventInstanceId
                    patientId: entry.patientId,
                    sleepSessionId: eventInfo?.sessionId,
                    entryDate: eventInfo?.entryDate ?? Calendar.current.startOfDay(for: entry.periodEnd),
                    createdAt: entry.createdAt ?? Date(),
                    source: entry.source,
                    periodType: periodType,
                    startTime: entry.periodStart,
                    endTime: entry.periodEnd,
                    duration: duration,
                    userTimezone: entry.userTimezone ?? "America/Los_Angeles"
                )
                periods.append(period)
            }
            print("📊 Built \(periods.count) periods (\(skippedCount) skipped)")

            // Group periods by sleep session to determine the correct "sleep day"
            // The sleep day is the MAX entry_date of all periods in the session (the wake date)
            let calendar = Calendar.current

            // First, group by session to find the primary date for each session
            let sessionGroups = Dictionary(grouping: periods) { period in
                period.sleepSessionId
            }

            // Map each session to its primary date (max entry_date in the session)
            var sessionToPrimaryDate: [UUID: Date] = [:]
            for (sessionId, sessionPeriods) in sessionGroups {
                if let sessionId = sessionId {
                    let maxEntryDate = sessionPeriods.map { $0.entryDate }.max() ?? sessionPeriods[0].entryDate
                    sessionToPrimaryDate[sessionId] = calendar.startOfDay(for: maxEntryDate)
                }
            }

            // Now group periods by their session's primary date
            let groupedByDate = Dictionary(grouping: periods) { period in
                if let sessionId = period.sleepSessionId,
                   let primaryDate = sessionToPrimaryDate[sessionId] {
                    return primaryDate
                } else {
                    // Fallback for periods without a session
                    return calendar.startOfDay(for: period.entryDate)
                }
            }

            // Create durations map from sleep events (duration is already calculated)
            var durationsByEvent: [UUID: TimeInterval] = [:]
            for event in sleepEvents {
                // Map by entry ID (sleepDataEntryId) since that's what we're using as SleepPeriodData.id
                durationsByEvent[event.sleepDataEntryId] = event.durationMinutes
            }

            // Build summaries grouped by TYPE and SOURCE
            summariesByDate = groupedByDate.mapValues { periodsForDate in
                // Group by BOTH type and source
                let groupedByTypeAndSource = Dictionary(grouping: periodsForDate) { period in
                    "\(period.periodType.rawValue)_\(period.source)"
                }

                let typeSummaries = groupedByTypeAndSource.compactMap { (_, periodsGroup) -> SleepPeriodTypeSummary? in
                    guard let firstPeriod = periodsGroup.first else { return nil }

                    // Calculate total duration by summing OUTPUT entries for this source
                    let totalDuration = periodsGroup.reduce(0.0) { sum, period in
                        sum + (durationsByEvent[period.id] ?? 0)
                    }

                    let intervalCount = periodsGroup.count

                    guard totalDuration > 0 || intervalCount > 0 else {
                        return nil
                    }

                    return SleepPeriodTypeSummary(
                        periodType: firstPeriod.periodType,
                        source: firstPeriod.source,
                        count: intervalCount,
                        totalDuration: totalDuration,
                        periods: periodsGroup.sorted { $0.startTime > $1.startTime }
                    )
                }

                return SleepDaySummary(periodTypeSummaries: typeSummaries)
            }

            print("✅ Loaded \(periods.count) sleep periods")
            print("📅 Created summaries for \(summariesByDate.count) dates")
            print("🔑 Dates: \(summariesByDate.keys.sorted(by: >).prefix(5).map { $0.description })")

        } catch {
            print("Error loading sleep data: \(error)")
        }

        isLoading = false
    }

    func deletePeriods(_ periods: [SleepPeriodData]) async {
        do {
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                return
            }

            for period in periods {
                guard period.patientId == patientId else {
                    print("Attempted to delete period that doesn't belong to current user")
                    continue
                }

                // Delete from patient_sleep_data_entries (CASCADE will delete events and sessions)
                try await supabase
                    .from("patient_sleep_data_entries")
                    .delete()
                    .eq("id", value: period.id.uuidString)
                    .eq("patient_id", value: patientId.uuidString)
                    .execute()

                print("Deleted sleep period: \(period.id)")
            }

            // Reload data
            await loadSleepData()

        } catch {
            print("Error deleting periods: \(error)")
        }
    }

    private func parseDateTime(_ dateString: String) -> Date? {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        iso8601Formatter.formatOptions = [.withInternetDateTime]
        return iso8601Formatter.date(from: dateString)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.date(from: dateString)
    }
}

// MARK: - Models

enum SleepPeriodType: String, CaseIterable {
    case inBed = "in_bed"
    case awake = "awake"
    case rem = "rem"
    case core = "core"
    case deep = "deep"
    case asleep = "asleep"

    var displayName: String {
        switch self {
        case .inBed: return "In Bed"
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        case .asleep: return "Asleep"
        }
    }

    var icon: String {
        switch self {
        case .inBed: return "🛏️"
        case .awake: return "👁️"
        case .rem: return "🌙"
        case .core: return "😴"
        case .deep: return "💤"
        case .asleep: return "😴"
        }
    }
}

struct SleepPeriodData: Identifiable {
    let id: UUID
    let patientId: UUID
    let sleepSessionId: UUID?
    let entryDate: Date
    let createdAt: Date
    let source: String
    let periodType: SleepPeriodType
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let userTimezone: String // Timezone where this sleep data was recorded

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }
}

struct SleepPeriodTypeSummary: Identifiable {
    let id = UUID()
    let periodType: SleepPeriodType
    let source: String
    let count: Int
    let totalDuration: TimeInterval
    let periods: [SleepPeriodData]
}

struct SleepDaySummary {
    let periodTypeSummaries: [SleepPeriodTypeSummary]
}

// MARK: - Date Filter View

struct DateFilterView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @State private var useFilter = false
    @State private var localStartDate = Date()
    @State private var localEndDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Filter by Date Range", isOn: $useFilter)
                        .tint(color)
                }

                if useFilter {
                    Section {
                        DatePicker("From", selection: $localStartDate, displayedComponents: .date)
                        DatePicker("To", selection: $localEndDate, displayedComponents: .date)
                    } header: {
                        Text("Date Range")
                    }
                }

                Section {
                    Button("Clear Filter") {
                        useFilter = false
                        startDate = nil
                        endDate = nil
                    }
                    .foregroundColor(.red)
                    .disabled(!useFilter && startDate == nil && endDate == nil)
                }
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        if useFilter {
                            startDate = localStartDate
                            endDate = localEndDate
                        } else {
                            startDate = nil
                            endDate = nil
                        }
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                if let start = startDate, let end = endDate {
                    useFilter = true
                    localStartDate = start
                    localEndDate = end
                } else {
                    useFilter = false
                    localStartDate = Date()
                    localEndDate = Date()
                }
            }
        }
    }
}
