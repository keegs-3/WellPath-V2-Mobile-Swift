//
//  ActivityDataManagementView.swift
//  WellPath
//
//  Generic data management view for duration-based activities
//  Used by: Mindfulness, Outdoor Time, Social Interactions, Cognitive Activities
//

import SwiftUI

// MARK: - Activity Entry Model

struct ActivityEntry: Identifiable {
    let id: UUID
    let quantityType: String
    let durationMinutes: Double
    let startTime: Date
    let endTime: Date?
    let activitySubtype: String?
    let notes: String?
    let source: String?

    var displayName: String {
        activitySubtype?.replacingOccurrences(of: "_", with: " ").capitalized ?? quantityType.capitalized
    }
}

// MARK: - Activity Data Management View

struct ActivityDataManagementView: View {
    let config: ActivityCategoryConfig

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ActivityEntry] = []
    @State private var isLoading = true
    @State private var showingEntryForm = false
    @State private var selectedEntry: ActivityEntry?

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entries.isEmpty {
                    emptyStateView
                } else {
                    entriesList
                }
            }
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEntryForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEntryForm) {
                ActivityEntryView(config: config) {
                    Task {
                        await loadEntries()
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                ActivityDetailView(entry: entry, config: config) {
                    Task {
                        await deleteEntry(entry)
                    }
                }
            }
        }
        .task {
            await loadEntries()
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: config.icon)
                .font(.system(size: 48))
                .foregroundColor(config.color.opacity(0.5))

            Text("No \(config.name) entries yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Button {
                showingEntryForm = true
            } label: {
                Text("Add Entry")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(config.color)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entriesList: some View {
        List {
            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedEntries[date] ?? []) { entry in
                        ActivityEntryRow(entry: entry, config: config)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                } header: {
                    Text(formatSectionDate(date))
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadEntries()
        }
    }

    // MARK: - Helpers

    private var groupedEntries: [Date: [ActivityEntry]] {
        Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.startTime)
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private func loadEntries() async {
        do {
            let userId = try await supabase.auth.session.user.id

            struct ActivitySampleRow: Codable {
                let id: UUID
                let quantityType: String
                let quantityValue: Double
                let startTime: Date
                let endTime: Date?
                let source: String?
                let metadata: ActivityMetadataRow?

                enum CodingKeys: String, CodingKey {
                    case id
                    case quantityType = "quantity_type"
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                    case endTime = "end_time"
                    case source
                    case metadata
                }
            }

            struct ActivityMetadataRow: Codable {
                let activitySubtype: String?
                let notes: String?

                enum CodingKeys: String, CodingKey {
                    case activitySubtype = "activity_subtype"
                    case notes
                }
            }

            let rows: [ActivitySampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("id, quantity_type, quantity_value, start_time, end_time, source, metadata")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: config.quantityType)
                .order("start_time", ascending: false)
                .limit(100)
                .execute()
                .value

            await MainActor.run {
                entries = rows.map { row in
                    ActivityEntry(
                        id: row.id,
                        quantityType: row.quantityType,
                        durationMinutes: row.quantityValue,
                        startTime: row.startTime,
                        endTime: row.endTime,
                        activitySubtype: row.metadata?.activitySubtype,
                        notes: row.metadata?.notes,
                        source: row.source
                    )
                }
                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("Error loading entries: \(error)")
                isLoading = false
            }
        }
    }

    private func deleteEntry(_ entry: ActivityEntry) async {
        do {
            try await supabase
                .from("patient_quantity_samples")
                .delete()
                .eq("id", value: entry.id.uuidString)
                .execute()

            await MainActor.run {
                entries.removeAll { $0.id == entry.id }
                selectedEntry = nil
            }
        } catch {
            print("Error deleting entry: \(error)")
        }
    }
}

// MARK: - Activity Entry Row

struct ActivityEntryRow: View {
    let entry: ActivityEntry
    let config: ActivityCategoryConfig

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(config.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: config.icon)
                    .font(.system(size: 18))
                    .foregroundColor(config.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)

                Text(formatTime(entry.startTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Duration
            Text(formatDuration(entry.durationMinutes))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(config.color)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Activity Detail View

struct ActivityDetailView: View {
    let entry: ActivityEntry
    let config: ActivityCategoryConfig
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(config.color.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: config.icon)
                                .font(.system(size: 36))
                                .foregroundColor(config.color)
                        }

                        Text(entry.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(formatDate(entry.startTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Duration card
                    VStack(spacing: 8) {
                        Text(formatDuration(entry.durationMinutes))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(config.color)

                        Text("Duration")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Details section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ActivityDetailRowView(label: "Type", value: entry.displayName)
                            ActivityDetailRowView(label: "Time", value: formatTime(entry.startTime))
                            ActivityDetailRowView(label: "Source", value: entry.source?.capitalized ?? "Manual")

                            if let notes = entry.notes, !notes.isEmpty {
                                ActivityDetailRowView(label: "Notes", value: notes)
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Delete Entry", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this entry?")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins) min"
        }
    }
}

private struct ActivityDetailRowView: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ActivityDataManagementView(config: .mindfulness)
}
