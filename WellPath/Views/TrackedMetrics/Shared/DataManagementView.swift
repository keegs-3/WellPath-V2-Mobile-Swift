//
//  DataManagementView.swift
//  WellPath
//
//  Generic view for managing user's data entries with source display and delete/edit capabilities
//

import SwiftUI

struct DataManagementView: View {
    let metricName: String
    let fieldIds: [String]  // Field IDs to filter for this metric
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DataManagementViewModel
    @State private var editMode: EditMode = .inactive

    init(metricName: String, fieldIds: [String], color: Color) {
        self.metricName = metricName
        self.fieldIds = fieldIds
        self.color = color
        _viewModel = StateObject(wrappedValue: DataManagementViewModel(fieldIds: fieldIds))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if viewModel.sortedDates.isEmpty {
                    Text("No data entries found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.sortedDates, id: \.self) { date in
                            Section(header: Text(formatSectionDate(date))) {
                                ForEach(viewModel.entriesByDate[date] ?? []) { entry in
                                    NavigationLink(destination: DataEntryDetailView(entry: entry, color: color, viewModel: viewModel)) {
                                        DataEntryRow(entry: entry, color: color)
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteEntries(at: indexSet, for: date)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("All \(metricName) Data")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.sortedDates.isEmpty {
                        Button(editMode == .active ? "Done" : "Edit") {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                    }
                }
            }
            .task {
                await viewModel.loadEntries()
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet, for date: Date) {
        guard let entries = viewModel.entriesByDate[date] else { return }

        let entriesToDelete = offsets.map { entries[$0] }
        Task {
            await viewModel.deleteEntries(entriesToDelete)
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Data Entry Row

struct DataEntryRow: View {
    let entry: DataEntry
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Source icon (WellPath or Apple Health)
            sourceIcon
                .frame(width: 40, height: 40)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(entry.valueDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private var sourceIcon: some View {
        Group {
            if entry.source == "wellpath" {
                Image("black_green")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Data Entry Detail View

struct DataEntryDetailView: View {
    let entry: DataEntry
    let color: Color
    @ObservedObject var viewModel: DataManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Entry details card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Entry Details")
                        .font(.headline)

                    DetailRow(label: "Value", value: entry.valueDescription)
                    DetailRow(label: "Date", value: formatDate(entry.entryDate))
                    DetailRow(label: "Source", value: entry.source.capitalized)

                    if let timestamp = entry.entryTimestamp {
                        DetailRow(label: "Time", value: formatTime(timestamp))
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                // Delete button (only for WellPath entries or user's own HealthKit data)
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
}

struct DetailRow: View {
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
class DataManagementViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [DataEntry]] = [:]
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client
    private let fieldIds: [String]

    init(fieldIds: [String]) {
        self.fieldIds = fieldIds
    }

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadEntries() async {
        isLoading = true

        do {
            // Get current patient ID
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                isLoading = false
                return
            }

            // Create custom decoder for date handling
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try ISO8601 with time first
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                // Try without fractional seconds
                iso8601Formatter.formatOptions = [.withInternetDateTime]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                // Try date-only format (YYYY-MM-DD)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
            }

            // Query patient_data_entries for the specified field IDs
            let query = supabase
                .from("patient_data_entries")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .in("field_id", values: fieldIds)
                .order("entry_date", ascending: false)

            let data = try await query.execute().data
            let response = try decoder.decode([DataEntry].self, from: data)

            // Group entries by date
            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: response) { entry in
                calendar.startOfDay(for: entry.entryDate)
            }

            print("Loaded \(response.count) data entries for fields: \(fieldIds)")

        } catch {
            print("Error loading data entries: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [DataEntry]) async {
        do {
            // Get current patient ID for verification
            guard let userId = supabase.auth.currentUser?.id,
                  let patientId = UUID(uuidString: userId.uuidString) else {
                print("No authenticated user found")
                return
            }

            // Delete each entry
            for entry in entries {
                // Verify this entry belongs to the current user
                guard entry.patientId == patientId else {
                    print("Attempted to delete entry that doesn't belong to current user")
                    continue
                }

                // Delete from database
                try await supabase
                    .from("patient_data_entries")
                    .delete()
                    .eq("id", value: entry.id.uuidString)
                    .eq("patient_id", value: patientId.uuidString)
                    .execute()

                print("Deleted entry: \(entry.id)")
            }

            // Reload data
            await loadEntries()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Models

struct DataEntry: Identifiable, Codable {
    let id: UUID
    let patientId: UUID
    let fieldId: String
    let entryDate: Date
    let entryTimestamp: Date?
    let valueQuantity: Double?
    let valueTimestamp: Date?
    let valueReference: UUID?
    let source: String
    let healthkitUuid: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case fieldId = "field_id"
        case entryDate = "entry_date"
        case entryTimestamp = "entry_timestamp"
        case valueQuantity = "value_quantity"
        case valueTimestamp = "value_timestamp"
        case valueReference = "value_reference"
        case source
        case healthkitUuid = "healthkit_uuid"
    }

    var displayName: String {
        // Map common field IDs to display names
        switch fieldId {
        case "OUTPUT_SLEEP_PERIOD_DURATION":
            return "Sleep Duration"
        case "OUTPUT_TIME_ASLEEP":
            return "Time Asleep"
        case "OUTPUT_TIME_AWAKE":
            return "Time Awake"
        case "OUTPUT_TIME_IN_BED":
            return "Time In Bed"
        case "DEF_SLEEP_PERIOD_TYPE":
            return "Sleep Period Type"
        default:
            // Format field ID nicely if no mapping exists
            return fieldId
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    var valueDescription: String {
        if let quantity = valueQuantity {
            // Format based on field type
            if fieldId.contains("DURATION") || fieldId.contains("TIME") {
                // Format as hours and minutes
                let hours = Int(quantity)
                let minutes = Int((quantity - Double(hours)) * 60)
                return "\(hours)h \(minutes)m"
            } else {
                // Default numeric formatting
                return String(format: "%.1f", quantity)
            }
        } else if let _ = valueReference {
            return "Reference Value"
        } else if let timestamp = valueTimestamp {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }
        return "N/A"
    }

    var canDelete: Bool {
        // Can delete WellPath entries or own HealthKit entries
        return source == "wellpath" || source == "healthkit"
    }

    var canEdit: Bool {
        // Can only edit WellPath entries
        return source == "wellpath"
    }
}
