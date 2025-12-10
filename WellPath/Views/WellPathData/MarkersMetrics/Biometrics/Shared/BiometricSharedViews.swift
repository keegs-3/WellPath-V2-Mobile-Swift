//
//  BiometricSharedViews.swift
//  WellPath
//
//  Reusable view components for biometric screens
//

import SwiftUI
import Charts

// MARK: - Background

struct BiometricBackground: View {
    let color: Color
    let icon: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 900)
                Spacer()
            }

            // Topographic wave pattern overlay - covers full screen, fades naturally
            GeometryReader { geo in
                TopographicPattern(color: .white, opacity: 0.12, fadeStart: 0.2, fadeEnd: 0.85)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Value Card

struct BiometricValueCard: View {
    let value: Double?
    let unit: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let lastUpdated: Date?
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(color)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                } else if let value = value {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(value))
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.primary)
                            Text(unit)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No data")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let date = lastUpdated {
                HStack {
                    Spacer()
                    Text("Last updated: \(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - About View

struct BiometricAboutView: View {
    @ObservedObject var educationLoader: BiometricEducationLoader
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if educationLoader.isLoading {
                        ProgressView("Loading education content...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if educationLoader.sections.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No education content available")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(educationLoader.sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: iconForSection(section.sectionTitle))
                                        .foregroundColor(color)
                                    Text(section.sectionTitle)
                                        .font(.headline)
                                }
                                Text(section.sectionContent)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Back to chart button
            Button(action: onDismiss) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func iconForSection(_ title: String) -> String {
        let titleLower = title.lowercased()
        if titleLower.contains("overview") || titleLower.contains("about") {
            return "info.circle.fill"
        } else if titleLower.contains("longevity") || titleLower.contains("health") || titleLower.contains("impact") {
            return "heart.circle.fill"
        } else if titleLower.contains("range") || titleLower.contains("optimal") {
            return "chart.bar.fill"
        } else if titleLower.contains("tip") || titleLower.contains("improve") {
            return "lightbulb.circle.fill"
        }
        return "doc.text.fill"
    }
}

// MARK: - About Modal (Sheet)

/// Modal sheet version of the About view for cleaner presentation
struct BiometricAboutModal: View {
    let title: String
    @ObservedObject var educationLoader: BiometricEducationLoader
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if educationLoader.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading education content...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if educationLoader.sections.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No education content available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Check back soon for information about this metric.")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(educationLoader.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: iconForSection(section.sectionTitle))
                                        .font(.title3)
                                        .foregroundColor(color)
                                    Text(section.sectionTitle)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }

                                Text(section.sectionContent)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("About \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func iconForSection(_ title: String) -> String {
        let titleLower = title.lowercased()
        if titleLower.contains("overview") || titleLower.contains("about") {
            return "info.circle.fill"
        } else if titleLower.contains("longevity") || titleLower.contains("health") || titleLower.contains("impact") {
            return "heart.circle.fill"
        } else if titleLower.contains("range") || titleLower.contains("optimal") {
            return "chart.bar.fill"
        } else if titleLower.contains("tip") || titleLower.contains("improve") {
            return "lightbulb.circle.fill"
        } else if titleLower.contains("status") || titleLower.contains("your") {
            return "person.circle.fill"
        } else if titleLower.contains("trend") {
            return "chart.line.uptrend.xyaxis"
        } else if titleLower.contains("step") || titleLower.contains("next") {
            return "arrow.right.circle.fill"
        }
        return "doc.text.fill"
    }
}

// MARK: - Trend Chart (Real Data)

struct BiometricTrendChart: View {
    let metricId: String
    let color: Color
    let unit: String

    @StateObject private var viewModel = BiometricTrendViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.headline)

            if viewModel.isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 200)
                    .overlay(ProgressView())
            } else if viewModel.historicalValues.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 200)
                    .overlay(Text("No historical data").foregroundColor(.secondary))
            } else {
                Chart {
                    ForEach(viewModel.historicalValues, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .symbolSize(30)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .task {
            await viewModel.loadHistory(for: metricId)
        }
    }
}

// MARK: - Trend ViewModel

@MainActor
class BiometricTrendViewModel: ObservableObject {
    @Published var historicalValues: [(date: Date, value: Double)] = []
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadHistory(for metricId: String) async {
        isLoading = true

        do {
            // Get primary sample_quantity_type from display_views_dependencies
            struct DependencyMapping: Codable {
                let sampleQuantityType: String?
                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let dependencies: [DependencyMapping] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type")
                .eq("view_id", value: metricId)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value

            guard let quantityType = dependencies.first?.sampleQuantityType else {
                isLoading = false
                return
            }

            let patientId = try await supabase.auth.session.user.id

            struct SampleReading: Codable {
                let quantityValue: Double
                let startTime: Date
                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                }
            }

            // Load all samples (biometric data is sparse)
            let results: [SampleReading] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: true)
                .execute()
                .value

            historicalValues = results.map { (date: $0.startTime, value: $0.quantityValue) }

        } catch {
            print("Error loading biometric history: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Legacy Placeholder (for backward compat)

struct BiometricTrendCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.headline)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(height: 200)
                .overlay(Text("Chart coming soon").foregroundColor(.secondary))
        }
        .padding(.horizontal)
    }
}

// Note: BiometricSimpleMiniCard removed - use BiometricMiniCard which uses database data

// MARK: - Simple Data Management View

struct SimpleBiometricDataManagementView: View {
    let title: String
    let biometricName: String
    let unit: String
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SimpleBiometricDataViewModel
    @State private var expandedDates: Set<Date> = []
    @State private var editMode: EditMode = .inactive
    @State private var selectedEntries: Set<UUID> = []
    @State private var showingDeleteAlert = false

    init(title: String, biometricName: String, unit: String, color: Color) {
        self.title = title
        self.biometricName = biometricName
        self.unit = unit
        self.color = color
        _viewModel = StateObject(wrappedValue: SimpleBiometricDataViewModel(biometricName: biometricName, unit: unit))
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("All \(title) Data")
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
                .alert("Delete \(title) Entries?", isPresented: $showingDeleteAlert) {
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
            Text("No \(title.lowercased()) data found")
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
    private func entryRow(entry: SimpleBiometricEntry) -> some View {
        if editMode == .inactive {
            SimpleBiometricEntryRow(entry: entry, unit: viewModel.displayUnit)
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
                    SimpleBiometricEntryRow(entry: entry, unit: viewModel.displayUnit)
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
