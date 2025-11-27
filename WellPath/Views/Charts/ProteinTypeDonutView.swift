//
//  ProteinTypeDonutView.swift
//  WellPath
//
//  Period-specific protein type breakdown with donut chart
//  Shows tier-based grouping with Type Score
//

import SwiftUI
import Charts

struct ProteinTypeDonutView: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedType: String?
    @StateObject private var viewModel: ProteinTypeDonutViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: ProteinTypeDonutViewModel(baseColor: color))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
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

                    // Type Score as circular progress ring
                    if let tierConfig = viewModel.tierConfig {
                        TypeScoreRing(
                            score: viewModel.calculateTypeScore(),
                            scoringExplanation: viewModel.scoringExplanation ?? "",
                            color: color
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // Donut chart - always shows individual types, colored by tier
                    if !viewModel.typeData.isEmpty {
                        Chart {
                            ForEach(Array(viewModel.typeData.keys.sorted()), id: \.self) { typeId in
                                if let value = viewModel.typeData[typeId], value > 0 {
                                    let isSelected = selectedType == nil || selectedType == typeId

                                    SectorMark(
                                        angle: .value("Grams", value),
                                        innerRadius: .ratio(0.618),
                                        angularInset: 1.5
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(
                                        viewModel.getColor(for: typeId)
                                            .opacity(isSelected ? 1.0 : 0.3)
                                    )
                                }
                            }
                        }
                        .frame(height: 160)
                        .chartAngleSelection(value: $selectedType)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }

                    // Tier accordion sections
                    if let tierConfig = viewModel.tierConfig {
                        VStack(spacing: 8) {
                            ForEach(tierConfig.tiers.filter { $0.targetPercentage > 0 }) { tier in
                                TierAccordionCard(
                                    tier: tier,
                                    typeData: viewModel.typeData,
                                    totalProtein: viewModel.totalProtein,
                                    selectedType: $selectedType,
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await viewModel.loadTierConfig()
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }
}

// MARK: - Type Score Ring

struct TypeScoreRing: View {
    let score: Double
    let scoringExplanation: String
    let color: Color

    @State private var isExpanded = false

    private var scoreGrade: String {
        if score >= 85 {
            return "Excellent"
        } else if score >= 70 {
            return "Good"
        } else if score >= 55 {
            return "Fair"
        } else {
            return "Poor"
        }
    }

    private var scoreColor: Color {
        if score >= 85 {
            return Color.green
        } else if score >= 70 {
            return Color.blue
        } else if score >= 55 {
            return Color.orange
        } else {
            return Color.red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Score ring
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Color(uiColor: .tertiarySystemGroupedBackground), lineWidth: 12)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: score / 100)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [scoreColor.opacity(0.6), scoreColor]),
                                    center: .center,
                                    startAngle: .degrees(-90),
                                    endAngle: .degrees(270)
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: score)

                        // Score text in center
                        VStack(spacing: 2) {
                            Text("\(Int(score.rounded()))")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(scoreColor)

                            Text(scoreGrade)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 100, height: 100)

                    // Label
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type Score")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Protein quality distribution")
                            .font(.caption)
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

            // Expanded explanation
            if isExpanded && !scoringExplanation.isEmpty {
                Text(.init(scoringExplanation))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Tier Accordion Card

struct TierAccordionCard: View {
    let tier: TierConfig.Tier
    let typeData: [String: Double]
    let totalProtein: Double
    @Binding var selectedType: String?
    let viewModel: ProteinTypeDonutViewModel

    @State private var isExpanded = false

    private var tierGrams: Double {
        tier.proteinTypes.reduce(0.0) { sum, typeId in
            sum + (typeData[typeId] ?? 0)
        }
    }

    private var tierPercentage: Double {
        guard totalProtein > 0 else { return 0 }
        return (tierGrams / totalProtein) * 100
    }

    private var progressValue: Double {
        guard tier.targetPercentage > 0 else { return 0 }
        return tierPercentage / Double(tier.targetPercentage)
    }

    private var tierColor: Color {
        switch tier.tierId {
        case "PROTEIN_TIER_1":
            return Color(red: 0.2, green: 0.78, blue: 0.35) // modern green
        case "PROTEIN_TIER_2":
            return Color(red: 0.0, green: 0.48, blue: 1.0) // modern blue
        case "PROTEIN_TIER_3":
            return Color(red: 1.0, green: 0.27, blue: 0.23) // modern red
        default:
            return Color.gray
        }
    }

    private var progressColor: Color {
        if progressValue >= 0.9 {
            return tierColor
        } else if progressValue >= 0.6 {
            return Color.orange
        } else {
            return Color.red
        }
    }

    private var typesWithData: [String] {
        tier.proteinTypes.filter { typeId in
            (typeData[typeId] ?? 0) > 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(tierColor)
                            .frame(width: 10, height: 10)

                        Text(tier.tierName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(formatValue(tierGrams))g")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("(\(Int(tierPercentage.rounded()))%)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Target: \(tier.targetPercentage)%")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(Int(tierPercentage.rounded()))/\(tier.targetPercentage)%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(progressColor)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .frame(height: 6)

                                // Progress fill
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor)
                                    .frame(width: geometry.size.width * min(progressValue, 1.0), height: 6)
                            }
                        }
                        .frame(height: 6)
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
                    // Tier description
                    if !tier.tierDescription.isEmpty {
                        Text(.init(tier.tierDescription))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Individual types with data
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
        let isSelected = selectedType == nil || selectedType == typeId

        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = selectedType == typeId ? nil : typeId
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.getColor(for: typeId))
                    .frame(width: 10, height: 10)
                    .opacity(isSelected ? 1.0 : 0.3)

                Text(viewModel.getDisplayName(for: typeId))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .opacity(isSelected ? 1.0 : 0.3)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formatValue(grams))g")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .opacity(isSelected ? 1.0 : 0.3)
                    Text("(\(Int(percentage.rounded()))%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(isSelected ? 1.0 : 0.3)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedType == typeId ? viewModel.getColor(for: typeId).opacity(0.12) : Color(uiColor: .tertiarySystemGroupedBackground))
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

#Preview {
    ProteinTypeDonutView(color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"))
}
