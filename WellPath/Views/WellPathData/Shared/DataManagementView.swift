//
//  DataManagementView.swift
//  WellPath
//
//  Generic view for managing user's data entries with source display and delete/edit capabilities
//

import SwiftUI

struct DataManagementView: View {
    let metricName: String
    let quantityTypes: [String]  // Quantity types to filter for this metric (e.g., "steps", "water_ml")
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DataManagementViewModel
    @State private var editMode: EditMode = .inactive

    init(metricName: String, quantityTypes: [String], color: Color) {
        self.metricName = metricName
        self.quantityTypes = quantityTypes
        self.color = color
        _viewModel = StateObject(wrappedValue: DataManagementViewModel(quantityTypes: quantityTypes))
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
    private let quantityTypes: [String]

    init(quantityTypes: [String]) {
        self.quantityTypes = quantityTypes
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

            // Query patient_quantity_samples for the specified quantity types
            let query = supabase
                .from("patient_quantity_samples")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .in("quantity_type", values: quantityTypes)
                .order("start_time", ascending: false)

            let data = try await query.execute().data
            let samples = try decoder.decode([RawDataSample].self, from: data)

            // Convert to DataEntry models
            let entries = samples.map { sample in
                DataEntry(
                    id: sample.id,
                    patientId: sample.patientId,
                    quantityType: sample.quantityType ?? "",
                    quantityValue: sample.quantityValue,
                    quantityUnit: sample.quantityUnit,
                    startTime: sample.startTime,
                    endTime: sample.endTime,
                    source: sample.source,
                    createdAt: sample.createdAt
                )
            }

            // Group entries by date
            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.startTime)
            }

            print("Loaded \(entries.count) samples for quantity types: \(quantityTypes)")

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

            // Delete each entry from patient_quantity_samples
            for entry in entries {
                // Verify this entry belongs to the current user
                guard entry.patientId == patientId else {
                    print("Attempted to delete entry that doesn't belong to current user")
                    continue
                }

                // Delete from patient_quantity_samples
                try await supabase
                    .from("patient_quantity_samples")
                    .delete()
                    .eq("id", value: entry.id.uuidString)
                    .eq("patient_id", value: patientId.uuidString)
                    .execute()

                print("Deleted sample: \(entry.id)")
            }

            // Reload data
            await loadEntries()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

// MARK: - Models

/// Raw sample from patient_quantity_samples table
struct RawDataSample: Codable {
    let id: UUID
    let patientId: UUID
    let startTime: Date
    let endTime: Date
    let quantityValue: Double?
    let quantityUnit: String?
    let quantityType: String?
    let source: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case quantityType = "quantity_type"
        case source
        case createdAt = "created_at"
    }
}

/// Data entry view model for display
struct DataEntry: Identifiable {
    let id: UUID
    let patientId: UUID
    let quantityType: String
    let quantityValue: Double?
    let quantityUnit: String?
    let startTime: Date
    let endTime: Date
    let source: String
    let createdAt: Date?

    var entryDate: Date {
        startTime
    }

    var entryTimestamp: Date? {
        startTime
    }

    var displayName: String {
        // Map quantity types to display names
        switch quantityType {
        case QuantityTypes.steps:
            return "Steps"
        case QuantityTypes.proteinGrams:
            return "Protein"
        case QuantityTypes.waterMl:
            return "Water"
        case QuantityTypes.vegetablesServings:
            return "Vegetables"
        case QuantityTypes.legumesServings:
            return "Legumes"
        case QuantityTypes.wholeGrainsServings:
            return "Whole Grains"
        case QuantityTypes.fruitsServings:
            return "Fruits"
        case QuantityTypes.strengthTraining:
            return "Strength Training"
        case QuantityTypes.cardio:
            return "Cardio"
        case QuantityTypes.yogaDuration:
            return "Yoga"
        case QuantityTypes.meditationDuration:
            return "Meditation"
        case QuantityTypes.weight:
            return "Weight"
        case QuantityTypes.heartRate:
            return "Heart Rate"
        default:
            // Format quantity type nicely if no mapping exists
            return quantityType
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    var valueDescription: String {
        guard let value = quantityValue else { return "N/A" }

        // Format based on quantity type
        if quantityType.contains("duration") {
            // Format as hours and minutes (value is in minutes)
            let totalMinutes = Int(value)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        } else if quantityType == QuantityTypes.steps {
            // Steps as whole number with comma formatting
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
        } else if quantityType.contains("servings") {
            // Servings as decimal
            return String(format: "%.1f servings", value)
        } else if quantityType == QuantityTypes.proteinGrams {
            return "\(Int(value))g"
        } else if quantityType == QuantityTypes.waterMl {
            // Display in L if >= 1000mL, otherwise mL
            if value >= 1000 {
                return String(format: "%.1f L", value / 1000.0)
            } else {
                return "\(Int(value)) mL"
            }
        } else if let unit = quantityUnit {
            return "\(Int(value)) \(unit)"
        } else {
            return String(format: "%.1f", value)
        }
    }

    var canDelete: Bool {
        // Can delete WellPath entries or own HealthKit entries
        return source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }

    var canEdit: Bool {
        // Can only edit WellPath entries
        return source == "wellpath" || source == "wellpath_input"
    }
}
