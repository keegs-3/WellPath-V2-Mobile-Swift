//
//  CaffeineTypeView.swift
//  WellPath
//
//  Full view for Caffeine Type metric (DISP_CAFFEINE_TYPE).
//  Shows caffeine source quality breakdown with 2 tiers:
//  - Tier 1: Quality Sources (tea, matcha, brewed coffee)
//  - Tier 2: Limit Sources (energy drinks, pre-workout, sodas)
//

import SwiftUI
import Charts

struct CaffeineTypeView: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedTier: String?
    @State private var selectedType: String?
    @State private var showAboutModal: Bool = false
    @State private var showScoringExplanation: Bool = false
    @State private var expandedTierId: String?
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @StateObject private var viewModel: CaffeineTypeDonutViewModel

    private let metricId = "DISP_CAFFEINE_TYPE"
    private let metricName = "Caffeine Type"

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: CaffeineTypeDonutViewModel(baseColor: color))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                } else {
                    VStack(spacing: 0) {
                        // Period selector
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach([TimePeriod.day, .week, .month, .year], id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .onChange(of: selectedPeriod) { _, newPeriod in
                            Task {
                                await viewModel.loadDataForPeriod(period: newPeriod, date: currentDate)
                            }
                        }

                        // Period navigation
                        HStack {
                            PeriodNavigationView(
                                selectedPeriod: selectedPeriod,
                                currentDate: $currentDate
                            )
                            .onChange(of: currentDate) { _, newDate in
                                Task {
                                    await viewModel.loadDataForPeriod(period: selectedPeriod, date: newDate)
                                }
                            }

                            Spacer()

                            Button(action: {
                                showAboutModal = true
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.title3)
                                    .foregroundColor(color)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Chart card with score
                        VStack(spacing: 0) {
                            // Header with score
                            HStack(alignment: .center, spacing: 12) {
                                HStack(spacing: 6) {
                                    Text("Quality Score")
                                        .font(.headline)
                                        .foregroundColor(.primary)

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

                                CompactScoreRing(score: viewModel.calculateTypeScore(), hasData: viewModel.totalCaffeine > 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.3))

                            Rectangle()
                                .fill(Color(uiColor: .separator))
                                .frame(height: 1)
                                .padding(.horizontal, 16)

                            // Distribution header
                            HStack(alignment: .top, spacing: 12) {
                                Text("Source Distribution")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(selectedPeriod == .day ? "Total" : "Daily Avg")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatTotalCaffeine())
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                            // Donut chart
                            if viewModel.totalCaffeine > 0, let tierConfig = viewModel.tierConfig {
                                Chart {
                                    ForEach(getSortedCaffeineTypes(), id: \.self) { typeId in
                                        let mg = viewModel.typeData[typeId] ?? 0
                                        if mg > 0 {
                                            let isSelected = (selectedType == nil && selectedTier == nil) ||
                                                            selectedType == typeId ||
                                                            (selectedType == nil && selectedTier != nil && typeInTier(typeId, tierId: selectedTier))

                                            SectorMark(
                                                angle: .value("mg", mg),
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
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.pie")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.5))

                                    Text("No caffeine data")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Button(action: {
                                        showingEntryForm = true
                                    }) {
                                        Label("Log Caffeine", systemImage: "plus")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(color)
                                            .cornerRadius(8)
                                    }
                                }
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        // Tier cards
                        if let tierConfig = viewModel.tierConfig {
                            VStack(spacing: 8) {
                                ForEach(tierConfig.tiers.filter { $0.tierId != "CAFFEINE_TIER_OTHER" }) { tier in
                                    CaffeineTierCard(
                                        tier: tier,
                                        tierMg: calculateTierMg(tier: tier),
                                        totalCaffeine: viewModel.totalCaffeine,
                                        typeData: viewModel.typeData,
                                        viewModel: viewModel,
                                        expandedTierId: $expandedTierId,
                                        selectedTier: $selectedTier,
                                        selectedType: $selectedType
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Caffeine Sources")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .metric,
                    itemId: "DISP_CAFFEINE_TYPE",
                    displayName: "Caffeine Sources",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_CAFFEINE_TYPE",
                    sectionId: "NAV_NUTRITION"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            CaffeineEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .caffeine)
        }
        .sheet(isPresented: $showScoringExplanation) {
            scoringExplanationModal
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadCaffeineTypeDisplayNames()
            await viewModel.loadTierConfig()
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }

    // MARK: - Scoring Explanation Modal

    private var scoringExplanationModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // How it's calculated
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "function")
                                .foregroundColor(color)
                                .font(.title3)
                            Text("How It's Calculated")
                                .font(.headline)
                        }

                        Text("Your caffeine quality score is based on the percentage of your caffeine that comes from quality sources (Tier 1) vs limit sources (Tier 2).")
                            .font(.body)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            scoreRangeRow(range: "90%+ from Tier 1", score: "80-100", color: MetricsUIConfig.tierGood)
                            scoreRangeRow(range: "70-90% from Tier 1", score: "60-80", color: .yellow)
                            scoreRangeRow(range: "50-70% from Tier 1", score: "40-60", color: .orange)
                            scoreRangeRow(range: "<50% from Tier 1", score: "0-40", color: MetricsUIConfig.tierPoor)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )

                    // Tier overview
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.3.layers.3d")
                                .foregroundColor(color)
                                .font(.title3)
                            Text("Source Tiers")
                                .font(.headline)
                        }

                        tierExplanationRow(
                            name: "Quality Sources (Tier 1)",
                            description: "Natural caffeine with health benefits: green tea, black tea, matcha, brewed coffee. Rich in antioxidants and polyphenols.",
                            target: "90%+",
                            color: MetricsUIConfig.tierGood
                        )

                        tierExplanationRow(
                            name: "Limit Sources (Tier 2)",
                            description: "Processed sources with added sugars or artificial ingredients: energy drinks, pre-workout, caffeinated sodas, caffeine pills.",
                            target: "<10%",
                            color: MetricsUIConfig.tierPoor
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
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

    @ViewBuilder
    private func scoreRangeRow(range: String, score: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(range)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text("Score: \(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func tierExplanationRow(name: String, description: String, target: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Target: \(target)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Helper Functions

    private func formatTotalCaffeine() -> String {
        let total = viewModel.totalCaffeine
        if total == 0 {
            return "—"
        } else {
            return String(format: "%.0f mg", total)
        }
    }

    private func calculateTierMg(tier: CaffeineTierConfig.Tier) -> Double {
        tier.caffeineTypes.reduce(0.0) { sum, typeId in
            sum + (viewModel.typeData[typeId] ?? 0)
        }
    }

    private func getSortedCaffeineTypes() -> [String] {
        guard let tierConfig = viewModel.tierConfig else { return [] }

        var sortedTypes: [String] = []

        // Process tiers in order
        for tier in tierConfig.tiers.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            let typesInTier = tier.caffeineTypes
                .filter { (viewModel.typeData[$0] ?? 0) > 0 }
                .sorted { (viewModel.typeData[$0] ?? 0) > (viewModel.typeData[$1] ?? 0) }
            sortedTypes.append(contentsOf: typesInTier)
        }

        // Add any types not in tiers
        let assignedTypeIds = Set(tierConfig.tiers.flatMap { $0.caffeineTypes })
        let otherTypes = viewModel.typeData.keys
            .filter { !assignedTypeIds.contains($0) && (viewModel.typeData[$0] ?? 0) > 0 }
            .sorted { (viewModel.typeData[$0] ?? 0) > (viewModel.typeData[$1] ?? 0) }
        sortedTypes.append(contentsOf: otherTypes)

        return sortedTypes
    }

    private func typeInTier(_ typeId: String, tierId: String?) -> Bool {
        guard let tierId = tierId, let tierConfig = viewModel.tierConfig else { return false }

        if let tier = tierConfig.tiers.first(where: { $0.tierId == tierId }) {
            return tier.caffeineTypes.contains(typeId)
        }
        return false
    }

    private func getGradientColor(for typeId: String) -> Color {
        guard let tierConfig = viewModel.tierConfig else { return .gray }

        for tier in tierConfig.tiers {
            if tier.caffeineTypes.contains(typeId) {
                let typesInTier = tier.caffeineTypes
                    .filter { (viewModel.typeData[$0] ?? 0) > 0 }
                    .sorted { (viewModel.typeData[$0] ?? 0) > (viewModel.typeData[$1] ?? 0) }

                if let position = typesInTier.firstIndex(of: typeId) {
                    let tierNum: Int
                    switch tier.tierId {
                    case "CAFFEINE_TIER_1":
                        tierNum = 1
                    case "CAFFEINE_TIER_2":
                        tierNum = 3  // Use tier 3 colors (orange/red) for limit sources
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

        return Color.gray.opacity(0.7)
    }
}

// MARK: - Caffeine Tier Card

struct CaffeineTierCard: View {
    let tier: CaffeineTierConfig.Tier
    let tierMg: Double
    let totalCaffeine: Double
    let typeData: [String: Double]
    let viewModel: CaffeineTypeDonutViewModel
    @Binding var expandedTierId: String?
    @Binding var selectedTier: String?
    @Binding var selectedType: String?

    private var isExpanded: Bool {
        expandedTierId == tier.tierId
    }

    private var tierPercentage: Double {
        guard totalCaffeine > 0 else { return 0 }
        return (tierMg / totalCaffeine) * 100
    }

    private var tierColor: Color {
        switch tier.tierId {
        case "CAFFEINE_TIER_1":
            return MetricsUIConfig.tierGood
        case "CAFFEINE_TIER_2":
            return MetricsUIConfig.tierPoor
        default:
            return Color.gray
        }
    }

    private var typesWithData: [String] {
        tier.caffeineTypes.filter { typeId in
            (typeData[typeId] ?? 0) > 0
        }
    }

    private var targetPercentage: Double {
        Double(tier.targetPercentage)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if expandedTierId == tier.tierId {
                        expandedTierId = nil
                    } else {
                        expandedTierId = tier.tierId
                    }

                    if selectedTier == tier.tierId {
                        selectedTier = nil
                    } else {
                        selectedTier = tier.tierId
                        selectedType = nil
                    }
                }
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(tierColor)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.tierId == "CAFFEINE_TIER_1" ? "Quality Sources" : "Limit Sources")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("\(formatValue(tierMg)) mg · \(Int(tierPercentage.rounded()))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Progress bar with target
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(tierColor)
                                    .frame(
                                        width: geometry.size.width * min(tierPercentage / 100, 1.0),
                                        height: 8
                                    )

                                // Target marker
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

                        Text("Target: \(tier.tierId == "CAFFEINE_TIER_1" ? "≥" : "<")\(Int(targetPercentage.rounded()))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                    Text(tier.tierDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !typesWithData.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(typesWithData, id: \.self) { typeId in
                                individualTypeRow(typeId)
                            }
                        }
                    } else {
                        Text("No sources logged in this category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
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
        let mg = typeData[typeId] ?? 0
        let percentage = totalCaffeine > 0 ? (mg / totalCaffeine) * 100 : 0
        let isSelected = selectedType == typeId

        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedType == typeId {
                    selectedType = nil
                    selectedTier = tier.tierId
                } else {
                    selectedType = typeId
                    selectedTier = nil
                }
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tierColor)
                    .frame(width: 8, height: 8)

                Text(viewModel.getDisplayName(for: typeId))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(formatValue(mg)) mg · \(Int(percentage.rounded()))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? tierColor.opacity(0.2) : Color(uiColor: .tertiarySystemGroupedBackground))
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
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    NavigationStack {
        CaffeineTypeView(color: .brown)
    }
}
