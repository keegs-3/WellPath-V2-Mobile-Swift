//
//  HeartRateDataManagementView.swift
//  WellPath
//
//  Data management view for Heart Rate entries
//  Queries patient_series_samples (heart_rate_series) instead of patient_quantity_samples
//

import SwiftUI
import Supabase

struct HeartRateDataManagementView: View {
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HeartRateDataViewModel()
    @State private var expandedDates: Set<Date> = []
    @State private var editMode: EditMode = .inactive
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("All Heart Rate Data")
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
                .alert("Delete Heart Rate Entries?", isPresented: $showingDeleteAlert) {
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
                    expandedDates = Set(viewModel.sortedDates)
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView().padding()
        } else if viewModel.sortedDates.isEmpty {
            Text("No heart rate data found")
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
    private func entryRow(entry: HeartRateEntry) -> some View {
        if editMode == .inactive {
            NavigationLink(destination: HeartRateEntryDetailView(
                entry: entry,
                color: color,
                viewModel: viewModel
            )) {
                HeartRateEntryRow(entry: entry)
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
                    HeartRateEntryRow(entry: entry)
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

// MARK: - Entry Row

struct HeartRateEntryRow: View {
    let entry: HeartRateEntry

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(entry.value))")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(formatTime(entry.timestamp))
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Entry Detail View

struct HeartRateEntryDetailView: View {
    let entry: HeartRateEntry
    let color: Color
    @ObservedObject var viewModel: HeartRateDataViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Heart Rate Details")
                        .font(.headline)

                    DetailRow(label: "Value", value: "\(Int(entry.value)) BPM")
                    DetailRow(label: "Recorded", value: formatDateTime(entry.timestamp))
                    DetailRow(label: "Source", value: formatSource(entry.source))
                    DetailRow(label: "Added to WellPath", value: formatDateTime(entry.createdAt))
                    DetailRow(label: "Entry ID", value: entry.id.uuidString)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                if entry.canDelete {
                    Button(action: { showingDeleteAlert = true }) {
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
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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
class HeartRateDataViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [HeartRateEntry]] = [:]
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadData() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            struct SeriesSampleRow: Codable {
                let id: UUID
                let value: Double
                let timestamp: Date
                let source: String
                let createdAt: Date?

                enum CodingKeys: String, CodingKey {
                    case id
                    case value
                    case timestamp
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
                .from("patient_series_samples")
                .select()
                .eq("patient_id", value: patientId)
                .eq("series_type", value: "heart_rate_series")
                .order("timestamp", ascending: false)
                .execute()
                .data

            let samples = try decoder.decode([SeriesSampleRow].self, from: data)

            var entries: [HeartRateEntry] = []
            for sample in samples {
                let entry = HeartRateEntry(
                    id: sample.id,
                    value: sample.value,
                    timestamp: sample.timestamp,
                    source: sample.source,
                    createdAt: sample.createdAt ?? sample.timestamp
                )
                entries.append(entry)
            }

            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.timestamp)
            }

            print("Loaded \(entries.count) heart rate entries")

        } catch {
            print("Error loading heart rate data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [HeartRateEntry]) async {
        do {
            let patientId = try await supabase.auth.session.user.id

            for entry in entries {
                try await supabase
                    .from("patient_series_samples")
                    .delete()
                    .eq("id", value: entry.id)
                    .eq("patient_id", value: patientId)
                    .execute()

                print("Deleted heart rate sample: \(entry.id)")
            }

            await loadData()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Model

struct HeartRateEntry: Identifiable {
    let id: UUID
    let value: Double
    let timestamp: Date
    let source: String
    let createdAt: Date

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }
}

#Preview {
    HeartRateDataManagementView(color: .red)
}
