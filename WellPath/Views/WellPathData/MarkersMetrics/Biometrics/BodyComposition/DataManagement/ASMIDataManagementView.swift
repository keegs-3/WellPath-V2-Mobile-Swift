//
//  ASMIDataManagementView.swift
//  WellPath
//
//  Data management view for ASMI showing both the calculated value
//  and its input components (ASMM and height)
//

import SwiftUI
import Supabase

struct ASMIDataManagementView: View {
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ASMIDataViewModel()
    @State private var expandedDates: Set<Date> = []
    @State private var editMode: EditMode = .inactive
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("All ASMI Data")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if editMode == .active {
                            Button(selectedEntries.isEmpty ? "Select All" : "Delete (\(selectedEntries.count))") {
                                if selectedEntries.isEmpty {
                                    for entry in viewModel.entries where entry.canDelete {
                                        selectedEntries.insert(entry.id)
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
                .alert("Delete ASMI Entries?", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        selectedEntries.removeAll()
                    }
                    Button("Delete", role: .destructive) {
                        Task {
                            await viewModel.deleteEntries(ids: selectedEntries)
                            selectedEntries.removeAll()
                            editMode = .inactive
                        }
                    }
                } message: {
                    Text("This will permanently delete \(selectedEntries.count) entry(ies) including both ASMI and ASMM data.")
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
            Text("No ASMI data found")
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
    private func entryRow(entry: ASMIEntry) -> some View {
        if editMode == .inactive {
            NavigationLink(destination: ASMIEntryDetailView(entry: entry, color: color, viewModel: viewModel)) {
                ASMIEntryRow(entry: entry)
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
                    ASMIEntryRow(entry: entry)
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

private struct ASMIEntryRow: View {
    let entry: ASMIEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main ASMI value
            HStack {
                Text(formatValue(entry.asmiValue))
                    .font(.headline)
                Text("kg/m²")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(entry.recordedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Components breakdown
            HStack(spacing: 16) {
                // ASMM input
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(formatValue(entry.asmmValue)) \(entry.asmmUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Height used
                HStack(spacing: 4) {
                    Image(systemName: "ruler")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(formatValue(entry.heightCm)) cm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Source
                Text(formatSource(entry.source))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
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
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatSource(_ source: String) -> String {
        switch source.lowercased() {
        case "healthkit": return "HealthKit"
        case "wellpath", "wellpath_input": return "WellPath"
        default: return source.capitalized
        }
    }
}

// MARK: - Entry Detail View

private struct ASMIEntryDetailView: View {
    let entry: ASMIEntry
    let color: Color
    @ObservedObject var viewModel: ASMIDataViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Calculated ASMI card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "function")
                            .foregroundColor(color)
                        Text("Calculated Value")
                            .font(.headline)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(formatValue(entry.asmiValue))
                            .font(.system(size: 36, weight: .bold))
                        Text("kg/m²")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    Text("ASMI = ASMM ÷ Height²")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                // Input components card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(color)
                        Text("Input Components")
                            .font(.headline)
                    }

                    Divider()

                    // ASMM
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Appendicular Muscle Mass")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatValue(entry.asmmValue)) \(entry.asmmUnit)")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Height
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Height")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(formatValue(entry.heightCm)) cm")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Image(systemName: "ruler")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                // Metadata card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(color)
                        Text("Details")
                            .font(.headline)
                    }

                    ASMIDetailRow(label: "Recorded", value: formatDateTime(entry.recordedAt))
                    ASMIDetailRow(label: "Source", value: formatSource(entry.source))
                    ASMIDetailRow(label: "Added to WellPath", value: formatDateTime(entry.createdAt))
                    ASMIDetailRow(label: "Entry ID", value: entry.id.uuidString)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(10)

                // Delete button
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
                    await viewModel.deleteEntries(ids: [entry.id])
                    dismiss()
                }
            }
        } message: {
            Text("This will delete both the ASMI and ASMM entries.")
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

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatSource(_ source: String) -> String {
        switch source.lowercased() {
        case "healthkit": return "HealthKit"
        case "wellpath", "wellpath_input": return "WellPath"
        default: return source.capitalized
        }
    }
}

private struct ASMIDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Data Model

struct ASMIEntry: Identifiable {
    let id: UUID  // ASMI sample ID
    let asmiValue: Double
    let asmmValue: Double
    let asmmUnit: String
    let heightCm: Double
    let recordedAt: Date
    let source: String
    let createdAt: Date
    let eventInstanceId: UUID?
    let asmmSampleId: UUID?

    var canDelete: Bool {
        source.lowercased() != "healthkit"
    }
}

// MARK: - ViewModel

@MainActor
class ASMIDataViewModel: ObservableObject {
    @Published var entries: [ASMIEntry] = []
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    var sortedDates: [Date] {
        let calendar = Calendar.current
        let uniqueDates = Set(entries.map { calendar.startOfDay(for: $0.recordedAt) })
        return uniqueDates.sorted(by: >)
    }

    var entriesByDate: [Date: [ASMIEntry]] {
        let calendar = Calendar.current
        return Dictionary(grouping: entries) { calendar.startOfDay(for: $0.recordedAt) }
    }

    func loadData() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // First, get patient's height from characteristics
            struct CharacteristicResult: Codable {
                let valueNumeric: Double?
                enum CodingKeys: String, CodingKey {
                    case valueNumeric = "value_numeric"
                }
            }

            let heightResults: [CharacteristicResult] = try await supabase
                .from("patient_characteristics")
                .select("value_numeric")
                .eq("patient_id", value: patientId)
                .eq("characteristic_type_name", value: "height")
                .limit(1)
                .execute()
                .value

            let currentHeight = heightResults.first?.valueNumeric ?? 0

            // Get all ASMI samples
            struct ASMISample: Codable {
                let id: UUID
                let quantityValue: Double
                let startTime: Date
                let source: String?
                let createdAt: Date
                let eventInstanceId: UUID?

                enum CodingKeys: String, CodingKey {
                    case id
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                    case source
                    case createdAt = "created_at"
                    case eventInstanceId = "event_instance_id"
                }
            }

            let asmiSamples: [ASMISample] = try await supabase
                .from("patient_quantity_samples")
                .select("id, quantity_value, start_time, source, created_at, event_instance_id")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: "asmi")
                .order("start_time", ascending: false)
                .execute()
                .value

            // Get all ASMM samples to link with ASMI
            struct ASMMSample: Codable {
                let id: UUID
                let quantityValue: Double
                let quantityUnit: String?
                let eventInstanceId: UUID?

                enum CodingKeys: String, CodingKey {
                    case id
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case eventInstanceId = "event_instance_id"
                }
            }

            let asmmSamples: [ASMMSample] = try await supabase
                .from("patient_quantity_samples")
                .select("id, quantity_value, quantity_unit, event_instance_id")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: "appendicular_skeletal_muscle_mass")
                .execute()
                .value

            // Create lookup by event_instance_id
            let asmmByEvent = Dictionary(uniqueKeysWithValues:
                asmmSamples.compactMap { sample -> (UUID, ASMMSample)? in
                    guard let eventId = sample.eventInstanceId else { return nil }
                    return (eventId, sample)
                }
            )

            // Build entries
            var loadedEntries: [ASMIEntry] = []

            for asmi in asmiSamples {
                // Try to find matching ASMM via event_instance_id
                var asmmValue: Double = 0
                var asmmUnit = "kg"
                var asmmSampleId: UUID?

                if let eventId = asmi.eventInstanceId, let asmm = asmmByEvent[eventId] {
                    asmmValue = asmm.quantityValue
                    asmmUnit = formatUnit(asmm.quantityUnit ?? "kilogram")
                    asmmSampleId = asmm.id
                } else {
                    // Calculate ASMM from ASMI and height if no linked entry
                    // ASMI = ASMM / height^2, so ASMM = ASMI * height^2
                    if currentHeight > 0 {
                        let heightM = currentHeight / 100.0
                        asmmValue = asmi.quantityValue * (heightM * heightM)
                    }
                }

                let entry = ASMIEntry(
                    id: asmi.id,
                    asmiValue: asmi.quantityValue,
                    asmmValue: asmmValue,
                    asmmUnit: asmmUnit,
                    heightCm: currentHeight,
                    recordedAt: asmi.startTime,
                    source: asmi.source ?? "unknown",
                    createdAt: asmi.createdAt,
                    eventInstanceId: asmi.eventInstanceId,
                    asmmSampleId: asmmSampleId
                )

                loadedEntries.append(entry)
            }

            entries = loadedEntries

        } catch {
            print("Error loading ASMI data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(ids: Set<UUID>) async {
        let entriesToDelete = entries.filter { ids.contains($0.id) }

        for entry in entriesToDelete {
            do {
                // Delete ASMI sample
                try await supabase
                    .from("patient_quantity_samples")
                    .delete()
                    .eq("id", value: entry.id)
                    .execute()

                // Also delete linked ASMM sample if exists
                if let asmmId = entry.asmmSampleId {
                    try await supabase
                        .from("patient_quantity_samples")
                        .delete()
                        .eq("id", value: asmmId)
                        .execute()
                }
            } catch {
                print("Error deleting entry: \(error)")
            }
        }

        // Refresh data
        await loadData()
    }

    private func formatUnit(_ rawUnit: String) -> String {
        switch rawUnit.lowercased() {
        case "pound", "pounds": return "lb"
        case "kilogram", "kilograms": return "kg"
        default: return rawUnit
        }
    }
}

#Preview {
    ASMIDataManagementView(color: .cyan)
}
