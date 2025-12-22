//
//  ProteinScoreDetailView.swift
//  WellPath
//
//  Detail view showing protein score with 3 tabs:
//  - Today: Score pill + grams, tier %, ratio breakdown
//  - History: Threshold progress + tappable day pills
//  - Baseline: Baseline score + summary metrics
//

import SwiftUI

struct ProteinScoreDetailView: View {
    @ObservedObject var viewModel: ProteinScoreViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScoreTab = .today
    @State private var scoreHistory: [String: Int] = [:]  // dateString -> score
    @State private var isLoadingHistory = true
    @State private var selectedHistoryEntry: DailyScoreEntry?
    @State private var showingDayDetail = false
    @State private var displayedMonth: Date = Date()

    // Today's data
    @State private var todayGrams: Double = 0
    @State private var todayTier1Pct: Double = 0
    @State private var todayTier2Pct: Double = 0
    @State private var todayTier3Pct: Double = 0
    @State private var todayRatio: Double = 0
    @State private var patientWeight: Double = 0
    @State private var isLoadingToday = true

    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    enum ScoreTab: String, CaseIterable {
        case today = "Today"
        case history = "History"
        case baseline = "Baseline"
    }

    private var usePounds: Bool {
        unitPrefs.weightUnit == .lb
    }

    private let kgToLb: Double = 2.2046

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Score View", selection: $selectedTab) {
                    ForEach(ScoreTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch selectedTab {
                    case .today:
                        todayTabContent
                    case .history:
                        historyTabContent
                    case .baseline:
                        baselineTabContent
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await unitPrefs.loadPreferences()
                await loadTodayData()
                await loadScoreHistory()
            }
            .sheet(isPresented: $showingDayDetail) {
                if let entry = selectedHistoryEntry {
                    DayScoreDetailSheet(entry: entry, color: color)
                }
            }
        }
    }

    // MARK: - Today Tab

    private var todayTabContent: some View {
        VStack(spacing: 20) {
            if viewModel.hasDailyScore {
                // Score pill at top
                ScoreRingPill(
                    score: viewModel.dailyScoreValue,
                    iconName: "fish.fill",
                    label: "Today",
                    size: 90
                )
                .padding(.top, 8)

                // Score status
                Text(scoreLabel(for: viewModel.dailyScoreValue))
                    .font(.headline)
                    .foregroundColor(scoreColor(for: viewModel.dailyScoreValue))

                // Summary metrics card
                if isLoadingToday {
                    ProgressView()
                        .padding(.vertical, 40)
                } else {
                    todaySummaryCard
                }

                // Component scores from DB
                componentBreakdown(
                    title: "Score Components",
                    typeScore: viewModel.dailyTypeScore,
                    ratioScore: viewModel.dailyRatioScore
                )

                // How It's Calculated
                if let explanation = viewModel.scoringExplanation {
                    scoringExplanationSection(explanation)
                }
            } else {
                noDataTodayView
            }
        }
        .padding()
    }

    private var todaySummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Protein")
                    .font(.headline)
                Spacer()
            }

            // Three metrics in a row
            HStack(spacing: 0) {
                // Amount
                metricColumn(
                    icon: "scalemass",
                    value: "\(Int(todayGrams))",
                    unit: "g",
                    label: "Amount"
                )

                Divider().frame(height: 55)

                // Tier breakdown
                tierColumn

                Divider().frame(height: 55)

                // Ratio
                ratioColumn
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var tierColumn: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.pie")
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle().fill(MetricsUIConfig.tierGood).frame(width: 6, height: 6)
                    Text("\(Int(todayTier1Pct))%")
                        .font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle().fill(MetricsUIConfig.tierMedium).frame(width: 6, height: 6)
                    Text("\(Int(todayTier2Pct))%")
                        .font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle().fill(MetricsUIConfig.tierPoor).frame(width: 6, height: 6)
                    Text("\(Int(todayTier3Pct))%")
                        .font(.caption2)
                }
            }
            .foregroundColor(.secondary)

            Text("Tiers")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ratioColumn: some View {
        VStack(spacing: 4) {
            Image(systemName: "percent")
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            if todayRatio > 0 {
                let displayRatio = usePounds ? todayRatio / kgToLb : todayRatio
                let unitLabel = usePounds ? "g/lb" : "g/kg"

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", displayRatio))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(unitLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if patientWeight > 0 {
                    let displayWeight = usePounds ? patientWeight * kgToLb : patientWeight
                    let weightUnit = usePounds ? "lb" : "kg"
                    Text("@ \(Int(displayWeight))\(weightUnit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text("Ratio")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var noDataTodayView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No protein logged today")
                .font(.headline)

            Text("Log your meals to see today's protein breakdown")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - History Tab

    private var historyTabContent: some View {
        VStack(spacing: 20) {
            // Threshold progress
            thresholdProgressSection

            // Score history calendar (tappable days)
            scoreHistoryCalendar
        }
        .padding()
    }

    private var thresholdProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.isBaseline ? "Unlock Tracked Score" : "Tracking Complete")
                    .font(.headline)

                Spacer()

                if !viewModel.isBaseline {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.isBaseline ? color : .green)
                            .frame(width: geometry.size.width * min(viewModel.thresholdProgress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(viewModel.daysTracked) of \(viewModel.daysRequired) days")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(Int(min(viewModel.thresholdProgress, 1.0) * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let explanation = viewModel.thresholdExplanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private var scoreHistoryCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(color)
                }

                Spacer()

                Text(monthYearString(for: displayedMonth))
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation {
                        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        // Don't go beyond current month
                        if nextMonth <= Date() {
                            displayedMonth = nextMonth
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(displayedMonth < Calendar.current.startOfMonth(for: Date()) ? color : .secondary.opacity(0.3))
                }
            }
            .padding(.horizontal)

            if isLoadingHistory {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                // Day headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date = date {
                            calendarDayCell(for: date)
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private func calendarDayCell(for date: Date) -> some View {
        let dateString = dateStringFormatter.string(from: date)
        let score = scoreHistory[dateString]
        let dayNumber = Calendar.current.component(.day, from: date)
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Date()

        return Button {
            if let score = score {
                selectedHistoryEntry = DailyScoreEntry(
                    date: date,
                    dateString: dateString,
                    score: score,
                    dayLabel: "\(dayNumber)"
                )
                showingDayDetail = true
            }
        } label: {
            VStack(spacing: 2) {
                if let score = score {
                    // Day with score - show mini ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 2)
                            .frame(width: 28, height: 28)

                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(
                                Color(red: 0.4, green: 0.7, blue: 0.8).opacity(0.8),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 28, height: 28)

                        Text("\(score)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                } else {
                    // Day without score
                    Text("\(dayNumber)")
                        .font(.caption)
                        .foregroundColor(isFuture ? .secondary.opacity(0.3) : .secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(score == nil)
    }

    private var dateStringFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: displayedMonth)
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!

        // Get the weekday of the first day (0 = Sunday)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1

        var days: [Date?] = []

        // Add empty cells for days before the first
        for _ in 0..<firstWeekday {
            days.append(nil)
        }

        // Add the actual days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    // MARK: - Baseline Tab

    private var baselineTabContent: some View {
        VStack(spacing: 20) {
            // Score pill
            ScoreRingPill(
                score: viewModel.scoreValue,
                iconName: "fish.fill",
                label: "Baseline",
                size: 90
            )
            .padding(.top, 8)

            // Source badge
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.body)
                    .foregroundColor(color)

                Text("Based on questionnaire")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)

            // Baseline summary card (like the old one)
            baselineSummaryCard

            // Component breakdown
            componentBreakdown(
                title: "Baseline Components",
                typeScore: viewModel.typeScore,
                ratioScore: viewModel.ratioScore
            )

            // How It's Calculated
            if let explanation = viewModel.scoringExplanation {
                scoringExplanationSection(explanation)
            }
        }
        .padding()
    }

    private var baselineSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flag.fill")
                    .font(.headline)
                    .foregroundColor(color)
                Text("Your Baseline")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                // Amount
                metricColumn(
                    icon: "scalemass",
                    value: viewModel.baselines["daily_protein_g"] != nil ? "\(Int(viewModel.baselines["daily_protein_g"]!))" : "--",
                    unit: "g",
                    label: "Amount"
                )

                Divider().frame(height: 55)

                // Type Score
                VStack(spacing: 4) {
                    Image(systemName: "chart.pie")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.7))

                    if let score = viewModel.typeScore {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(score)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(scoreColor(for: score))
                            Text("/100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 55)

                // Ratio
                VStack(spacing: 4) {
                    Image(systemName: "percent")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.7))

                    if let ratio = viewModel.baselineRatioDisplay {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.2f", ratio))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(viewModel.ratioUnitDisplay)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    Text("Ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Shared Components

    private func metricColumn(icon: String, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func componentBreakdown(title: String, typeScore: Int?, ratioScore: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.components.enumerated()), id: \.element.id) { index, component in
                    let score: Int? = {
                        if component.componentType == "protein_type_score" {
                            return typeScore
                        } else if component.componentType == "protein_ratio_score" {
                            return ratioScore
                        }
                        return nil
                    }()

                    componentRow(component, score: score)

                    if index < viewModel.components.count - 1 {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func componentRow(_ component: BehavioralScoreComponent, score: Int?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: component.iconName ?? "circle.fill")
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(component.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    if let score = score {
                        Text("\(score)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(for: score))
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    if let description = component.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(component.weightPercentage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private func scoringExplanationSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How It's Calculated")
                .font(.headline)

            Text(explanation)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func scoreColor(for score: Int?) -> Color {
        guard let score = score else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private func scoreLabel(for score: Int?) -> String {
        guard let score = score else { return "" }
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Improvement" }
    }

    // MARK: - Data Loading

    private func loadTodayData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: today)

            // Load protein grams and tier data
            struct ProteinSample: Decodable {
                let canonicalValue: Double
                let proteinType: String?

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case metadata
                }

                enum MetadataKeys: String, CodingKey {
                    case proteinTypes = "protein_types"
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    canonicalValue = try container.decode(Double.self, forKey: .canonicalValue)

                    if let metadataContainer = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata) {
                        proteinType = try? metadataContainer.decode(String.self, forKey: .proteinTypes)
                    } else {
                        proteinType = nil
                    }
                }
            }

            let samples: [ProteinSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value, metadata")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "protein_grams")
                .eq("aggregation_date", value: todayString)
                .in("source", values: ["wellpath_input", "healthkit"])
                .execute()
                .value

            // Calculate totals
            var totalGrams: Double = 0
            var tier1Grams: Double = 0
            var tier2Grams: Double = 0
            var tier3Grams: Double = 0

            // Get tier config (simplified - would need ProteinTypeDonutViewModel)
            for sample in samples {
                totalGrams += sample.canonicalValue
                // Simplified tier assignment - would need proper tier lookup
                if let type = sample.proteinType {
                    // Tier 1: fish, legumes, poultry
                    if ["fish", "legumes", "poultry", "eggs"].contains(where: { type.lowercased().contains($0) }) {
                        tier1Grams += sample.canonicalValue
                    }
                    // Tier 3: processed, red meat
                    else if ["processed", "bacon", "sausage", "red_meat", "beef", "pork"].contains(where: { type.lowercased().contains($0) }) {
                        tier3Grams += sample.canonicalValue
                    }
                    // Tier 2: everything else
                    else {
                        tier2Grams += sample.canonicalValue
                    }
                }
            }

            todayGrams = totalGrams

            if totalGrams > 0 {
                todayTier1Pct = (tier1Grams / totalGrams) * 100
                todayTier2Pct = (tier2Grams / totalGrams) * 100
                todayTier3Pct = (tier3Grams / totalGrams) * 100
            }

            // Load patient weight for ratio - try quantity samples first, then baseline
            struct WeightSample: Decodable {
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                }
            }

            var weight: Double = 0

            // Try patient_quantity_samples first
            let weightResults: [WeightSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "body_mass_kg")
                .order("sample_date", ascending: false)
                .limit(1)
                .execute()
                .value

            if let w = weightResults.first?.canonicalValue, w > 0 {
                weight = w
            } else {
                // Fallback to baseline samples
                struct BaselineSample: Decodable {
                    let value: Double
                }

                let baselineResults: [BaselineSample] = try await client
                    .from("patient_baseline_samples")
                    .select("value")
                    .eq("patient_id", value: userId.uuidString)
                    .eq("baseline_type", value: "body_mass_kg")
                    .eq("is_current", value: true)
                    .limit(1)
                    .execute()
                    .value

                if let w = baselineResults.first?.value, w > 0 {
                    weight = w
                }
            }

            if weight > 0 {
                patientWeight = weight
                todayRatio = totalGrams / weight
            }

            isLoadingToday = false
        } catch {
            print("Error loading today's data: \(error)")
            isLoadingToday = false
        }
    }

    private func loadScoreHistory() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Load last 90 days of score history for calendar
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -90, to: today) else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: startDate)

            struct ScoreResult: Decodable {
                let aggregationDate: String
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case aggregationDate = "aggregation_date"
                    case canonicalValue = "canonical_value"
                }
            }

            let results: [ScoreResult] = try await client
                .from("patient_quantity_samples")
                .select("aggregation_date, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "protein_score")
                .eq("source", value: "calculated")
                .gte("aggregation_date", value: startDateString)
                .order("aggregation_date", ascending: false)
                .execute()
                .value

            // Populate dictionary: dateString -> score
            var historyDict: [String: Int] = [:]
            for result in results {
                historyDict[result.aggregationDate] = Int(result.canonicalValue)
            }
            scoreHistory = historyDict

            isLoadingHistory = false
        } catch {
            print("Error loading score history: \(error)")
            isLoadingHistory = false
        }
    }
}

// MARK: - Supporting Types

struct DailyScoreEntry: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let score: Int
    let dayLabel: String
}

// MARK: - Day Score Detail Sheet

struct DayScoreDetailSheet: View {
    let entry: DailyScoreEntry
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var grams: Double = 0
    @State private var tier1Pct: Double = 0
    @State private var tier2Pct: Double = 0
    @State private var tier3Pct: Double = 0
    @State private var ratio: Double = 0
    @State private var typeScore: Int = 0
    @State private var ratioScore: Int = 0
    @State private var isLoading = true

    @StateObject private var unitPrefs = UnitPreferencesViewModel()
    private let kgToLb: Double = 2.2046

    private var usePounds: Bool {
        unitPrefs.weightUnit == .lb
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score pill
                    ScoreRingPill(
                        score: entry.score,
                        iconName: "fish.fill",
                        label: formattedDate,
                        size: 90
                    )
                    .padding(.top, 8)

                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else {
                        // Summary metrics
                        daySummaryCard
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await unitPrefs.loadPreferences()
                await loadDayData()
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: entry.date)
    }

    private var daySummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Protein Summary")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                // Amount
                VStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.7))

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(grams))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 55)

                // Tiers
                VStack(spacing: 4) {
                    Image(systemName: "chart.pie")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.7))

                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Circle().fill(MetricsUIConfig.tierGood).frame(width: 6, height: 6)
                            Text("\(Int(tier1Pct))%").font(.caption2)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(MetricsUIConfig.tierMedium).frame(width: 6, height: 6)
                            Text("\(Int(tier2Pct))%").font(.caption2)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(MetricsUIConfig.tierPoor).frame(width: 6, height: 6)
                            Text("\(Int(tier3Pct))%").font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)

                    Text("Tiers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 55)

                // Ratio
                VStack(spacing: 4) {
                    Image(systemName: "percent")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.7))

                    if ratio > 0 {
                        let displayRatio = usePounds ? ratio / kgToLb : ratio
                        let unitLabel = usePounds ? "g/lb" : "g/kg"

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", displayRatio))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(unitLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    Text("Ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Component scores
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Type Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(typeScore)")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ratio Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(ratioScore)")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func loadDayData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Load scores for this day
            struct ScoreSample: Decodable {
                let quantityType: String
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case quantityType = "quantity_type"
                    case canonicalValue = "canonical_value"
                }
            }

            let scores: [ScoreSample] = try await client
                .from("patient_quantity_samples")
                .select("quantity_type, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .in("quantity_type", values: ["protein_type_score", "protein_ratio_score"])
                .eq("aggregation_date", value: entry.dateString)
                .eq("source", value: "calculated")
                .execute()
                .value

            for score in scores {
                if score.quantityType == "protein_type_score" {
                    typeScore = Int(score.canonicalValue)
                } else if score.quantityType == "protein_ratio_score" {
                    ratioScore = Int(score.canonicalValue)
                }
            }

            // Load protein grams
            struct ProteinSample: Decodable {
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                }
            }

            let proteinSamples: [ProteinSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "protein_grams")
                .eq("aggregation_date", value: entry.dateString)
                .in("source", values: ["wellpath_input", "healthkit"])
                .execute()
                .value

            grams = proteinSamples.reduce(0) { $0 + $1.canonicalValue }

            // Load weight for ratio
            struct WeightSample: Decodable {
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                }
            }

            let weightResults: [WeightSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "body_mass_kg")
                .lte("sample_date", value: entry.dateString)
                .order("sample_date", ascending: false)
                .limit(1)
                .execute()
                .value

            if let weight = weightResults.first?.canonicalValue, weight > 0 {
                ratio = grams / weight
            }

            isLoading = false
        } catch {
            print("Error loading day data: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    ProteinScoreDetailView(
        viewModel: ProteinScoreViewModel(),
        color: .green
    )
}
