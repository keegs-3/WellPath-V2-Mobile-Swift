//
//  BloodPressureDataManagementView.swift
//  WellPath
//
//  Data management view for Blood Pressure entries
//  Lists all entries with edit/delete capabilities
//

import SwiftUI
import Supabase

struct BloodPressureDataManagementView: View {
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BloodPressureDataViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var expandedDates: Set<Date> = []
    @State private var showingDateFilter = false
    @State private var filterStartDate: Date?
    @State private var filterEndDate: Date?
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    private let icon = "heart.fill"

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
                .navigationTitle("All Blood Pressure Data")
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
                .alert("Delete Blood Pressure Entries?", isPresented: $showingDeleteAlert) {
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
            Text("No blood pressure data found")
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
    private func entryRow(entry: BloodPressureEntry) -> some View {
        if editMode == .inactive {
            NavigationLink(destination: BloodPressureEntryDetailView(entry: entry, viewModel: viewModel, color: color)) {
                BloodPressureEntryRow(entry: entry, icon: icon, color: color)
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
                    BloodPressureEntryRow(entry: entry, icon: icon, color: color)
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

struct BloodPressureEntryRow: View {
    let entry: BloodPressureEntry
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(entry.systolic))/\(Int(entry.diastolic))")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("mmHg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(classificationColor)
                        .frame(width: 6, height: 6)
                    Text(classification)
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

    private var classification: String {
        let sys = Int(entry.systolic)
        let dia = Int(entry.diastolic)
        if sys < 120 && dia < 80 {
            return "Normal"
        } else if sys < 130 && dia < 80 {
            return "Elevated"
        } else {
            return "High"
        }
    }

    private var classificationColor: Color {
        let sys = Int(entry.systolic)
        let dia = Int(entry.diastolic)
        if sys < 120 && dia < 80 {
            return .green
        } else if sys < 130 && dia < 80 {
            return .yellow
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

struct BloodPressureEntryDetailView: View {
    let entry: BloodPressureEntry
    @ObservedObject var viewModel: BloodPressureDataViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Blood Pressure Entry Details")
                        .font(.headline)

                    BPDetailRow(label: "Reading", value: "\(Int(entry.systolic))/\(Int(entry.diastolic)) mmHg")
                    BPDetailRow(label: "Systolic", value: "\(Int(entry.systolic)) mmHg")
                    BPDetailRow(label: "Diastolic", value: "\(Int(entry.diastolic)) mmHg")
                    BPDetailRow(label: "Classification", value: classification)
                    BPDetailRow(label: "Date", value: formatDate(entry.recordedAt))
                    BPDetailRow(label: "Time", value: formatTime(entry.recordedAt))
                    BPDetailRow(label: "Source", value: formatSource(entry.source))
                    BPDetailRow(label: "Date Added", value: formatDateTime(entry.createdAt))
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

    private var classification: String {
        let sys = Int(entry.systolic)
        let dia = Int(entry.diastolic)
        if sys < 120 && dia < 80 {
            return "Normal"
        } else if sys < 130 && dia < 80 {
            return "Elevated"
        } else if sys < 140 || dia < 90 {
            return "High (Stage 1)"
        } else {
            return "High (Stage 2)"
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

private struct BPDetailRow: View {
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
class BloodPressureDataViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [BloodPressureEntry]] = [:]
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadData() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // Query patient_correlation_samples for blood pressure readings
            let results: [CorrelationSampleRead] = try await supabase
                .from("patient_correlation_samples")
                .select("id, patient_id, correlation_type, components, sample_time, source, user_timezone")
                .eq("patient_id", value: patientId)
                .eq("correlation_type", value: CorrelationTypes.bloodPressure)
                .order("sample_time", ascending: false)
                .execute()
                .value

            // Convert to BloodPressureEntry
            var entries: [BloodPressureEntry] = []

            for reading in results {
                guard let systolic = reading.systolic, let diastolic = reading.diastolic else { continue }

                let entry = BloodPressureEntry(
                    id: reading.id,
                    systolic: systolic,
                    diastolic: diastolic,
                    recordedAt: reading.sampleTime,
                    source: reading.source ?? "unknown",
                    createdAt: reading.sampleTime  // Correlation samples don't have separate createdAt
                )
                entries.append(entry)
            }

            // Group by date
            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.recordedAt)
            }

            print("Loaded \(entries.count) blood pressure entries from patient_correlation_samples")

        } catch {
            print("Error loading blood pressure data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [BloodPressureEntry]) async {
        do {
            let patientId = try await supabase.auth.session.user.id

            for entry in entries {
                // Delete correlation sample (single row contains both systolic and diastolic)
                try await supabase
                    .from("patient_correlation_samples")
                    .delete()
                    .eq("id", value: entry.id)
                    .eq("patient_id", value: patientId)
                    .execute()

                print("Deleted blood pressure entry: \(entry.id)")
            }

            await loadData()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Model

struct BloodPressureEntry: Identifiable {
    let id: UUID
    let systolic: Double
    let diastolic: Double
    let recordedAt: Date
    let source: String
    let createdAt: Date

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }
}

#Preview {
    BloodPressureDataManagementView(color: .red)
}
