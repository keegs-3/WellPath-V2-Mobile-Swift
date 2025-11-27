//
//  NutrientTypeView.swift
//  WellPath
//
//  Generic view for nutrient type distribution (legumes, vegetables, whole grains, fruits)
//  Shows Variety Score based on count + evenness, with flat type list (no tiers)
//

import SwiftUI
import Charts

struct NutrientTypeView: View {
    let nutrientType: NutrientTimingType
    let color: Color
    @Binding var showAbout: Bool

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedType: String?
    @State private var showScoringExplanation: Bool = false
    @StateObject private var viewModel: NutrientTypeViewModel

    init(nutrientType: NutrientTimingType, color: Color, showAbout: Binding<Bool>) {
        self.nutrientType = nutrientType
        self.color = color
        self._showAbout = showAbout
        _viewModel = StateObject(wrappedValue: NutrientTypeViewModel(nutrientType: nutrientType, baseColor: color))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Period selector (exclude 6M for type view)
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach([TimePeriod.day, .week, .month, .year], id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .onChange(of: selectedPeriod) { oldValue, newPeriod in
                        Task {
                            await viewModel.loadDataForPeriod(period: newPeriod, date: currentDate)
                        }
                    }

                    // Period navigation with info button
                    HStack {
                        PeriodNavigationView(
                            selectedPeriod: selectedPeriod,
                            currentDate: $currentDate
                        )
                        .onChange(of: currentDate) { oldValue, newDate in
                            Task {
                                await viewModel.loadDataForPeriod(period: selectedPeriod, date: newDate)
                            }
                        }

                        Spacer()

                        // Info button
                        Button(action: {
                            withAnimation {
                                showAbout = true
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(color)
                        }
                    }
                    .padding(.horizontal)

                    // Score card with variety score ring and donut chart
                    VStack(spacing: 0) {
                        // Card header with compact score ring and scoring explanation button
                        HStack(alignment: .center, spacing: 12) {
                            HStack(spacing: 6) {
                                Text("Variety Score")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                // Scoring explanation button
                                Button(action: {
                                    withAnimation {
                                        showScoringExplanation = true
                                    }
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.subheadline)
                                        .foregroundColor(color)
                                }
                            }

                            Spacer()

                            // Compact score ring (50pt)
                            CompactScoreRing(
                                score: viewModel.calculateVarietyScore(for: selectedPeriod),
                                hasData: viewModel.hasData
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.3))

                        // Visual separator
                        Rectangle()
                            .fill(Color(uiColor: .separator))
                            .frame(height: 1)
                            .padding(.horizontal, 16)

                        // Type Distribution header
                        HStack(alignment: .top, spacing: 12) {
                            Text("Type Distribution")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                            // Total or Daily Avg
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(selectedPeriod == .day ? "Total" : "Daily Avg")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatTotalServings())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        // Donut chart with selection highlighting
                        if viewModel.hasData {
                            Chart {
                                ForEach(viewModel.getTypesWithData()) { type in
                                    let servings = viewModel.typeData[type.aggId] ?? 0
                                    let isSelected = selectedType == nil || selectedType == type.aggId

                                    SectorMark(
                                        angle: .value("Servings", servings),
                                        innerRadius: .ratio(0.618),
                                        angularInset: 1.5
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(type.color.opacity(isSelected ? 1.0 : 0.3))
                                }
                            }
                            .frame(height: 140)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        } else {
                            // Empty state
                            VStack(spacing: 8) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))

                                Text("No \(nutrientType.displayName.lowercased()) data")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)

                    // Type list (flat, always visible)
                    if viewModel.hasData {
                        VStack(spacing: 8) {
                            ForEach(viewModel.getTypesWithData()) { type in
                                NutrientTypeRow(
                                    type: type,
                                    servings: viewModel.typeData[type.aggId] ?? 0,
                                    totalServings: viewModel.totalServings,
                                    isSelected: selectedType == type.aggId,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedType == type.aggId {
                                                selectedType = nil
                                            } else {
                                                selectedType = type.aggId
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // No data placeholder
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))

                            Text("No type breakdown available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        // Background provided by parent via metricScreenBackground modifier
        .sheet(isPresented: $showScoringExplanation) {
            varietyScoreExplanationModal
        }
        .task {
            await viewModel.discoverTypeAggregations()
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }

    // MARK: - Variety Score Explanation Modal

    private var varietyScoreExplanationModal: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let explanation = viewModel.scoringExplanation {
                        // Parse and render markdown sections from database
                        let sections = parseScoringExplanation(explanation)

                        // What is Variety Score?
                        if let whatIs = sections["what"] {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "star.circle.fill")
                                        .foregroundColor(color)
                                        .font(.title3)
                                    Text("What is Variety Score?")
                                        .font(.headline)
                                }

                                renderMarkdownText(whatIs)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }

                        // Score Calculation
                        if let calculation = sections["calculation"] {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "function")
                                        .foregroundColor(color)
                                        .font(.title3)
                                    Text("Score Calculation")
                                        .font(.headline)
                                }

                                renderMarkdownText(calculation)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }

                        // Scoring Examples
                        if let examples = sections["examples"] {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "list.number")
                                        .foregroundColor(color)
                                        .font(.title3)
                                    Text("Scoring Examples")
                                        .font(.headline)
                                }

                                renderMarkdownText(examples)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }

                        // Why Variety Matters
                        if let why = sections["why"] {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(color)
                                        .font(.title3)
                                    Text("Why Variety Matters")
                                        .font(.headline)
                                }

                                renderMarkdownText(why)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }
                    } else {
                        // Fallback if no explanation in database
                        Text("Scoring information not available.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Variety Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showScoringExplanation = false
                    }
                }
            }
        }
    }

    /// Parse markdown sections from scoring explanation
    private func parseScoringExplanation(_ text: String) -> [String: String] {
        var sections: [String: String] = [:]

        let components = text.components(separatedBy: "##")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.starts(with: "What is Variety Score?") {
                sections["what"] = trimmed.replacingOccurrences(of: "What is Variety Score?", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.starts(with: "Score Calculation") {
                sections["calculation"] = trimmed.replacingOccurrences(of: "Score Calculation", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.starts(with: "Scoring Examples") {
                sections["examples"] = trimmed.replacingOccurrences(of: "Scoring Examples", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.starts(with: "Why Variety Matters") {
                sections["why"] = trimmed.replacingOccurrences(of: "Why Variety Matters", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return sections
    }

    /// Render markdown text with bold and bullet points
    @ViewBuilder
    private func renderMarkdownText(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let lines = text.components(separatedBy: "\n")

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if trimmed.starts(with: "- ") {
                        // Bullet point
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.secondary)
                            renderTextWithBold(String(trimmed.dropFirst(2)))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Regular text or bold text
                        renderTextWithBold(trimmed)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    /// Render text with **bold** markdown
    private func renderTextWithBold(_ text: String) -> Text {
        var result = Text("")
        let components = text.components(separatedBy: "**")

        for (index, component) in components.enumerated() {
            if index % 2 == 0 {
                result = result + Text(component)
            } else {
                result = result + Text(component).fontWeight(.semibold).foregroundColor(.primary)
            }
        }

        return result
    }

    // MARK: - Helper Functions

    private func formatTotalServings() -> String {
        let total = viewModel.totalServings
        if total == 0 {
            return "—"
        } else if total >= 10 {
            return String(format: "%.1f srv", total)
        } else {
            return String(format: "%.2f srv", total)
        }
    }
}

// MARK: - Nutrient Type Row

struct NutrientTypeRow: View {
    let type: TypeAggregation
    let servings: Double
    let totalServings: Double
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isExpanded = false

    private var percentage: Double {
        guard totalServings > 0 else { return 0 }
        return (servings / totalServings) * 100
    }

    private var hasDescription: Bool {
        type.description != nil && !type.description!.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row content - tappable for chart highlighting
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Color indicator
                    Circle()
                        .fill(type.color)
                        .frame(width: 12, height: 12)

                    // Type name and servings
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("Servings: \(formatServings(servings))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Percentage
                    Text("\(Int(percentage.rounded()))%")
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Chevron for description expand (only if has description)
                    if hasDescription {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expandable description
            if isExpanded, let description = type.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                    .padding(.leading, 24) // Align with text after color dot
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? type.color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
        )
    }

    private func formatServings(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showAbout = false

        var body: some View {
            NutrientTypeView(
                nutrientType: .legumes,
                color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"),
                showAbout: $showAbout
            )
        }
    }

    return PreviewWrapper()
}
