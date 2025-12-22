//
//  ProteinScoreDetailView.swift
//  WellPath
//
//  Detail view showing protein score with 3 tabs:
//  - Today: Score pill + expandable summary card
//  - History: Threshold progress + calendar, taps into day detail
//  - Baseline: Score pill + expandable summary card
//

import SwiftUI

// MARK: - Protein Summary Data

struct ProteinSummaryData {
    let grams: Double
    let tier1Pct: Double
    let tier2Pct: Double
    let tier3Pct: Double
    let ratio: Double
    let weight: Double
    let typeScore: Int?
    let ratioScore: Int?
    let overallScore: Int?

    static let empty = ProteinSummaryData(
        grams: 0, tier1Pct: 0, tier2Pct: 0, tier3Pct: 0,
        ratio: 0, weight: 0, typeScore: nil, ratioScore: nil, overallScore: nil
    )
}

// MARK: - Main Detail View

struct ProteinScoreDetailView: View {
    @ObservedObject var viewModel: ProteinScoreViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScoreTab = .today
    @State private var scoreHistory: [String: Int] = [:]
    @State private var isLoadingHistory = true
    @State private var selectedHistoryDate: Date?
    @State private var displayedMonth: Date = Date()

    // Today's data
    @State private var todayData: ProteinSummaryData = .empty
    @State private var isLoadingToday = true

    // Baseline data
    @State private var baselineData: ProteinSummaryData = .empty

    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    enum ScoreTab: String, CaseIterable {
        case today = "Today"
        case history = "History"
        case baseline = "Baseline"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await unitPrefs.loadPreferences()
                await loadTodayData()
                await loadBaselineData()
                await loadScoreHistory()
            }
            .sheet(item: $selectedHistoryDate) { date in
                ProteinDayDetailView(
                    date: date,
                    score: scoreHistory[dateString(for: date)],
                    color: color,
                    viewModel: viewModel
                )
            }
        }
    }

    // MARK: - Today Tab

    private var todayTabContent: some View {
        VStack(spacing: 20) {
            if viewModel.hasDailyScore {
                ScoreRingPill(
                    score: viewModel.dailyScoreValue,
                    iconName: "fish.fill",
                    label: "Today",
                    size: 90
                )
                .padding(.top, 8)

                Text(scoreLabel(for: viewModel.dailyScoreValue))
                    .font(.headline)
                    .foregroundColor(scoreColor(for: viewModel.dailyScoreValue))

                if isLoadingToday {
                    ProgressView().padding(.vertical, 40)
                } else {
                    ProteinSummaryCard(
                        title: "Today's Protein",
                        data: todayData,
                        color: color,
                        usePounds: unitPrefs.weightUnit == .lb,
                        viewModel: viewModel
                    )
                }

                if let explanation = viewModel.scoringExplanation {
                    scoringExplanationSection(explanation)
                }
            } else {
                noDataTodayView
            }
        }
        .padding()
    }

    // MARK: - Baseline Tab

    private var baselineTabContent: some View {
        VStack(spacing: 20) {
            ScoreRingPill(
                score: viewModel.scoreValue,
                iconName: "fish.fill",
                label: "Baseline",
                size: 90
            )
            .padding(.top, 8)

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

            ProteinSummaryCard(
                title: "Your Baseline",
                data: baselineData,
                color: color,
                usePounds: unitPrefs.weightUnit == .lb,
                viewModel: viewModel,
                showIcon: true
            )

            if let explanation = viewModel.scoringExplanation {
                scoringExplanationSection(explanation)
            }
        }
        .padding()
    }

    // MARK: - History Tab

    private var historyTabContent: some View {
        VStack(spacing: 20) {
            thresholdProgressSection
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
                            Color.clear.frame(height: 44)
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
        let dateStr = dateString(for: date)
        let score = scoreHistory[dateStr]
        let dayNumber = Calendar.current.component(.day, from: date)
        let isFuture = date > Date()

        return Button {
            if score != nil {
                selectedHistoryDate = date
            }
        } label: {
            VStack(spacing: 2) {
                if let score = score {
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

    // MARK: - Shared Components

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

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: displayedMonth)
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1

        var days: [Date?] = []
        for _ in 0..<firstWeekday { days.append(nil) }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        return days
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

            // Load protein samples
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

            var totalGrams: Double = 0
            var tier1Grams: Double = 0
            var tier2Grams: Double = 0
            var tier3Grams: Double = 0

            for sample in samples {
                totalGrams += sample.canonicalValue
                if let type = sample.proteinType {
                    if ["fish", "legumes", "poultry", "eggs"].contains(where: { type.lowercased().contains($0) }) {
                        tier1Grams += sample.canonicalValue
                    } else if ["processed", "bacon", "sausage", "red_meat", "beef", "pork"].contains(where: { type.lowercased().contains($0) }) {
                        tier3Grams += sample.canonicalValue
                    } else {
                        tier2Grams += sample.canonicalValue
                    }
                }
            }

            let tier1Pct = totalGrams > 0 ? (tier1Grams / totalGrams) * 100 : 0
            let tier2Pct = totalGrams > 0 ? (tier2Grams / totalGrams) * 100 : 0
            let tier3Pct = totalGrams > 0 ? (tier3Grams / totalGrams) * 100 : 0

            // Load weight
            let weight = await loadPatientWeight(userId: userId.uuidString)

            let ratio = weight > 0 ? totalGrams / weight : 0

            todayData = ProteinSummaryData(
                grams: totalGrams,
                tier1Pct: tier1Pct,
                tier2Pct: tier2Pct,
                tier3Pct: tier3Pct,
                ratio: ratio,
                weight: weight,
                typeScore: viewModel.dailyTypeScore,
                ratioScore: viewModel.dailyRatioScore,
                overallScore: viewModel.dailyScoreValue
            )

            isLoadingToday = false
        } catch {
            print("Error loading today's data: \(error)")
            isLoadingToday = false
        }
    }

    private func loadBaselineData() async {
        let grams = viewModel.baselines["daily_protein_g"] ?? 0
        let ratioValue = viewModel.baselines["daily_protein_ratio"] ?? 0
        let weight = viewModel.baselines["body_mass_kg"] ?? 0

        baselineData = ProteinSummaryData(
            grams: grams,
            tier1Pct: 0, // Baseline doesn't have tier breakdown
            tier2Pct: 0,
            tier3Pct: 0,
            ratio: ratioValue,
            weight: weight,
            typeScore: viewModel.typeScore,
            ratioScore: viewModel.ratioScore,
            overallScore: viewModel.scoreValue
        )
    }

    private func loadPatientWeight(userId: String) async -> Double {
        do {
            let client = SupabaseManager.shared.client

            struct WeightSample: Decodable {
                let canonicalValue: Double
                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                }
            }

            let weightResults: [WeightSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "body_mass_kg")
                .order("start_time", ascending: false)
                .limit(1)
                .execute()
                .value

            if let w = weightResults.first?.canonicalValue, w > 0 {
                return w
            }

            // Fallback to baseline
            struct BaselineSample: Decodable {
                let value: Double
            }

            let baselineResults: [BaselineSample] = try await client
                .from("patient_baseline_samples")
                .select("value")
                .eq("patient_id", value: userId)
                .eq("baseline_type", value: "body_mass_kg")
                .eq("is_current", value: true)
                .limit(1)
                .execute()
                .value

            return baselineResults.first?.value ?? 0
        } catch {
            print("Error loading weight: \(error)")
            return 0
        }
    }

    private func loadScoreHistory() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

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

// MARK: - Expandable Summary Card

struct ProteinSummaryCard: View {
    let title: String
    let data: ProteinSummaryData
    let color: Color
    let usePounds: Bool
    let viewModel: ProteinScoreViewModel
    var showIcon: Bool = false

    @State private var isExpanded = false

    private let kgToLb: Double = 2.2046

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    if showIcon {
                        Image(systemName: "flag.fill")
                            .font(.headline)
                            .foregroundColor(color)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal)

            // Summary row (always visible)
            HStack(spacing: 0) {
                // Amount
                summaryColumn(
                    icon: "scalemass",
                    value: "\(Int(data.grams))",
                    unit: "g",
                    label: "Amount"
                )

                Divider().frame(height: 55)

                // Type
                summaryColumn(
                    icon: "chart.pie",
                    value: data.typeScore != nil ? "\(data.typeScore!)" : "--",
                    unit: "/100",
                    label: "Type"
                )

                Divider().frame(height: 55)

                // Ratio
                ratioSummaryColumn
            }
            .padding(.vertical, 12)

            // Expanded details
            if isExpanded {
                Divider().padding(.horizontal)

                VStack(spacing: 16) {
                    // Tier breakdown
                    if data.tier1Pct > 0 || data.tier2Pct > 0 || data.tier3Pct > 0 {
                        tierBreakdownSection
                    }

                    // Weight info
                    if data.weight > 0 {
                        weightInfoSection
                    }

                    // Component scores
                    componentScoresSection
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func summaryColumn(icon: String, value: String, unit: String, label: String) -> some View {
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

    private var ratioSummaryColumn: some View {
        let displayRatio = usePounds ? data.ratio / kgToLb : data.ratio
        let unitLabel = usePounds ? "g/lb" : "g/kg"

        return VStack(spacing: 4) {
            Image(systemName: "percent")
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            if data.ratio > 0 {
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

    private var tierBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protein Type Breakdown")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 16) {
                tierRow(label: "Tier 1", pct: data.tier1Pct, color: MetricsUIConfig.tierGood, description: "Fish, legumes, poultry")
                tierRow(label: "Tier 2", pct: data.tier2Pct, color: MetricsUIConfig.tierMedium, description: "Dairy, other")
                tierRow(label: "Tier 3", pct: data.tier3Pct, color: MetricsUIConfig.tierPoor, description: "Red/processed meat")
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func tierRow(label: String, pct: Double, color: Color, description: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Text("\(Int(pct))%")
                .font(.headline)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var weightInfoSection: some View {
        let displayWeight = usePounds ? data.weight * kgToLb : data.weight
        let weightUnit = usePounds ? "lb" : "kg"

        return HStack {
            Image(systemName: "scalemass.fill")
                .foregroundColor(color.opacity(0.7))
            Text("Body Weight:")
                .font(.subheadline)
            Spacer()
            Text("\(Int(displayWeight)) \(weightUnit)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var componentScoresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Components")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(viewModel.components, id: \.id) { component in
                HStack {
                    Image(systemName: component.iconName ?? "circle.fill")
                        .foregroundColor(color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(component.displayName)
                            .font(.subheadline)
                        if let desc = component.description {
                            Text(desc)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        let score: Int? = component.componentType == "protein_type_score" ? data.typeScore : data.ratioScore
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
                        Text(component.weightPercentage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Day Detail View (for History)

struct ProteinDayDetailView: View {
    let date: Date
    let score: Int?
    let color: Color
    @ObservedObject var viewModel: ProteinScoreViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dayData: ProteinSummaryData = .empty
    @State private var isLoading = true
    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ScoreRingPill(
                        score: score,
                        iconName: "fish.fill",
                        label: formattedDate,
                        size: 90
                    )
                    .padding(.top, 8)

                    if let score = score {
                        Text(scoreLabel(for: score))
                            .font(.headline)
                            .foregroundColor(scoreColor(for: score))
                    }

                    if isLoading {
                        ProgressView().padding(.vertical, 40)
                    } else {
                        ProteinSummaryCard(
                            title: "Protein Summary",
                            data: dayData,
                            color: color,
                            usePounds: unitPrefs.weightUnit == .lb,
                            viewModel: viewModel
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await unitPrefs.loadPreferences()
                await loadDayData()
            }
        }
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private func scoreLabel(for score: Int) -> String {
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Improvement" }
    }

    private func loadDayData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Load scores
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
                .eq("aggregation_date", value: dateString)
                .eq("source", value: "calculated")
                .execute()
                .value

            var typeScore: Int?
            var ratioScore: Int?
            for s in scores {
                if s.quantityType == "protein_type_score" {
                    typeScore = Int(s.canonicalValue)
                } else if s.quantityType == "protein_ratio_score" {
                    ratioScore = Int(s.canonicalValue)
                }
            }

            // Load protein samples
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
                .eq("aggregation_date", value: dateString)
                .in("source", values: ["wellpath_input", "healthkit"])
                .execute()
                .value

            var totalGrams: Double = 0
            var tier1Grams: Double = 0
            var tier2Grams: Double = 0
            var tier3Grams: Double = 0

            for sample in samples {
                totalGrams += sample.canonicalValue
                if let type = sample.proteinType {
                    if ["fish", "legumes", "poultry", "eggs"].contains(where: { type.lowercased().contains($0) }) {
                        tier1Grams += sample.canonicalValue
                    } else if ["processed", "bacon", "sausage", "red_meat", "beef", "pork"].contains(where: { type.lowercased().contains($0) }) {
                        tier3Grams += sample.canonicalValue
                    } else {
                        tier2Grams += sample.canonicalValue
                    }
                }
            }

            let tier1Pct = totalGrams > 0 ? (tier1Grams / totalGrams) * 100 : 0
            let tier2Pct = totalGrams > 0 ? (tier2Grams / totalGrams) * 100 : 0
            let tier3Pct = totalGrams > 0 ? (tier3Grams / totalGrams) * 100 : 0

            // Load weight
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
                .lte("aggregation_date", value: dateString)
                .order("start_time", ascending: false)
                .limit(1)
                .execute()
                .value

            let weight = weightResults.first?.canonicalValue ?? 0
            let ratio = weight > 0 ? totalGrams / weight : 0

            dayData = ProteinSummaryData(
                grams: totalGrams,
                tier1Pct: tier1Pct,
                tier2Pct: tier2Pct,
                tier3Pct: tier3Pct,
                ratio: ratio,
                weight: weight,
                typeScore: typeScore,
                ratioScore: ratioScore,
                overallScore: score
            )

            isLoading = false
        } catch {
            print("Error loading day data: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Date Extension for Sheet

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
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
