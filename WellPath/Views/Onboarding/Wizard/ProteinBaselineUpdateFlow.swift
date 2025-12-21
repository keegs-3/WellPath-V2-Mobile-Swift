//
//  ProteinBaselineUpdateFlow.swift
//  WellPath
//
//  Baseline detail view with accordion cards for current tracked, baseline, and history.
//

import SwiftUI
import Supabase

// MARK: - Main View

struct ProteinBaselineUpdateFlow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProteinBaselineUpdateViewModel()
    @State private var showingUpdateSheet = false
    @State private var expandedCard: ExpandedCard? = .baseline

    private let color = MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")

    enum ExpandedCard {
        case tracked, baseline, history
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Protein Baseline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingUpdateSheet) {
                ProteinBaselineEditSheet(viewModel: viewModel) {
                    Task { await viewModel.loadData() }
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Current Tracked (from food logging)
                AccordionCard(
                    title: "Current Tracked",
                    subtitle: viewModel.daysTracked > 0 ? viewModel.trackingProgressText : "No data yet",
                    icon: "chart.line.uptrend.xyaxis",
                    isExpanded: expandedCard == .tracked,
                    color: color
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedCard = expandedCard == .tracked ? nil : .tracked
                    }
                } content: {
                    trackedDetailContent
                }

                // Current Baseline (targets)
                AccordionCard(
                    title: "Current Baseline",
                    subtitle: viewModel.lastUpdatedFormatted,
                    icon: "flag.fill",
                    isExpanded: expandedCard == .baseline,
                    color: color,
                    showEditButton: true,
                    onEdit: { showingUpdateSheet = true }
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedCard = expandedCard == .baseline ? nil : .baseline
                    }
                } content: {
                    baselineDetailContent
                }

                // Baseline History
                if !viewModel.history.isEmpty {
                    AccordionCard(
                        title: "Baseline History",
                        subtitle: "\(viewModel.historyCount) previous \(viewModel.historyCount == 1 ? "baseline" : "baselines")",
                        icon: "clock.arrow.circlepath",
                        isExpanded: expandedCard == .history,
                        color: color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedCard = expandedCard == .history ? nil : .history
                        }
                    } content: {
                        historyDetailContent
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Tracked Detail Content

    private var trackedDetailContent: some View {
        VStack(spacing: 16) {
            // Always show tracking progress indicator
            if viewModel.daysTracked > 0 {
                HStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(uiColor: .tertiarySystemGroupedBackground))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewModel.hasSufficientData ? Color.green : color)
                                .frame(width: geo.size.width * min(Double(viewModel.daysTracked) / 15.0, 1.0))
                        }
                    }
                    .frame(height: 8)

                    Text(viewModel.trackingProgressText)
                        .font(.caption)
                        .foregroundColor(viewModel.hasSufficientData ? .green : .secondary)
                }

                if !viewModel.hasSufficientData {
                    Text("Track \(15 - viewModel.daysTracked) more days to unlock tracked values")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.bottom, 8)
                }
            }

            if viewModel.hasTrackedData {
                // Amount
                BaselineDetailRow(
                    label: "Daily Amount",
                    value: viewModel.trackedDailyAverage,
                    unit: "g",
                    icon: "scalemass",
                    color: color
                )

                Divider()

                // Type breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type Breakdown")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TierBar(label: "Tier 1", percentage: viewModel.trackedTierBest, color: MetricsUIConfig.tierGood)
                    TierBar(label: "Tier 2", percentage: viewModel.trackedTierGood, color: MetricsUIConfig.tierMedium)
                    TierBar(label: "Tier 3", percentage: viewModel.trackedTierLimit, color: MetricsUIConfig.tierPoor)

                    if let score = viewModel.trackedTypeScore {
                        HStack {
                            Text("Type Score:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(score))/100")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(typeScoreColor(score))
                        }
                        .padding(.top, 4)
                    }
                }

                Divider()

                // Ratio
                BaselineDetailRow(
                    label: "Ratio",
                    value: viewModel.trackedRatio,
                    unit: "g/kg",
                    icon: "percent",
                    color: color,
                    decimals: 2,
                    status: viewModel.trackedRatioStatus
                )
            } else if viewModel.daysTracked > 0 && !viewModel.hasSufficientData {
                // Have some data but not enough
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Gathering data...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("Keep logging to see your averages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No protein logged yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Log meals to start tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Baseline Detail Content

    private var baselineDetailContent: some View {
        VStack(spacing: 16) {
            // Amount
            BaselineDetailRow(
                label: "Daily Amount",
                value: viewModel.currentBaselines["daily_protein_g"],
                unit: "g",
                icon: "scalemass",
                color: color
            )

            Divider()

            // Type breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Type Breakdown")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TierBar(label: "Tier 1", percentage: viewModel.currentBaselines["protein_tier1_pct"], color: MetricsUIConfig.tierGood)
                TierBar(label: "Tier 2", percentage: viewModel.currentBaselines["protein_tier2_pct"], color: MetricsUIConfig.tierMedium)
                TierBar(label: "Tier 3", percentage: viewModel.currentBaselines["protein_tier3_pct"], color: MetricsUIConfig.tierPoor)

                if let score = viewModel.currentBaselines["protein_type_score"] {
                    HStack {
                        Text("Type Score:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(score))/100")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(typeScoreColor(score))
                    }
                    .padding(.top, 4)
                }
            }

            Divider()

            // Ratio + Weight
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let ratio = viewModel.currentBaselines["daily_protein_ratio"] {
                        Text(String(format: "%.2f g/kg", ratio))
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("--")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Weight at Baseline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let weight = viewModel.baselineWeightKg {
                        Text(String(format: "%.1f kg", weight))
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("--")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - History Detail Content

    private var historyDetailContent: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupedHistory.keys.sorted().reversed(), id: \.self) { date in
                if let entries = viewModel.groupedHistory[date] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(date)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(entries) { entry in
                            HStack {
                                Text(entry.baselineLabel)
                                    .font(.subheadline)
                                Spacer()
                                Text(entry.formattedValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(color)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if date != viewModel.groupedHistory.keys.sorted().reversed().last {
                        Divider()
                    }
                }
            }
        }
    }

    private func typeScoreColor(_ score: Double?) -> Color {
        guard let score = score else { return .secondary }
        if score >= 85 { return .green }
        else if score >= 70 { return .blue }
        else if score >= 55 { return .orange }
        else { return .red }
    }
}

// MARK: - Accordion Card

struct AccordionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let isExpanded: Bool
    let color: Color
    var showEditButton: Bool = false
    var onEdit: (() -> Void)? = nil
    let onTap: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if showEditButton && isExpanded {
                        Button {
                            onEdit?()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(color)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                content
                    .padding()
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Baseline Detail Row

struct BaselineDetailRow: View {
    let label: String
    let value: Double?
    let unit: String
    let icon: String
    let color: Color
    var decimals: Int = 0
    var status: String? = nil

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color.opacity(0.7))
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if let value = value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(decimals > 0 ? String(format: "%.\(decimals)f", value) : "\(Int(value))")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let status = status {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status == "Optimal" ? .green : .orange)
                }
            } else {
                Text("--")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Tier Bar

struct TierBar: View {
    let label: String
    let percentage: Double?
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min((percentage ?? 0) / 100, 1.0))
                }
            }
            .frame(height: 8)

            Text(percentage != nil ? "\(Int(percentage!))%" : "--%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Edit Sheet

struct ProteinBaselineEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProteinBaselineUpdateViewModel
    let onSave: () -> Void

    private let color = MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Baseline questions
                    ForEach(viewModel.baselineQuestions) { question in
                        BaselineQuestionCard(
                            question: question,
                            value: Binding(
                                get: { viewModel.getValue(for: question) },
                                set: { viewModel.setValue($0, for: question) }
                            ),
                            color: color
                        )
                    }

                    // Tier validation
                    tierValidationView

                    // Calculated values
                    calculatedValuesView
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Update Baseline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.saveBaselines()
                            if success {
                                onSave()
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
        }
    }

    private var tierValidationView: some View {
        HStack {
            Text("Tier Total:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(viewModel.tierPercentageSum))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.tierPercentagesValid ? .green : .orange)
            if viewModel.tierPercentagesValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("(should be 100%)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var calculatedValuesView: some View {
        VStack(spacing: 12) {
            if let typeScore = viewModel.calculatedTypeScore {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(color)
                    Text("Type Score:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f/100", typeScore))
                        .font(.headline)
                        .foregroundColor(typeScoreColor(typeScore))
                }
            }

            if let ratio = viewModel.calculatedRatio {
                HStack {
                    Image(systemName: "percent")
                        .foregroundColor(color)
                    Text("Ratio:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f g/kg", ratio))
                        .font(.headline)
                        .foregroundColor(viewModel.ratioIsOptimal ? .green : color)
                }
            } else if viewModel.patientWeightKg == nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Add weight to calculate ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func typeScoreColor(_ score: Double?) -> Color {
        guard let score = score else { return .secondary }
        if score >= 85 { return .green }
        else if score >= 70 { return .blue }
        else if score >= 55 { return .orange }
        else { return .red }
    }
}

// MARK: - View Model

@MainActor
class ProteinBaselineUpdateViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var isSaving = false

    @Published var baselineQuestions: [BaselineQuestion] = []
    @Published var responses: [String: Double] = [:]
    @Published var currentBaselines: [String: Double] = [:]
    @Published var history: [BaselineHistoryEntry] = []
    @Published var changes: [BaselineChange] = []

    @Published var patientWeightKg: Double?
    @Published var baselineWeightKg: Double?  // Weight at time of baseline
    @Published var lastUpdated: Date?

    var lastUpdatedFormatted: String {
        guard let date = lastUpdated else { return "Not set" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Set \(formatter.string(from: date))"
    }

    // Tracked data (from food logging)
    @Published var trackedDailyAverage: Double?
    @Published var trackedTierBest: Double?
    @Published var trackedTierGood: Double?
    @Published var trackedTierLimit: Double?
    @Published var trackedTypeScore: Double?
    @Published var trackedRatio: Double?
    @Published var daysTracked: Int = 0
    @Published var trackingSource: String = "baseline"  // "tracked" or "baseline"

    private let categoryId = "CAT_PROTEIN"
    private let minDaysRequired = 15  // Matches backend threshold

    // MARK: - Computed Properties

    var hasTrackedData: Bool {
        trackingSource == "tracked" && trackedDailyAverage != nil
    }

    var hasSufficientData: Bool {
        daysTracked >= minDaysRequired
    }

    var trackingProgressText: String {
        if hasSufficientData {
            return "\(daysTracked) days tracked"
        } else {
            return "\(daysTracked)/\(minDaysRequired) days tracked"
        }
    }

    var trackedRatioStatus: String? {
        guard let ratio = trackedRatio else { return nil }
        if ratio >= 1.2 && ratio <= 1.6 { return "Optimal" }
        else if ratio < 1.2 { return "Below target" }
        else { return "Above target" }
    }

    var baselineRatioStatus: String? {
        guard let ratio = currentBaselines["daily_protein_ratio"] else { return nil }
        if ratio >= 1.2 && ratio <= 1.6 { return "Optimal" }
        else if ratio < 1.2 { return "Below target" }
        else { return "Above target" }
    }

    var historyCount: Int {
        // Count unique assessment dates
        Set(history.map { $0.assessmentDate }).count
    }

    var groupedHistory: [String: [BaselineHistoryEntry]] {
        Dictionary(grouping: history) { $0.assessmentDate }
    }

    var tierPercentageSum: Double {
        let best = responses["BQ_PROTEIN_TIER_BEST"] ?? 0
        let good = responses["BQ_PROTEIN_TIER_GOOD"] ?? 0
        let limit = responses["BQ_PROTEIN_TIER_LIMIT"] ?? 0
        return best + good + limit
    }

    var tierPercentagesValid: Bool {
        abs(tierPercentageSum - 100) < 0.01
    }

    var calculatedTypeScore: Double? {
        guard tierPercentagesValid else { return nil }
        let best = responses["BQ_PROTEIN_TIER_BEST"] ?? 0
        let good = responses["BQ_PROTEIN_TIER_GOOD"] ?? 0
        let limit = responses["BQ_PROTEIN_TIER_LIMIT"] ?? 0
        return (best * 100 + good * 60 + limit * 20) / 100
    }

    var calculatedRatio: Double? {
        guard let dailyProtein = responses["BQ_PROTEIN_TOTAL"],
              let weight = patientWeightKg,
              weight > 0 else { return nil }
        return dailyProtein / weight
    }

    var ratioIsOptimal: Bool {
        guard let ratio = calculatedRatio else { return false }
        return ratio >= 1.2 && ratio <= 1.6
    }

    var canSave: Bool {
        responses["BQ_PROTEIN_TOTAL"] != nil && tierPercentagesValid
    }

    // MARK: - Load Data

    func loadData() async {
        isLoading = true

        async let questionsTask: () = loadQuestions()
        async let baselinesTask: () = loadCurrentBaselines()
        async let historyTask: () = loadHistory()
        async let weightTask: () = loadPatientWeight()
        async let trackedTask: () = loadTrackedData()

        _ = await (questionsTask, baselinesTask, historyTask, weightTask, trackedTask)

        // Pre-populate responses from current baselines
        for question in baselineQuestions {
            if let baselineType = question.baselineType,
               let existingValue = currentBaselines[baselineType] {
                responses[question.questionId] = existingValue
            }
        }

        isLoading = false
    }

    private func loadTrackedData() async {
        // TODO: Implement new tracked data loading once baseline/tracking architecture is rebuilt
        // The old protein-specific views have been deprecated in favor of a generic approach
        // For now, tracked data will show as "No data yet"
        //
        // New system will:
        // 1. Query patient_quantity_samples directly
        // 2. Use generic threshold config (replacing behavioral_threshold_config)
        // 3. Determine if tracked data meets threshold (14 days in 21-day window)
        // 4. Return tracked averages if sufficient data exists

        daysTracked = 0
        trackingSource = "baseline"
    }

    private func loadQuestions() async {
        do {
            let client = SupabaseManager.shared.client

            let questions: [BaselineQuestion] = try await client
                .from("baseline_questions")
                .select()
                .eq("category_id", value: categoryId)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            baselineQuestions = questions
        } catch {
            print("Error loading questions: \(error)")
        }
    }

    private func loadCurrentBaselines() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct BaselineData: Decodable {
                let baselineType: String
                let value: Double
                let updatedAt: Date?

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case value
                    case updatedAt = "updated_at"
                }
            }

            let baselines: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value, updated_at")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
                .execute()
                .value

            for baseline in baselines {
                // Store baseline weight separately
                if baseline.baselineType == "baseline_weight_kg" {
                    baselineWeightKg = baseline.value
                } else {
                    currentBaselines[baseline.baselineType] = baseline.value
                }
                if let updated = baseline.updatedAt, (lastUpdated == nil || updated > lastUpdated!) {
                    lastUpdated = updated
                }
            }

            // Calculate baseline weight from ratio if not stored directly
            if baselineWeightKg == nil,
               let dailyProtein = currentBaselines["daily_protein_g"],
               let ratio = currentBaselines["daily_protein_ratio"],
               ratio > 0 {
                baselineWeightKg = dailyProtein / ratio
            }
        } catch {
            print("Error loading baselines: \(error)")
        }
    }

    private func loadHistory() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct HistoryData: Decodable {
                let id: UUID
                let baselineType: String
                let value: Double
                let unit: String?
                let source: String?
                let assessmentDate: String
                let supersededAt: Date?

                enum CodingKeys: String, CodingKey {
                    case id
                    case baselineType = "baseline_type"
                    case value
                    case unit
                    case source
                    case assessmentDate = "assessment_date"
                    case supersededAt = "superseded_at"
                }
            }

            let historyData: [HistoryData] = try await client
                .from("patient_baseline_samples")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: false)
                .order("superseded_at", ascending: false)
                .limit(20)
                .execute()
                .value

            history = historyData.map { data in
                BaselineHistoryEntry(
                    id: data.id,
                    baselineType: data.baselineType,
                    value: data.value,
                    unit: data.unit,
                    source: data.source,
                    assessmentDate: data.assessmentDate,
                    supersededAt: data.supersededAt
                )
            }
        } catch {
            print("Error loading history: \(error)")
        }
    }

    private func loadPatientWeight() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct WeightData: Decodable {
                let value: Double
                let unit: String?

                enum CodingKeys: String, CodingKey {
                    case value = "quantity_value"
                    case unit = "quantity_unit"
                }
            }

            let results: [WeightData] = try await client
                .from("patient_quantity_samples")
                .select("quantity_value, quantity_unit")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "bodyweight")
                .order("aggregation_date", ascending: false)
                .limit(1)
                .execute()
                .value

            if let weight = results.first {
                if weight.unit == "lb" || weight.unit == "pound" || weight.unit == "lbs" {
                    patientWeightKg = weight.value * 0.453592
                } else {
                    patientWeightKg = weight.value
                }
            }
        } catch {
            print("Error loading weight: \(error)")
        }
    }

    func getValue(for question: BaselineQuestion) -> Double? {
        responses[question.questionId]
    }

    func setValue(_ value: Double?, for question: BaselineQuestion) {
        if let value = value {
            responses[question.questionId] = value
        } else {
            responses.removeValue(forKey: question.questionId)
        }
    }

    func saveBaselines() async -> Bool {
        isSaving = true
        changes = []

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let today = dateFormatter.string(from: Date())

            // Save question responses (only if value changed)
            for question in baselineQuestions {
                guard let baselineType = question.baselineType,
                      let value = responses[question.questionId] else { continue }

                let oldValue = currentBaselines[baselineType]

                // Skip if value unchanged
                if let old = oldValue, old == value { continue }

                // Track change
                if let old = oldValue {
                    changes.append(BaselineChange(
                        type: baselineType,
                        label: question.questionText,
                        oldValue: old,
                        newValue: value,
                        unit: question.unitLabel
                    ))
                }

                let unit = unitForBaselineType(baselineType)

                let record: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string(baselineType),
                    "value": .double(value),
                    "unit": .string(unit),
                    "source": .string("manual_update"),
                    "assessment_date": .string(today),
                    "is_current": .bool(true)
                ]

                // INSERT triggers the handle_baseline_update trigger which marks old rows as superseded
                try await client
                    .from("patient_baseline_samples")
                    .insert(record)
                    .execute()

                currentBaselines[baselineType] = value
            }

            // Save calculated type score (only if changed)
            if let typeScore = calculatedTypeScore {
                let oldScore = currentBaselines["protein_type_score"]

                if oldScore == nil || oldScore != typeScore {
                    if let old = oldScore {
                        changes.append(BaselineChange(
                            type: "protein_type_score",
                            label: "Type Score",
                            oldValue: old,
                            newValue: typeScore,
                            unit: "/100"
                        ))
                    }

                    let typeRecord: [String: AnyJSON] = [
                        "patient_id": .string(userId.uuidString),
                        "baseline_type": .string("protein_type_score"),
                        "value": .double(typeScore),
                        "unit": .string("score"),
                        "source": .string("calculated"),
                        "assessment_date": .string(today),
                        "is_current": .bool(true)
                    ]

                    try await client
                        .from("patient_baseline_samples")
                        .insert(typeRecord)
                        .execute()

                    currentBaselines["protein_type_score"] = typeScore
                }
            }

            // Save calculated ratio (only if changed)
            if let ratio = calculatedRatio {
                let oldRatio = currentBaselines["daily_protein_ratio"]

                if oldRatio == nil || oldRatio != ratio {
                    if let old = oldRatio {
                        changes.append(BaselineChange(
                            type: "daily_protein_ratio",
                            label: "Protein Ratio",
                            oldValue: old,
                            newValue: ratio,
                            unit: "g/kg"
                        ))
                    }

                    let ratioRecord: [String: AnyJSON] = [
                        "patient_id": .string(userId.uuidString),
                        "baseline_type": .string("daily_protein_ratio"),
                        "value": .double(ratio),
                        "unit": .string("grams_per_kg"),
                        "source": .string("calculated"),
                        "assessment_date": .string(today),
                        "is_current": .bool(true)
                    ]

                    try await client
                        .from("patient_baseline_samples")
                        .insert(ratioRecord)
                        .execute()

                    currentBaselines["daily_protein_ratio"] = ratio
                }
            }

            // Reload history to show new entries
            await loadHistory()

            isSaving = false
            return true

        } catch {
            print("Error saving baselines: \(error)")
            isSaving = false
            return false
        }
    }

    private func unitForBaselineType(_ type: String) -> String {
        switch type {
        case "daily_protein_g":
            return "gram"
        case let t where t.contains("pct"):
            return "percent"
        case let t where t.contains("servings"):
            return "serving"
        default:
            return "unit"
        }
    }
}

// MARK: - Supporting Models

struct BaselineHistoryEntry: Identifiable {
    let id: UUID
    let baselineType: String
    let value: Double
    let unit: String?
    let source: String?
    let assessmentDate: String
    let supersededAt: Date?

    var baselineLabel: String {
        switch baselineType {
        case "daily_protein_g": return "Daily Amount"
        case "protein_type_score": return "Type Score"
        case "daily_protein_ratio": return "Ratio"
        case "protein_tier1_pct": return "Tier 1 %"
        case "protein_tier2_pct": return "Tier 2 %"
        case "protein_tier3_pct": return "Tier 3 %"
        case "baseline_weight_kg": return "Weight"
        default: return baselineType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var formattedValue: String {
        switch baselineType {
        case "daily_protein_g": return "\(Int(value))g"
        case "protein_type_score": return String(format: "%.0f/100", value)
        case "daily_protein_ratio": return String(format: "%.2f g/kg", value)
        case "baseline_weight_kg": return String(format: "%.1f kg", value)
        case let t where t.contains("pct"): return "\(Int(value))%"
        default: return String(format: "%.1f", value)
        }
    }
}

struct BaselineChange {
    let type: String
    let label: String
    let oldValue: Double
    let newValue: Double
    let unit: String

    var oldFormatted: String {
        formatValue(oldValue)
    }

    var newFormatted: String {
        formatValue(newValue)
    }

    private func formatValue(_ val: Double) -> String {
        if type.contains("ratio") {
            return String(format: "%.2f%@", val, unit)
        } else if val == floor(val) {
            return "\(Int(val))\(unit)"
        } else {
            return String(format: "%.1f%@", val, unit)
        }
    }
}

// MARK: - Preview

#Preview("Baseline Update Flow") {
    ProteinBaselineUpdateFlow()
}
