//
//  ProteinTiersView.swift
//  WellPath
//
//  Shows protein quality score and tier breakdown with targets
//  Focuses on "how healthy were my protein choices?"
//

import SwiftUI
import Charts

struct ProteinTiersView: View {
    let color: Color

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedTier: String?
    @State private var selectedType: String?
    @State private var showAbout: Bool = false
    @State private var showScoringExplanation: Bool = false
    @State private var expandedTierId: String?
    @StateObject private var viewModel: ProteinTypeDonutViewModel
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_PROTEIN_TYPE")

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: ProteinTypeDonutViewModel(baseColor: color))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showAbout {
                // About content
                aboutContentView
            } else {
                // Period selector (exclude 6M)
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

                // Period navigation
                PeriodNavigationView(
                    selectedPeriod: selectedPeriod,
                    currentDate: $currentDate
                )
                .onChange(of: currentDate) { oldValue, newDate in
                    Task {
                        await viewModel.loadDataForPeriod(period: selectedPeriod, date: newDate)
                    }
                }

                // Info button (below date picker)
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showAbout = true
                        }
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

                // PINNED: Chart card with score
                VStack(spacing: 0) {
                    // Card header with compact score ring and scoring explanation button
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 6) {
                            Text("Quality Score")
                                .font(.headline)
                                .foregroundColor(.primary)

                            // Scoring explanation button
                            Button(action: {
                                withAnimation {
                                    showScoringExplanation = true
                                }
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(color)
                            }
                        }

                        Spacer()

                        // Compact score ring (50pt)
                        CompactScoreRing(score: viewModel.calculateTypeScore(), hasData: viewModel.totalProtein > 0)
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
                            Text(formatTotalProtein())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Donut chart with gradient colors per protein type
                    if viewModel.totalProtein > 0, let tierConfig = viewModel.tierConfig {
                        Chart {
                            ForEach(getSortedProteinTypes(), id: \.self) { typeId in
                                let grams = viewModel.typeData[typeId] ?? 0
                                if grams > 0 {
                                    let isSelected = (selectedType == nil && selectedTier == nil) ||
                                                    selectedType == typeId ||
                                                    (selectedType == nil && selectedTier != nil && typeInTier(typeId, tierId: selectedTier))

                                    SectorMark(
                                        angle: .value("Grams", grams),
                                        innerRadius: .ratio(0.618),
                                        angularInset: 1.5
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(
                                        getGradientColor(for: typeId)
                                            .opacity(isSelected ? 1.0 : 0.3)
                                    )
                                }
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

                            Text("No protein data")
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
                .padding(.bottom, 8)

                // SCROLLABLE: Tier cards
                ScrollView {
                    VStack(spacing: 16) {
                        // Tier cards
                        if let tierConfig = viewModel.tierConfig {
                            VStack(spacing: 8) {
                                // Regular tiers
                                ForEach(tierConfig.tiers) { tier in
                                    SimpleTierCard(
                                        tier: tier,
                                        tierGrams: calculateTierGrams(tier: tier),
                                        totalProtein: viewModel.totalProtein,
                                        typeData: viewModel.typeData,
                                        viewModel: viewModel,
                                        expandedTierId: $expandedTierId,
                                        selectedTier: $selectedTier,
                                        selectedType: $selectedType
                                    )
                                }

                                // "Other" tier card
                                let otherGrams = calculateOtherGrams()
                                if otherGrams > 0 {
                                    OtherTierCard(
                                        otherGrams: otherGrams,
                                        totalProtein: viewModel.totalProtein,
                                        typeData: viewModel.typeData,
                                        viewModel: viewModel
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .background(
            ZStack {
                // Base background that extends to bottom
                Color(uiColor: .systemGroupedBackground)

                // Gradient overlay at top
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                // Watermark icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: screenIcon)
                            .font(.system(size: 200))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showScoringExplanation) {
            scoringExplanationModal
        }
        .task {
            await viewModel.loadTierConfig()
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
            await educationViewModel.loadEducation()
        }
    }

    // MARK: - Scoring Explanation Modal

    private var scoringExplanationModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let explanation = viewModel.scoringExplanation {
                        // Parse markdown sections
                        let sections = parseScoringExplanation(explanation)

                        // Score Calculation Section
                        if let scoreSection = sections["score"] {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "function")
                                        .foregroundColor(color)
                                        .font(.title3)
                                    Text("Score Calculation")
                                        .font(.headline)
                                }

                                renderScoreCalculation(scoreSection)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }

                        // Tier Overview Section
                        if let tierSection = sections["tier"] {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.3.layers.3d")
                                        .foregroundColor(color)
                                        .font(.title3)
                                    Text("Tier Overview")
                                        .font(.headline)
                                }

                                renderTierOverview(tierSection)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }

                        // Target Percentages Section
                        if let targetSection = sections["target"] {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "target")
                                        .foregroundColor(color)
                                        .font(.title3)
                                    Text("Target Percentages")
                                        .font(.headline)
                                }

                                renderTargetPercentages(targetSection)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        }
                    } else {
                        Text("Scoring information not available.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Quality Score")
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

    // Parse markdown sections from scoring explanation
    private func parseScoringExplanation(_ text: String) -> [String: String] {
        var sections: [String: String] = [:]

        let components = text.components(separatedBy: "##")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.starts(with: "Score Calculation") {
                sections["score"] = trimmed.replacingOccurrences(of: "Score Calculation", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.starts(with: "Tier Overview") {
                sections["tier"] = trimmed.replacingOccurrences(of: "Tier Overview", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.starts(with: "Target Percentages") {
                sections["target"] = trimmed.replacingOccurrences(of: "Target Percentages", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return sections
    }

    // Render markdown text with bold and bullet points
    @ViewBuilder
    private func renderMarkdownSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let lines = text.components(separatedBy: "\n")

            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if trimmed.starts(with: "- ") {
                        // Bullet point
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                            Text(trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Regular text or bold text
                        renderTextWithBold(trimmed)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // Render text with **bold** markdown
    private func renderTextWithBold(_ text: String) -> Text {
        var result = Text("")
        let components = text.components(separatedBy: "**")

        for (index, component) in components.enumerated() {
            if index % 2 == 0 {
                // Regular text
                result = result + Text(component)
            } else {
                // Bold text
                result = result + Text(component).fontWeight(.semibold)
            }
        }

        return result
    }

    // Render tier overview with colored tier indicators
    @ViewBuilder
    private func renderTierOverview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "**", with: "")

                if cleaned.starts(with: "Tier 1") {
                    tierOverviewRow(
                        tierName: "Tier 1 - Best Sources",
                        description: getDescriptionAfterTier(from: lines, startIndex: index),
                        color: MetricsUIConfig.tierGood
                    )
                } else if cleaned.starts(with: "Tier 2") {
                    tierOverviewRow(
                        tierName: "Tier 2 - Good Sources",
                        description: getDescriptionAfterTier(from: lines, startIndex: index),
                        color: MetricsUIConfig.tierMedium
                    )
                } else if cleaned.starts(with: "Tier 3") {
                    tierOverviewRow(
                        tierName: "Tier 3 - Limit Intake",
                        description: getDescriptionAfterTier(from: lines, startIndex: index),
                        color: MetricsUIConfig.tierPoor
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func tierOverviewRow(tierName: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(tierName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func getDescriptionAfterTier(from lines: [String], startIndex: Int) -> String {
        guard startIndex + 1 < lines.count else { return "" }
        return lines[startIndex + 1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "**", with: "")
    }

    // Render score calculation with custom formatting
    @ViewBuilder
    private func renderScoreCalculation(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            // Find intro paragraph (first non-header line)
            if let introLine = lines.first(where: { !$0.starts(with: "**") && !$0.starts(with: "-") }) {
                Text(introLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Find and render formula
            if let formulaLine = lines.first(where: { $0.contains("**Formula:**") }) {
                let formula = formulaLine
                    .replacingOccurrences(of: "**Formula:**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "function")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.7))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Formula")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(formula)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.1))
                )
            }

            // Render "How it works:" section
            if let howItWorksIndex = lines.firstIndex(where: { $0.contains("**How it works:**") }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // Get bullet points for this section
                    let bullets = extractBulletsAfter(lines: lines, startIndex: howItWorksIndex)
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        renderScoringBullet(bullet)
                    }
                }
            }

            // Render "Scoring:" section
            if let scoringIndex = lines.firstIndex(where: { $0.contains("**Scoring:**") }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scoring:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // Get bullet points for this section
                    let bullets = extractBulletsAfter(lines: lines, startIndex: scoringIndex)
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        renderScoringBullet(bullet)
                    }
                }
            }
        }
    }

    // Helper to extract bullets after a section header
    private func extractBulletsAfter(lines: [String], startIndex: Int) -> [String] {
        var bullets: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            // Stop at next section header
            if line.starts(with: "**") && line.hasSuffix("**") && !line.starts(with: "- **") {
                break
            }

            // Add bullet if it starts with "-"
            if line.starts(with: "-") {
                bullets.append(line)
            }

            index += 1
        }

        return bullets
    }

    // Render a single scoring bullet with clean formatting
    @ViewBuilder
    private func renderScoringBullet(_ bullet: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            let content = bullet
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "- ", with: "")

            // Parse bold sections
            if content.contains("**") {
                let components = content.components(separatedBy: "**")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        if !component.isEmpty {
                            if index % 2 == 1 {
                                // Bold text
                                Text(component)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            } else {
                                // Regular text
                                Text(component)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // Render target percentages with visual indicators
    @ViewBuilder
    private func renderTargetPercentages(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Extract intro text
            let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            // Show intro paragraph
            if let firstLine = lines.first, !firstLine.contains("**>") && !firstLine.contains("**~") && !firstLine.contains("**<") {
                Text(firstLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Target rows
            targetPercentageRow(target: ">75%", tier: "Tier 1", sources: "plant proteins, fatty fish", color: MetricsUIConfig.tierGood)
            targetPercentageRow(target: "~20%", tier: "Tier 2", sources: "eggs, lean protein, dairy", color: MetricsUIConfig.tierMedium)
            targetPercentageRow(target: "<5%", tier: "Tier 3", sources: "red/processed meat", color: MetricsUIConfig.tierPoor)

            // Show closing paragraph
            if let lastLine = lines.last, lastLine.contains("Aim to") {
                Text(lastLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func targetPercentageRow(target: String, tier: String, sources: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Target percentage badge
            Text(target)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 60, alignment: .center)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(tier)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(sources)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - About Content View

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    // About content (simple layout)
                    if let education = educationViewModel.education {
                        // About section
                        if let about = education.aboutContent {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(color)
                                    Text("About")
                                        .font(.headline)
                                }
                                Text(about)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Health Impact section
                        if let impact = education.longevityImpact {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "heart.circle.fill")
                                        .foregroundColor(color)
                                    Text("Health Impact")
                                        .font(.headline)
                                }
                                Text(impact)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Quick Tips section
                        if let tips = education.quickTips {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lightbulb.circle.fill")
                                        .foregroundColor(color)
                                    Text("Quick Tips")
                                        .font(.headline)
                                }

                                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .fontWeight(.semibold)
                                            .foregroundColor(color)
                                        Text(tip)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.top, 40) // Space for close button
            }
            .background(Color.clear)

            // Close button (floating, top-right)
            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.pie")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .background(Color.clear)
    }

    // MARK: - Helper Functions

    private func formatTotalProtein() -> String {
        let total = viewModel.totalProtein
        if total == 0 {
            return "—"
        } else if total >= 100 {
            return String(format: "%.0fg", total)
        } else if total >= 10 {
            return String(format: "%.1fg", total)
        } else {
            return String(format: "%.2fg", total)
        }
    }

    private func calculateTierGrams(tier: TierConfig.Tier) -> Double {
        tier.proteinTypes.reduce(0.0) { sum, typeId in
            sum + (viewModel.typeData[typeId] ?? 0)
        }
    }

    private func calculateTierPercentage(tier: TierConfig.Tier?) -> Double {
        guard let tier = tier, viewModel.totalProtein > 0 else { return 0 }
        let tierGrams = calculateTierGrams(tier: tier)
        return (tierGrams / viewModel.totalProtein) * 100
    }

    private func calculateOtherGrams() -> Double {
        guard let tierConfig = viewModel.tierConfig else { return 0 }

        // Get all assigned type IDs
        let assignedTypeIds = Set(tierConfig.tiers.flatMap { $0.proteinTypes })

        // Sum up grams for types not in any tier
        return viewModel.typeData
            .filter { !assignedTypeIds.contains($0.key) }
            .values
            .reduce(0, +)
    }

    private func getTierColor(_ tierId: String) -> Color {
        switch tierId {
        case "PROTEIN_TIER_1":
            return MetricsUIConfig.tierGood
        case "PROTEIN_TIER_2":
            return MetricsUIConfig.tierMedium
        case "PROTEIN_TIER_3":
            return MetricsUIConfig.tierPoor
        default:
            return Color.gray
        }
    }

    // MARK: - Chart Helper Functions

    /// Returns all protein types sorted by tier (1→2→3→Other), then by quantity within each tier
    private func getSortedProteinTypes() -> [String] {
        guard let tierConfig = viewModel.tierConfig else { return [] }

        var sortedTypes: [String] = []

        // Process Tier 1, 2, 3 in order
        for tier in tierConfig.tiers.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            let typesInTier = tier.proteinTypes
                .filter { (viewModel.typeData[$0] ?? 0) > 0 }
                .sorted { (viewModel.typeData[$0] ?? 0) > (viewModel.typeData[$1] ?? 0) }
            sortedTypes.append(contentsOf: typesInTier)
        }

        // Add "Other" types (not in any tier)
        let assignedTypeIds = Set(tierConfig.tiers.flatMap { $0.proteinTypes })
        let otherTypes = viewModel.typeData.keys
            .filter { !assignedTypeIds.contains($0) && (viewModel.typeData[$0] ?? 0) > 0 }
            .sorted { (viewModel.typeData[$0] ?? 0) > (viewModel.typeData[$1] ?? 0) }
        sortedTypes.append(contentsOf: otherTypes)

        return sortedTypes
    }

    /// Check if a protein type belongs to a specific tier
    private func typeInTier(_ typeId: String, tierId: String?) -> Bool {
        guard let tierId = tierId, let tierConfig = viewModel.tierConfig else { return false }

        if let tier = tierConfig.tiers.first(where: { $0.tierId == tierId }) {
            return tier.proteinTypes.contains(typeId)
        }
        return false
    }

    /// Get gradient color for a protein type based on its tier and position within that tier
    private func getGradientColor(for typeId: String) -> Color {
        guard let tierConfig = viewModel.tierConfig else { return .gray }

        // Find which tier this type belongs to
        for tier in tierConfig.tiers {
            if tier.proteinTypes.contains(typeId) {
                // Get all types in this tier that have data, sorted by quantity
                let typesInTier = tier.proteinTypes
                    .filter { (viewModel.typeData[$0] ?? 0) > 0 }
                    .sorted { (viewModel.typeData[$0] ?? 0) > (viewModel.typeData[$1] ?? 0) }

                // Find position of this type
                if let position = typesInTier.firstIndex(of: typeId) {
                    let tierNum: Int
                    switch tier.tierId {
                    case "PROTEIN_TIER_1":
                        tierNum = 1
                    case "PROTEIN_TIER_2":
                        tierNum = 2
                    case "PROTEIN_TIER_3":
                        tierNum = 3
                    default:
                        return .gray
                    }

                    return MetricsUIConfig.getProteinTypeColor(
                        tier: tierNum,
                        positionInTier: position,
                        totalInTier: typesInTier.count
                    )
                }
            }
        }

        // "Other" types get gray
        return Color.gray.opacity(0.7)
    }
}

// MARK: - Compact Score Ring

struct CompactScoreRing: View {
    let score: Double
    let hasData: Bool

    private var scoreColor: Color {
        if score >= 85 {
            return MetricsUIConfig.tierGood
        } else if score >= 70 {
            return MetricsUIConfig.tierMedium
        } else {
            return MetricsUIConfig.tierPoor
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(uiColor: .tertiarySystemGroupedBackground), lineWidth: 6)

            if hasData {
                // Progress ring (only show when there's data)
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [scoreColor.opacity(0.6), scoreColor]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: score)

                // Score text in center
                Text("\(Int(score.rounded()))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(scoreColor)
            } else {
                // No data - show em dash in black
                Text("—")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 50, height: 50)
    }
}

// MARK: - Simple Tier Card (No Mini Rings)

struct SimpleTierCard: View {
    let tier: TierConfig.Tier
    let tierGrams: Double
    let totalProtein: Double
    let typeData: [String: Double]
    let viewModel: ProteinTypeDonutViewModel
    @Binding var expandedTierId: String?
    @Binding var selectedTier: String?
    @Binding var selectedType: String?

    private var isExpanded: Bool {
        expandedTierId == tier.tierId
    }

    private var tierPercentage: Double {
        guard totalProtein > 0 else { return 0 }
        return (tierGrams / totalProtein) * 100
    }

    private var tierColor: Color {
        switch tier.tierId {
        case "PROTEIN_TIER_1":
            return MetricsUIConfig.tierGood
        case "PROTEIN_TIER_2":
            return MetricsUIConfig.tierMedium
        case "PROTEIN_TIER_3":
            return MetricsUIConfig.tierPoor
        default:
            return Color.gray
        }
    }

    private var typesWithData: [String] {
        tier.proteinTypes.filter { typeId in
            (typeData[typeId] ?? 0) > 0
        }
    }

    private var targetPercentage: Double {
        switch tier.tierId {
        case "PROTEIN_TIER_1":
            return 75.0
        case "PROTEIN_TIER_2":
            return 20.0
        case "PROTEIN_TIER_3":
            return 5.0
        default:
            return 0.0
        }
    }

    /// Calculate marker position for target text alignment
    private func calculateMarkerPosition() -> CGFloat {
        // Approximate card width (screen width - padding)
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth = screenWidth - 64 // 32px padding on each side
        return cardWidth * (targetPercentage / 100)
    }

    /// Get gradient color for a protein type within this tier
    private func getTypeGradientColor(_ typeId: String) -> Color {
        // Get all types in this tier sorted by quantity
        let sortedTypes = typesWithData.sorted {
            (typeData[$0] ?? 0) > (typeData[$1] ?? 0)
        }

        // Find position of this type
        if let position = sortedTypes.firstIndex(of: typeId) {
            let tierNum: Int
            switch tier.tierId {
            case "PROTEIN_TIER_1":
                tierNum = 1
            case "PROTEIN_TIER_2":
                tierNum = 2
            case "PROTEIN_TIER_3":
                tierNum = 3
            default:
                return tierColor
            }

            return MetricsUIConfig.getProteinTypeColor(
                tier: tierNum,
                positionInTier: position,
                totalInTier: sortedTypes.count
            )
        }

        return tierColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - clickable for tier selection
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Toggle expansion
                    if expandedTierId == tier.tierId {
                        expandedTierId = nil
                    } else {
                        expandedTierId = tier.tierId
                    }

                    // Select this tier for chart highlighting
                    if selectedTier == tier.tierId {
                        selectedTier = nil
                    } else {
                        selectedTier = tier.tierId
                        selectedType = nil  // Clear individual type selection
                    }
                }
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(tierColor)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.tierName)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("\(formatValue(tierGrams))g · \(Int(tierPercentage.rounded()))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Per-tier stacked progress bar
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .leading) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background (full width, light gray)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                        .frame(height: 8)

                                    // Current progress (tier color)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(tierColor)
                                        .frame(
                                            width: geometry.size.width * min(tierPercentage / 100, 1.0),
                                            height: 8
                                        )

                                    // Target marker (centered vertically on the bar)
                                    Rectangle()
                                        .fill(tierColor)
                                        .frame(width: 3, height: 16)
                                        .position(
                                            x: geometry.size.width * (targetPercentage / 100),
                                            y: 8
                                        )
                                }
                            }
                            .frame(height: 16)
                        }

                        // Target text left-aligned to marker
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: calculateMarkerPosition())

                            Text("Target: \(Int(targetPercentage.rounded()))%")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            // Expanded content
            if isExpanded {
                VStack(spacing: 12) {
                    // Tier description from database
                    if !tier.tierDescription.isEmpty {
                        Text(tier.tierDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Individual types
                    if !typesWithData.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(typesWithData, id: \.self) { typeId in
                                individualTypeRow(typeId)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func individualTypeRow(_ typeId: String) -> some View {
        let grams = typeData[typeId] ?? 0
        let percentage = totalProtein > 0 ? (grams / totalProtein) * 100 : 0
        let isSelected = selectedType == typeId

        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                // Toggle individual type selection
                if selectedType == typeId {
                    selectedType = nil
                    selectedTier = tier.tierId  // Fall back to tier selection
                } else {
                    selectedType = typeId
                    selectedTier = nil  // Clear tier selection
                }
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(getTypeGradientColor(typeId))
                    .frame(width: 8, height: 8)

                Text(viewModel.getDisplayName(for: typeId))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(formatValue(grams))g · \(Int(percentage.rounded()))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? getTypeGradientColor(typeId).opacity(0.2) : Color(uiColor: .tertiarySystemGroupedBackground))
            )
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Other Tier Card

struct OtherTierCard: View {
    let otherGrams: Double
    let totalProtein: Double
    let typeData: [String: Double]
    let viewModel: ProteinTypeDonutViewModel

    @State private var isExpanded = false

    private var otherPercentage: Double {
        guard totalProtein > 0 else { return 0 }
        return (otherGrams / totalProtein) * 100
    }

    private var otherTypeIds: [String] {
        guard let tierConfig = viewModel.tierConfig else { return [] }
        let assignedTypeIds = Set(tierConfig.tiers.flatMap { $0.proteinTypes })
        return typeData.keys.filter { !assignedTypeIds.contains($0) && (typeData[$0] ?? 0) > 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Other")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(formatValue(otherGrams))g · \(Int(otherPercentage.rounded()))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            // Expanded content
            if isExpanded {
                VStack(spacing: 12) {
                    Text("Unclassified or mixed protein sources.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Individual types
                    if !otherTypeIds.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(otherTypeIds, id: \.self) { typeId in
                                individualTypeRow(typeId)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func individualTypeRow(_ typeId: String) -> some View {
        let grams = typeData[typeId] ?? 0

        HStack(spacing: 12) {
            Circle()
                .fill(viewModel.getColor(for: typeId))
                .frame(width: 8, height: 8)

            Text(viewModel.getDisplayName(for: typeId))
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(formatValue(grams))g")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

#Preview {
    ProteinTiersView(color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"))
}
