//
//  GenericScoreDetailView.swift
//  WellPath
//
//  Database-driven score detail view with Today/History/Baseline tabs.
//  Renders component details based on calculation_method from sample_behavioral_score_types.
//

import SwiftUI

struct GenericScoreDetailView: View {
    @ObservedObject var viewModel: GenericScoreDetailViewModel
    let title: String
    let iconName: String
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ScoreDetailTab = .today
    @State private var displayedMonth: Date = Date()
    @State private var selectedHistoryDate: Date?
    @State private var selectedDayScores: (composite: Int?, components: [String: Int])?
    @State private var isLoadingDayScores = false
    @State private var showBaselineEdit = false

    enum ScoreDetailTab: String, CaseIterable {
        case today = "Today"
        case history = "History"
        case baseline = "Baseline"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(ScoreDetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
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
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadAll()
                await viewModel.loadScoreHistory()
                await viewModel.loadBaselineHistory()
            }
        }
    }

    // MARK: - Today Tab

    private var todayTabContent: some View {
        VStack(spacing: 20) {
            // Main score ring
            if let score = viewModel.dailyCompositeScore {
                VStack(spacing: 12) {
                    ScoreRingPill(
                        score: score,
                        iconName: iconName,
                        label: "Today",
                        size: 90
                    )

                    Text(scoreLabel(for: score))
                        .font(.headline)
                        .foregroundColor(scoreColor(for: score))
                }
                .padding(.top, 8)

                // Component breakdown (for composite scores)
                if viewModel.isComposite {
                    componentBreakdownSection(
                        title: "Score Components",
                        componentScores: viewModel.dailyComponentScores
                    )
                }
            } else {
                noDataView(message: "No data logged today")
            }
        }
        .padding()
    }

    // MARK: - Component Breakdown

    @ViewBuilder
    private func componentBreakdownSection(title: String, componentScores: [String: Int], date: Date = Date(), isBaseline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section title
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            // Score description (always visible, not in accordion)
            if let desc = viewModel.mainDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }

            // Expandable component cards (with centered rings inside)
            ForEach(viewModel.components) { component in
                ComponentExpandableCard(
                    component: component,
                    score: componentScores[component.componentScoreType],
                    description: viewModel.componentDescriptions[component.componentScoreType],
                    viewModel: viewModel,
                    color: color,
                    date: date,
                    isBaseline: isBaseline
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func componentDetailSection(component: ScoreComponentWeight, score: Int?, date: Date = Date()) -> some View {
        let method = viewModel.calculationMethod(for: component.componentScoreType)

        switch method {
        case .weightedTiers:
            // Show tier breakdown for type scores
            TierBreakdownDetailSection(
                component: component,
                score: score,
                viewModel: viewModel,
                date: date,
                color: color
            )

        case .timingDistribution:
            // Show timing distribution
            TimingDistributionDetailSection(
                component: component,
                score: score,
                viewModel: viewModel,
                date: date,
                color: color
            )

        case .scoringRanges:
            // Show scoring ranges
            ScoringRangesDetailSection(
                component: component,
                score: score,
                viewModel: viewModel,
                date: date,
                color: color
            )

        default:
            // Fallback to simple display
            simpleComponentRow(component: component, score: score, method: method)
        }
    }

    @ViewBuilder
    private func simpleComponentRow(component: ScoreComponentWeight, score: Int?, method: ScoreCalculationMethod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: component.iconName ?? "questionmark.circle")
                    .foregroundColor(color)
                Text(component.displayName ?? component.componentScoreType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let score = score {
                    Text("\(score)/100")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(scoreColor(for: score))
                }
            }

            // Method-specific hint
            Text(methodDescription(method))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func methodDescription(_ method: ScoreCalculationMethod) -> String {
        switch method {
        case .scoringRanges:
            return "Based on target ranges"
        case .weightedTiers:
            return "Based on source quality tiers"
        case .timingDistribution:
            return "Based on timing throughout the day"
        case .variety:
            return "Based on count and distribution"
        case .assessment:
            return "Based on questionnaire responses"
        case .composite:
            return "Combined from sub-components"
        case .unknown:
            return ""
        }
    }

    // MARK: - History Tab

    private var historyTabContent: some View {
        VStack(spacing: 20) {
            // Calendar
            scoreHistoryCalendar

            // Selected day detail (inline, not sheet)
            if let selectedDate = selectedHistoryDate {
                selectedDayDetailSection(for: selectedDate)
            }
        }
        .padding()
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

            if viewModel.isLoadingHistory {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                // Day labels
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
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                        if let date = date {
                            calendarDayCell(for: date)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private func calendarDayCell(for date: Date) -> some View {
        let dateStr = dateString(for: date)
        let score = viewModel.scoreHistory[dateStr]
        let dayNumber = Calendar.current.component(.day, from: date)
        let isFuture = date > Date()
        let isSelected = selectedHistoryDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false

        return Button {
            guard score != nil else { return }
            withAnimation {
                if isSelected {
                    selectedHistoryDate = nil
                    selectedDayScores = nil
                } else {
                    selectedHistoryDate = date
                    Task {
                        await loadDayScores(for: date)
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                if let score = score {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? color : Color.gray.opacity(0.15), lineWidth: isSelected ? 3 : 2)
                            .frame(width: 28, height: 28)
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(
                                color.opacity(0.8),
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

    @ViewBuilder
    private func selectedDayDetailSection(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dismiss
            HStack {
                Text(formattedDate(date))
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation {
                        selectedHistoryDate = nil
                        selectedDayScores = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            if isLoadingDayScores {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let scores = selectedDayScores {
                // Score ring
                HStack {
                    Spacer()
                    ScoreRingPill(
                        score: scores.composite,
                        iconName: iconName,
                        label: formattedDate(date),
                        size: 70
                    )
                    Spacer()
                }

                // Component breakdown (no extra wrapper padding)
                if viewModel.isComposite {
                    componentBreakdownSection(
                        title: "Components",
                        componentScores: scores.components,
                        date: date
                    )
                    .padding(.horizontal, -16)  // Compensate for section's internal padding
                }
            } else {
                Text("Unable to load scores for this day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func loadDayScores(for date: Date) async {
        isLoadingDayScores = true
        selectedDayScores = await viewModel.loadScoresForDate(date)
        isLoadingDayScores = false
    }

    // MARK: - Baseline Tab

    private var baselineTabContent: some View {
        VStack(spacing: 20) {
            // Edit button (when editable)
            if viewModel.isEditable {
                HStack {
                    Spacer()
                    Button {
                        showBaselineEdit = true
                    } label: {
                        Label("Edit Baseline", systemImage: "pencil.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(color)
                    }
                }
            }

            // Main baseline score
            if let score = viewModel.baselineCompositeScore {
                VStack(spacing: 12) {
                    ScoreRingPill(
                        score: score,
                        iconName: iconName,
                        label: "Current Baseline",
                        size: 100
                    )

                    Text(scoreLabel(for: score))
                        .font(.headline)
                        .foregroundColor(scoreColor(for: score))

                    if let date = viewModel.baselineAssessmentDate {
                        Text("Set on \(formatDateString(date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)

                // Component breakdown
                if viewModel.isComposite {
                    componentBreakdownSection(
                        title: "Score Components",
                        componentScores: viewModel.baselineComponentScores,
                        isBaseline: true
                    )
                }
            } else {
                noDataView(message: "No baseline data available")
            }

            // Editability status
            HStack(spacing: 8) {
                Image(systemName: viewModel.isEditable ? "pencil.circle" : "lock.fill")
                    .font(.body)
                    .foregroundColor(viewModel.isEditable ? color : .secondary)
                Text(viewModel.editabilityReason ?? "Based on onboarding")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)

            // Baseline History Section (only show if there is history)
            if !viewModel.baselineHistory.isEmpty {
                baselineHistorySection
            }
        }
        .padding()
        .sheet(isPresented: $showBaselineEdit) {
            BaselineEditSheet(
                title: "Edit \(title) Baseline",
                baselineTypes: viewModel.relatedBaselineTypes,
                color: color,
                onSave: {
                    Task {
                        await viewModel.refreshBaselines()
                    }
                }
            )
        }
    }

    // MARK: - Baseline History

    private var baselineHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.secondary)
                Text("Previous Baselines")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.baselineHistory) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(baselineDisplayName(for: entry.baselineType))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 8) {
                                Text(formatDateString(entry.assessmentDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(entry.sourceDisplayName)
                                    .font(.caption)
                                    .foregroundColor(entry.source == "tracked" ? color : .secondary)
                            }
                        }

                        Spacer()

                        Text(formatBaselineValue(entry.value, for: entry.baselineType))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func baselineDisplayName(for baselineType: String) -> String {
        // Simple formatting: convert snake_case to Title Case
        baselineType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func formatBaselineValue(_ value: Double, for baselineType: String) -> String {
        // Format based on baseline type patterns
        if baselineType.contains("pct") || baselineType.contains("percent") {
            return "\(Int(value))%"
        } else if baselineType.contains("cups") {
            return "\(Int(value)) cups"
        } else if baselineType.contains("ml") {
            return "\(Int(value)) mL"
        } else if baselineType.contains("oz") {
            return "\(Int(value)) oz"
        } else {
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value))
                : String(format: "%.1f", value)
        }
    }

    // MARK: - Helpers

    private func noDataView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.headline)
            Text("Log data to see your score")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatDateString(_ dateStr: String) -> String {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        if let date = isoFormatter.date(from: dateStr) {
            return displayFormatter.string(from: date)
        }
        return dateStr
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }
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
}

// MARK: - Expandable Component Card

/// Expandable card for a single component score with accordion description
struct ComponentExpandableCard: View {
    let component: ScoreComponentWeight
    let score: Int?
    let description: String?
    @ObservedObject var viewModel: GenericScoreDetailViewModel  // ObservedObject to react to componentScoreTypes loading
    let color: Color
    var date: Date = Date()  // Date to load data for (today or history date)
    var isBaseline: Bool = false  // Baseline mode - don't load daily data

    @State private var isExpanded = false
    @State private var showDescription = false

    private var method: ScoreCalculationMethod {
        viewModel.calculationMethod(for: component.componentScoreType)
    }

    private var statusColor: Color {
        guard let score = score else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    // Allow expansion for both daily and baseline modes
    private var canExpand: Bool {
        true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible) - tappable to expand (if allowed)
            Button {
                guard canExpand else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Score ring pill - give it enough space for the ring stroke
                    ScoreRingPill(
                        score: score ?? 0,
                        iconName: component.iconName ?? "chart.bar.fill",
                        label: "",
                        size: 44
                    )
                    .opacity(score != nil ? 1.0 : 0.3)
                    .frame(width: 52, height: 52)  // Slightly larger than size to prevent clipping

                    // Title and weight
                    VStack(alignment: .leading, spacing: 2) {
                        Text(component.displayName ?? component.componentScoreType)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(component.weightPercentage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Chevron (only show if expandable)
                    if canExpand {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(!canExpand)

            // Expanded content
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal)

                    // Component detail view based on calculation method
                    componentDetailContent
                        .padding(.horizontal)

                    // Description accordion
                    if let desc = description {
                        DisclosureGroup(isExpanded: $showDescription) {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                Text("How this is calculated")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        .tint(.secondary)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var componentDetailContent: some View {
        switch method {
        case .scoringRanges:
            CompactScoringRangesSection(
                component: component,
                score: score,
                viewModel: viewModel,
                color: color,
                date: date,
                isBaseline: isBaseline
            )

        case .timingDistribution:
            CompactTimingSection(
                component: component,
                score: score,
                viewModel: viewModel,
                color: color,
                date: date,
                isBaseline: isBaseline
            )

        case .weightedTiers:
            CompactTierSection(
                component: component,
                score: score,
                viewModel: viewModel,
                color: color,
                date: date,
                isBaseline: isBaseline
            )

        case .composite:
            // Composite scores don't have their own detail view - they aggregate components
            Text("Weighted average of component scores")
                .font(.caption)
                .foregroundColor(.secondary)

        case .unknown:
            // Still loading calculation method - show placeholder
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        default:
            Text("Calculation method: \(method.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Compact Detail Sections

/// Compact scoring ranges display for expandable card
/// Uses pre-calculated data from behavioral_score_components view for values
struct CompactScoringRangesSection: View {
    let component: ScoreComponentWeight
    let score: Int?
    let viewModel: GenericScoreDetailViewModel
    let color: Color
    var date: Date = Date()
    var isBaseline: Bool = false

    @State private var value: Double?
    @State private var ranges: [ScoringRangeData] = []
    @State private var isLoading = true

    private var quantityType: String {
        viewModel.quantityType(for: component.componentScoreType)
    }

    /// For variety scores, use the scoring_ranges_key from the database
    private var rangeKey: String? {
        viewModel.scoringRangesKey(for: component.componentScoreType)
    }

    /// Whether this is a variety score (uses range_key instead of quantity_type)
    private var isVarietyScore: Bool {
        component.componentScoreType.contains("variety")
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let val = value {
                // Current value display
                HStack {
                    // Use appropriate label based on score type
                    let labelText = isVarietyScore
                        ? (isBaseline ? "Baseline:" : (isToday ? "Today:" : "Count:"))
                        : (isBaseline ? "Baseline:" : (isToday ? "Your intake:" : "Intake:"))
                    Text(labelText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatValue(val))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }

                // Compact range rows
                ForEach(ranges) { range in
                    compactRangeRow(range, currentValue: val)
                }
            } else {
                Text("No data for \(isBaseline ? "baseline" : (isToday ? "today" : "this day"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            // Load value from behavioral_score_components (pre-calculated)
            async let componentsTask: [String: ScoreComponent] = {
                if isBaseline {
                    return await viewModel.loadBaselineScoreComponents(scoreType: component.componentScoreType)
                } else {
                    return await viewModel.loadScoreComponents(for: date, scoreType: component.componentScoreType, context: "daily")
                }
            }()
            async let rangesTask = loadRanges()

            let components = await componentsTask
            // Get the "value" component key for scoring_ranges (or "count" for variety)
            if let valueComponent = components["value"] ?? components["count"] {
                value = valueComponent.componentValue
            }
            _ = await rangesTask
            isLoading = false
        }
    }

    private func loadRanges() async {
        do {
            // For variety scores, query by range_key; otherwise by quantity_type
            let results: [ScoringRangeData]
            if isVarietyScore, let key = rangeKey {
                results = try await SupabaseManager.shared.client
                    .from("sample_scoring_ranges")
                    .select("id, range_name, range_low, range_high, score_at_low, score_at_high, frontend_display")
                    .eq("range_key", value: key)
                    .order("range_low", ascending: true)
                    .execute()
                    .value
            } else {
                results = try await SupabaseManager.shared.client
                    .from("sample_scoring_ranges")
                    .select("id, range_name, range_low, range_high, score_at_low, score_at_high, frontend_display")
                    .eq("quantity_type", value: quantityType)
                    .order("range_low", ascending: true)
                    .execute()
                    .value
            }
            ranges = results
        } catch {
            print("Error loading ranges: \(error)")
        }
    }

    @ViewBuilder
    private func compactRangeRow(_ range: ScoringRangeData, currentValue: Double) -> some View {
        let isActive = range.contains(currentValue)
        let statusColor = rangeColor(range.rangeName)

        HStack {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isActive ? statusColor : .secondary.opacity(0.5))

            Text(range.rangeName)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(isActive ? statusColor : .secondary)

            Spacer()

            Text(formatRange(range))
                .font(.caption)
                .foregroundColor(isActive ? statusColor : .secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isActive ? statusColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }

    private func rangeColor(_ name: String) -> Color {
        switch name.uppercased() {
        case "OPTIMAL", "EXCELLENT": return .green
        case "GOOD", "IN RANGE", "MODERATE": return .yellow
        case "FAIR", "LOW", "HIGH": return .orange
        default: return .red
        }
    }

    /// Format value based on quantity type
    private func formatValue(_ val: Double) -> String {
        // Variety scores show count of types
        if isVarietyScore {
            let count = Int(val)
            return count == 1 ? "1 type" : "\(count) types"
        }

        switch quantityType {
        case "water_ml":
            // Convert mL to L for display
            let liters = val / 1000.0
            return liters >= 1.0 ? String(format: "%.1fL", liters) : String(format: "%.2fL", liters)
        case "daily_protein_ratio", "protein_g_per_kg":
            // Show g/kg ratio
            return String(format: "%.2f g/kg", val)
        case "daily_fat_ratio":
            return String(format: "%.2f g/kg", val)
        case "caffeine_mg":
            return String(format: "%.0f mg", val)
        case "steps":
            return String(format: "%.0f", val)
        default:
            return String(format: "%.1f", val)
        }
    }

    /// Format range for display based on quantity type
    private func formatRange(_ range: ScoringRangeData) -> String {
        // For variety, show integer type counts
        if isVarietyScore {
            let low = Int(range.safeLow)
            let high = Int(range.safeHigh)
            if low <= 0 { return "< \(high) types" }
            if high >= 999999 { return "\(low)+ types" }
            return "\(low)–\(high) types"
        }

        let low = range.safeLow
        let high = range.safeHigh
        if low <= 0 { return "< \(formatValue(high))" }
        if high >= 999999 { return "> \(formatValue(low))" }
        return "\(formatValue(low)) – \(formatValue(high))"
    }
}

/// Compact timing distribution display for expandable card
/// Uses pre-calculated data from behavioral_score_components view
struct CompactTimingSection: View {
    let component: ScoreComponentWeight
    let score: Int?
    let viewModel: GenericScoreDetailViewModel
    let color: Color
    var date: Date = Date()
    var isBaseline: Bool = false

    @State private var components: [String: ScoreComponent] = [:]
    @State private var isLoading = true

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var hasData: Bool {
        !components.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if hasData {
                // Timing window rows from pre-calculated components
                ForEach(["morning", "afternoon", "evening", "night"], id: \.self) { window in
                    if let comp = components[window] {
                        compactTimingRow(
                            window: window,
                            percentage: comp.componentPct ?? 0,
                            value: comp.componentValue,
                            target: comp.targetPct ?? 0
                        )
                    } else {
                        // Show row even if no data for this window (0%)
                        compactTimingRow(
                            window: window,
                            percentage: 0,
                            value: nil,
                            target: defaultTarget(for: window)
                        )
                    }
                }
            } else {
                Text("No timing data for \(isToday ? "today" : "this day")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            if isBaseline {
                components = await viewModel.loadBaselineScoreComponents(scoreType: component.componentScoreType)
            } else {
                components = await viewModel.loadScoreComponents(for: date, scoreType: component.componentScoreType, context: "daily")
            }
            isLoading = false
        }
    }

    @ViewBuilder
    private func compactTimingRow(window: String, percentage: Double, value: Double?, target: Double) -> some View {
        let status = timingStatus(actual: percentage, target: target)

        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            // Icon and label
            Image(systemName: windowIcon(window))
                .font(.caption2)
                .foregroundColor(color)

            Text(window.capitalized)
                .font(.caption)
                .frame(width: 70, alignment: .leading)

            // Progress bar with target marker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    // Fill
                    Rectangle()
                        .fill(status.color)
                        .frame(width: geo.size.width * min(percentage / 100, 1), height: 4)

                    // Target marker
                    if target > 0 {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: 10)
                            .offset(x: geo.size.width * (target / 100) - 1)
                    }
                }
            }
            .frame(height: 10)

            // Percentage
            Text("\(Int(percentage))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private func windowIcon(_ window: String) -> String {
        switch window {
        case "morning": return "sunrise.fill"
        case "afternoon": return "sun.max.fill"
        case "evening": return "sunset.fill"
        case "night": return "moon.fill"
        default: return "clock"
        }
    }

    private func timingStatus(actual: Double, target: Double) -> (color: Color, text: String) {
        let deviation = abs(actual - target)
        if deviation <= 5 { return (.green, "On target") }
        else if actual > target { return (.orange, "Above target") }
        else { return (.red, "Below target") }
    }

    private func defaultTarget(for window: String) -> Double {
        switch window {
        case "morning": return 40
        case "afternoon": return 40
        case "evening": return 15
        case "night": return 5
        default: return 0
        }
    }
}

/// Compact tier breakdown display for expandable card
/// Uses pre-calculated data from behavioral_score_components view
struct CompactTierSection: View {
    let component: ScoreComponentWeight
    let score: Int?
    let viewModel: GenericScoreDetailViewModel
    let color: Color
    var date: Date = Date()
    var isBaseline: Bool = false

    @State private var components: [String: ScoreComponent] = [:]
    @State private var isLoading = true

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var hasData: Bool {
        !components.isEmpty
    }

    /// Get tier keys in order (PROTEIN_TIER_1, PROTEIN_TIER_2, etc.)
    private var sortedTierKeys: [String] {
        components.keys.sorted { k1, k2 in
            // Extract tier number from key like PROTEIN_TIER_1
            let num1 = Int(k1.filter { $0.isNumber }) ?? 99
            let num2 = Int(k2.filter { $0.isNumber }) ?? 99
            return num1 < num2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if hasData {
                // Tier rows from pre-calculated components
                ForEach(sortedTierKeys, id: \.self) { tierKey in
                    if let comp = components[tierKey] {
                        compactTierRow(
                            tierKey: tierKey,
                            percentage: comp.componentPct ?? 0,
                            value: comp.componentValue,
                            target: comp.targetPct ?? 0
                        )
                    }
                }
            } else {
                Text("No type data for \(isToday ? "today" : "this day")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            if isBaseline {
                components = await viewModel.loadBaselineScoreComponents(scoreType: component.componentScoreType)
            } else {
                components = await viewModel.loadScoreComponents(for: date, scoreType: component.componentScoreType, context: "daily")
            }
            isLoading = false
        }
    }

    @ViewBuilder
    private func compactTierRow(tierKey: String, percentage: Double, value: Double?, target: Double) -> some View {
        let status = tierStatus(actual: percentage, target: target, tierKey: tierKey)

        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            // Tier label
            Text(tierDisplayName(tierKey))
                .font(.caption)
                .frame(width: 60, alignment: .leading)

            // Progress bar with target marker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    // Fill
                    Rectangle()
                        .fill(status.color)
                        .frame(width: geo.size.width * min(percentage / 100, 1), height: 4)

                    // Target marker
                    if target > 0 {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: 10)
                            .offset(x: geo.size.width * (target / 100) - 1)
                    }
                }
            }
            .frame(height: 10)

            // Value and percentage
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(Int(percentage))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(status.color)
                if let val = value {
                    Text("\(Int(val))g")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, alignment: .trailing)
        }
    }

    private func tierDisplayName(_ tierKey: String) -> String {
        // Convert PROTEIN_TIER_1 -> "Tier 1", FAT_TIER_2 -> "Tier 2"
        if let tierNum = tierKey.last, tierNum.isNumber {
            return "Tier \(tierNum)"
        }
        if tierKey.uppercased().contains("OTHER") {
            return "Other"
        }
        return tierKey
    }

    private func tierStatus(actual: Double, target: Double, tierKey: String) -> (color: Color, text: String) {
        // For tier 3 (limit), lower is better
        let isTier3 = tierKey.contains("3") || tierKey.contains("OTHER")

        if isTier3 {
            // For limit tier, being under target is good
            if actual <= target { return (.green, "On target") }
            else if actual <= target * 1.5 { return (.orange, "Slightly over") }
            else { return (.red, "Over limit") }
        } else {
            // For tier 1 & 2, being near target is good
            let deviation = abs(actual - target)
            if deviation <= 10 { return (.green, "On target") }
            else if actual < target { return (.orange, "Below target") }
            else { return (.yellow, "Above target") }
        }
    }
}

// MARK: - Detail Section Wrappers

/// Wrapper view for tier breakdown that loads data asynchronously
struct TierBreakdownDetailSection: View {
    let component: ScoreComponentWeight
    let score: Int?
    let viewModel: GenericScoreDetailViewModel
    let date: Date
    let color: Color

    @State private var typeValues: [String: Double] = [:]
    @State private var isLoading = true

    private var referenceCategory: String {
        // Derive from score type: protein_type_score -> protein_types
        component.componentScoreType
            .replacingOccurrences(of: "_type_score", with: "_types")
    }

    var body: some View {
        Group {
            if isLoading {
                loadingPlaceholder
            } else if typeValues.isEmpty {
                noDataPlaceholder
            } else {
                TierBreakdownView(
                    title: component.displayName ?? "Type Breakdown",
                    scoreType: component.componentScoreType,
                    referenceCategory: referenceCategory,
                    typeValues: typeValues,
                    unit: "g",
                    score: score,
                    baseColor: color
                )
            }
        }
        .task {
            typeValues = await viewModel.loadTierTypeValues(for: date, category: referenceCategory)
            isLoading = false
        }
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: component.iconName ?? "chart.pie.fill")
                    .foregroundColor(color)
                Text(component.displayName ?? component.componentScoreType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                ProgressView()
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: component.iconName ?? "chart.pie.fill")
                    .foregroundColor(color)
                Text(component.displayName ?? component.componentScoreType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let score = score {
                    Text("\(score)/100")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            Text("No type data available for this day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

/// Wrapper view for timing distribution that loads data asynchronously
struct TimingDistributionDetailSection: View {
    let component: ScoreComponentWeight
    let score: Int?
    let viewModel: GenericScoreDetailViewModel
    let date: Date
    let color: Color

    @State private var windowValues: [String: Double] = [:]
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                loadingPlaceholder
            } else if windowValues.isEmpty {
                noDataPlaceholder
            } else {
                TimingDistributionDetailView(
                    title: component.displayName ?? "Timing Distribution",
                    scoreType: component.componentScoreType,
                    windowValues: windowValues,
                    unit: "ml",
                    score: score,
                    color: color
                )
            }
        }
        .task {
            windowValues = await viewModel.loadTimingWindowValues(for: date, scoreType: component.componentScoreType)
            isLoading = false
        }
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: component.iconName ?? "clock.fill")
                    .foregroundColor(color)
                Text(component.displayName ?? component.componentScoreType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                ProgressView()
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: component.iconName ?? "clock.fill")
                    .foregroundColor(color)
                Text(component.displayName ?? component.componentScoreType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let score = score {
                    Text("\(score)/100")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            Text("No timing data available for this day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

/// Wrapper view for scoring ranges that loads data asynchronously
struct ScoringRangesDetailSection: View {
    let component: ScoreComponentWeight
    let score: Int?
    let viewModel: GenericScoreDetailViewModel
    let date: Date
    let color: Color

    @State private var quantityValue: Double?
    @State private var isLoading = true

    private var quantityType: String {
        viewModel.quantityType(for: component.componentScoreType)
    }

    var body: some View {
        Group {
            if isLoading {
                loadingPlaceholder
            } else if let value = quantityValue {
                ScoringRangesDetailView(
                    title: component.displayName ?? "Amount",
                    value: value,
                    unit: unitFor(component.componentScoreType),
                    quantityType: quantityType,
                    score: score,
                    color: color
                )
            } else {
                noDataPlaceholder
            }
        }
        .task {
            quantityValue = await viewModel.loadQuantityValue(for: date, quantityType: quantityType)
            isLoading = false
        }
    }

    private func unitFor(_ scoreType: String) -> String {
        if scoreType.contains("hydration") || scoreType.contains("water") {
            return "ml"
        } else if scoreType.contains("steps") {
            return "steps"
        } else if scoreType.contains("protein") || scoreType.contains("fat") || scoreType.contains("carb") {
            return "g"
        } else if scoreType.contains("caffeine") {
            return "mg"
        }
        return ""
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: component.iconName ?? "chart.bar.fill")
                    .foregroundColor(color)
                Text(component.displayName ?? component.componentScoreType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                ProgressView()
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: component.iconName ?? "chart.bar.fill")
                    .foregroundColor(color)
                Text(component.displayName ?? component.componentScoreType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let score = score {
                    Text("\(score)/100")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            Text("No amount data available for this day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview
// Note: Uses Calendar.startOfMonth(for:) from existing extensions

#Preview {
    GenericScoreDetailView(
        viewModel: GenericScoreDetailViewModel(scoreType: "hydration_score"),
        title: "Hydration Score",
        iconName: "drop.fill",
        color: .cyan
    )
}
