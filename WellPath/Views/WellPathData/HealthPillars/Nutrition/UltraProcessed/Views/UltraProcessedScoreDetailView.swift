//
//  UltraProcessedScoreDetailView.swift
//  WellPath
//
//  Detail view showing ultra-processed score with Today/History/Baseline tabs.
//

import SwiftUI

struct UltraProcessedScoreDetailView: View {
    @ObservedObject var viewModel: UltraProcessedScoreViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScoreTab = .today
    @State private var scoreHistory: [String: Int] = [:]
    @State private var isLoadingHistory = true
    @State private var displayedMonth: Date = Date()

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
            .navigationTitle("Ultra-Processed Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadScoreHistory()
            }
        }
    }

    // MARK: - Today Tab

    private var todayTabContent: some View {
        VStack(spacing: 20) {
            if viewModel.hasDailyScore {
                ScoreRingPill(
                    score: viewModel.dailyScoreValue,
                    iconName: "xmark.circle.fill",
                    label: "Today",
                    size: 90
                )
                .padding(.top, 8)

                Text(scoreLabel(for: viewModel.dailyScoreValue))
                    .font(.headline)
                    .foregroundColor(scoreColor(for: viewModel.dailyScoreValue))

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
                iconName: "xmark.circle.fill",
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

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

        return VStack(spacing: 2) {
            if let score = score {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 2)
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

    // MARK: - Shared Components

    private var noDataTodayView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No data logged today")
                .font(.headline)
            Text("Log your food intake to see today's ultra-processed score")
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
                .eq("quantity_type", value: "ultra_processed_score")
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

#Preview {
    UltraProcessedScoreDetailView(
        viewModel: UltraProcessedScoreViewModel(),
        color: .red
    )
}
