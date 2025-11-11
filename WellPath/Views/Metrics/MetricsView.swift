//
//  MetricsView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

enum BiometricFilter: String, CaseIterable {
    case outOfRange = "Out of Range"
    case inRange = "In Range"
    case optimal = "Optimal"
}

enum MetricCategory: String, CaseIterable {
    case biometrics = "Biometrics"
    case biomarkers = "Biomarkers"
}

struct MetricsView: View {
    @StateObject private var viewModel = MetricsViewModel()
    @State private var selectedCategory: MetricCategory = .biomarkers
    @State private var selectedFilter: BiometricFilter = .outOfRange
    @State private var searchText: String = ""
    @State private var selectedSubcategories: Set<String> = []
    @State private var showSearchDropdown: Bool = false
    @FocusState private var isSearchFocused: Bool

    var filteredBiomarkers: [BiomarkerCardData] {
        var cards = viewModel.biomarkerCards

        // Filter by status
        switch selectedFilter {
        case .outOfRange:
            cards = cards.filter { $0.status == "Out-of-Range" }
        case .inRange:
            cards = cards.filter { $0.status == "In-Range" }
        case .optimal:
            cards = cards.filter { $0.status == "Optimal" }
        }

        // Filter by search text
        if !searchText.isEmpty {
            cards = cards.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Filter by subcategories (multi-select)
        if !selectedSubcategories.isEmpty {
            cards = cards.filter { card in
                if let category = card.category {
                    return selectedSubcategories.contains(category)
                }
                return false
            }
        }

        return cards
    }

    var filteredBiometrics: [BiometricCardData] {
        var cards = viewModel.biometricCards

        // Filter by status
        switch selectedFilter {
        case .outOfRange:
            cards = cards.filter { $0.status == "Out-of-Range" }
        case .inRange:
            cards = cards.filter { $0.status == "In-Range" }
        case .optimal:
            cards = cards.filter { $0.status == "Optimal" }
        }

        // Filter by search text
        if !searchText.isEmpty {
            cards = cards.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Filter by subcategories (multi-select)
        if !selectedSubcategories.isEmpty {
            cards = cards.filter { card in
                if let category = card.category {
                    return selectedSubcategories.contains(category)
                }
                return false
            }
        }

        return cards
    }

    var searchSuggestions: [String] {
        let allNames = selectedCategory == .biomarkers
            ? viewModel.biomarkerCards.map { $0.name }
            : viewModel.biometricCards.map { $0.name }

        if searchText.isEmpty {
            return []
        }

        return allNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
            .prefix(5)
            .map { $0 }
    }

    @ViewBuilder
    var categoryFiltersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Category Dropdown Menu
                    categoryDropdownMenu

                    // Selected Category Pills (with X to remove)
                    ForEach(Array(selectedSubcategories).sorted(), id: \.self) { category in
                        categoryPill(for: category)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    func categoryPill(for category: String) -> some View {
        HStack(spacing: 6) {
            Text(category)
                .font(.subheadline)
                .fontWeight(.medium)

            Button(action: {
                withAnimation {
                    _ = selectedSubcategories.remove(category)
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0, green: 0.478, blue: 1, opacity: 0.6))
        .foregroundColor(.white)
        .cornerRadius(16)
    }

    var categoryDropdownMenu: some View {
        Menu {
            ForEach(viewModel.categories, id: \.self) { category in
                Button(action: {
                    withAnimation {
                        // Only add if not already selected
                        if !selectedSubcategories.contains(category) {
                            selectedSubcategories.insert(category)
                        }
                    }
                }) {
                    HStack {
                        Text(category)
                        if selectedSubcategories.contains(category) {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.subheadline)
                Text("Filter by category")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(16)
        }
    }

    func getStatusColor(_ status: String) -> Color {
        switch status {
        case "Out-of-Range": return .red
        case "In-Range": return .blue
        case "Optimal": return .green
        default: return .gray
        }
    }

    func getFilterColor(_ filter: BiometricFilter) -> Color {
        switch filter {
        case .outOfRange:
            return Color.red.opacity(0.7)
        case .inRange:
            return Color.blue.opacity(0.7)
        case .optimal:
            return Color.green.opacity(0.7)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Search Bar
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)

                            TextField("Search biomarkers & biometrics...", text: $searchText)
                                .focused($isSearchFocused)
                                .onChange(of: searchText) { newValue in
                                    showSearchDropdown = !newValue.isEmpty && !searchSuggestions.isEmpty
                                }
                                .onSubmit {
                                    isSearchFocused = false
                                    showSearchDropdown = false
                                }

                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    showSearchDropdown = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        // Search Suggestions Dropdown
                        if showSearchDropdown && !searchSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchSuggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        searchText = suggestion
                                        showSearchDropdown = false
                                        isSearchFocused = false
                                    }) {
                                        HStack {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Text(suggestion)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }

                                    if suggestion != searchSuggestions.last {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)

                    // Category Toggle - Segmented Picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(MetricCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedCategory) { oldValue, newValue in
                        Task {
                            if newValue == .biomarkers {
                                await viewModel.loadBiomarkers()
                            } else {
                                await viewModel.loadBiometrics()
                            }
                        }
                    }

                    // Status Filter - Rounded pill buttons with colored selection
                    HStack(spacing: 8) {
                        ForEach(BiometricFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                            }) {
                                Text(filter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedFilter == filter
                                            ? getFilterColor(filter)
                                            : Color(uiColor: .secondarySystemGroupedBackground)
                                    )
                                    .foregroundColor(
                                        selectedFilter == filter
                                            ? .white
                                            : .primary
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                Color.gray.opacity(0.3),
                                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Category Filters Section
                    categoryFiltersView

                    // Content
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else if selectedCategory == .biomarkers {
                        // Biomarker Cards
                        if filteredBiomarkers.isEmpty {
                            Text("No biomarkers found for this filter")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredBiomarkers.enumerated()), id: \.element.id) { index, card in
                                    NavigationLink(destination: BiomarkerDetailView(
                                        name: card.name,
                                        value: card.value,
                                        status: card.status,
                                        optimalRange: card.optimalRange,
                                        trend: card.trend,
                                        isBiometric: false
                                    )) {
                                        VStack(spacing: 0) {
                                            BiomarkerCard(
                                                name: card.name,
                                                value: card.value,
                                                status: card.status,
                                                rangeName: card.rangeName,
                                                optimalRange: card.optimalRange,
                                                trend: card.trend,
                                                trendData: card.trendData,
                                                statusColor: getStatusColor(card.status),
                                                isBiometric: false
                                            )

                                            // Divider between rows (not after last item)
                                            if index < filteredBiomarkers.count - 1 {
                                                Divider()
                                                    .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Biometrics view
                        if filteredBiometrics.isEmpty {
                            Text("No biometrics found for this filter")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredBiometrics.enumerated()), id: \.element.id) { index, card in
                                    NavigationLink(destination: BiomarkerDetailView(
                                        name: card.name,
                                        value: card.value,
                                        status: card.status,
                                        optimalRange: card.optimalRange,
                                        trend: card.trend,
                                        isBiometric: true
                                    )) {
                                        VStack(spacing: 0) {
                                            BiomarkerCard(
                                                name: card.name,
                                                value: card.value,
                                                status: card.status,
                                                rangeName: card.rangeName,
                                                optimalRange: card.optimalRange,
                                                trend: card.trend,
                                                trendData: card.trendData,
                                                statusColor: getStatusColor(card.status),
                                                isBiometric: true
                                            )

                                            // Divider between rows (not after last item)
                                            if index < filteredBiometrics.count - 1 {
                                                Divider()
                                                    .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("BIOMETRICS & BIOMARKERS")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Load biomarkers and categories on first load
                await viewModel.loadBiomarkers()
                await viewModel.loadCategories()
            }
        }
    }
}

struct BiomarkerCard: View {
    let name: String
    let value: String
    let status: String
    let rangeName: String
    let optimalRange: String
    let trend: String
    let trendData: [Double]
    let statusColor: Color
    let isBiometric: Bool

    var metricColor: Color {
        if isBiometric {
            return Color(red: 1.0, green: 0.0, blue: 1.0) // Magenta for biometrics
        } else {
            return Color(red: 0.74, green: 0.56, blue: 0.94) // Purple for biomarkers
        }
    }

    var metricIcon: String {
        if isBiometric {
            return "ruler.fill" // Physical measurements
        } else {
            return "drop.fill" // Lab/blood tests
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon badge - colored by metric type
            Image(systemName: metricIcon)
                .font(.system(size: 20))
                .foregroundColor(metricColor)
                .frame(width: 44, height: 44)
                .background(metricColor.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                // Marker name
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Value and range name on one line
                HStack(spacing: 6) {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(rangeName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Mini sparkline chart
            MiniSparkline(
                data: trendData.isEmpty ? [0] : trendData,
                color: statusColor,
                optimalRange: optimalRange
            )
            .frame(width: 80, height: 50)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct MiniSparkline: View {
    let data: [Double]
    let color: Color
    let optimalRange: String

    func getOptimalMin() -> Double {
        if optimalRange.contains("-") {
            let components = optimalRange.components(separatedBy: "-")
            if let min = Double(components[0].trimmingCharacters(in: .whitespaces)) {
                return min
            }
        } else if optimalRange.contains("<") {
            return 0
        } else if optimalRange.contains(">") {
            let minString = optimalRange
                .replacingOccurrences(of: ">", with: "")
                .components(separatedBy: " ")[0]
                .trimmingCharacters(in: .whitespaces)
            if let min = Double(minString) {
                return min
            }
        }
        return 0
    }

    func getOptimalMax() -> Double {
        if optimalRange.contains("-") {
            let components = optimalRange.components(separatedBy: "-")
            if components.count > 1 {
                let maxString = components[1]
                    .replacingOccurrences(of: "mg/dL", with: "")
                    .replacingOccurrences(of: "ng/mL", with: "")
                    .replacingOccurrences(of: "pg/mL", with: "")
                    .replacingOccurrences(of: "mIU/L", with: "")
                    .replacingOccurrences(of: "μg/dL", with: "")
                    .replacingOccurrences(of: "%", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let max = Double(maxString) {
                    return max
                }
            }
        } else if optimalRange.contains("<") {
            let maxString = optimalRange
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: "mg/dL", with: "")
                .replacingOccurrences(of: "ng/mL", with: "")
                .replacingOccurrences(of: "pg/mL", with: "")
                .replacingOccurrences(of: "mIU/L", with: "")
                .replacingOccurrences(of: "μg/dL", with: "")
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let max = Double(maxString) {
                return max
            }
        } else if optimalRange.contains(">") {
            return 0
        }
        return 0
    }

    func getColorForValue(_ value: Double) -> Color {
        let optMin = getOptimalMin()
        let optMax = getOptimalMax()

        if optMin > 0 && optMax > optMin {
            if value >= optMin && value <= optMax {
                return .green
            } else {
                let optRange = optMax - optMin
                let lowerInRange = optMin - (optRange * 0.3)
                let upperInRange = optMax + (optRange * 0.3)
                if value >= lowerInRange && value <= upperInRange {
                    return .blue
                }
                return .red
            }
        } else if optMax > 0 && optMin == 0 {
            if value <= optMax {
                return .green
            } else if value <= optMax * 1.3 {
                return .blue
            }
            return .red
        } else if optMin > 0 && optMax == 0 {
            if value >= optMin {
                return .green
            } else if value >= optMin * 0.7 {
                return .blue
            }
            return .red
        }

        return color
    }

    private func calculateChartDimensions(_ geometry: GeometryProxy) -> (maxValue: Double, minValue: Double, range: Double, chartWidth: CGFloat, chartStartX: CGFloat, chartHeight: CGFloat, padding: CGFloat) {
        let rawMaxValue = data.max() ?? 1
        let rawMinValue = data.min() ?? 0
        let rawRange = rawMaxValue - rawMinValue

        let bufferY = rawRange > 0 ? rawRange * 0.1 : 0.1
        let maxValue = rawMaxValue + bufferY
        let minValue = rawMinValue - bufferY
        let range = maxValue - minValue

        let padding: CGFloat = 8
        let totalWidth = geometry.size.width - padding * 2
        let bufferX = totalWidth * 0.1
        let chartWidth = totalWidth - (bufferX * 2)
        let chartStartX = padding + bufferX
        let chartHeight = geometry.size.height - padding * 2

        return (maxValue, minValue, range, chartWidth, chartStartX, chartHeight, padding)
    }

    @ViewBuilder
    private func chartContent(geometry: GeometryProxy, dimensions: (maxValue: Double, minValue: Double, range: Double, chartWidth: CGFloat, chartStartX: CGFloat, chartHeight: CGFloat, padding: CGFloat)) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))

            // Y-axis
            Path { path in
                path.move(to: CGPoint(x: dimensions.padding, y: dimensions.padding))
                path.addLine(to: CGPoint(x: dimensions.padding, y: geometry.size.height - dimensions.padding))
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)

            // X-axis
            Path { path in
                path.move(to: CGPoint(x: dimensions.padding, y: geometry.size.height - dimensions.padding))
                path.addLine(to: CGPoint(x: geometry.size.width - dimensions.padding, y: geometry.size.height - dimensions.padding))
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)

            lineSegments(chartStartX: dimensions.chartStartX, chartWidth: dimensions.chartWidth, chartHeight: dimensions.chartHeight, padding: dimensions.padding, minValue: dimensions.minValue, range: dimensions.range)
            dataPoints(chartStartX: dimensions.chartStartX, chartWidth: dimensions.chartWidth, chartHeight: dimensions.chartHeight, padding: dimensions.padding, minValue: dimensions.minValue, range: dimensions.range)
        }
    }

    @ViewBuilder
    private func lineSegments(chartStartX: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat, padding: CGFloat, minValue: Double, range: Double) -> some View {
        ForEach(Array(0..<max(1, data.count)-1), id: \.self) { index in
            lineSegment(at: index, chartStartX: chartStartX, chartWidth: chartWidth, chartHeight: chartHeight, padding: padding, minValue: minValue, range: range)
        }
    }

    @ViewBuilder
    private func lineSegment(at index: Int, chartStartX: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat, padding: CGFloat, minValue: Double, range: Double) -> some View {
        let currentValue = data[index]
        let nextValue = data[index + 1]

        let currentX: CGFloat = data.count == 1 ? chartStartX + (chartWidth / 2) : chartStartX + (chartWidth * CGFloat(index) / CGFloat(data.count - 1))
        let nextX: CGFloat = data.count == 1 ? chartStartX + (chartWidth / 2) : chartStartX + (chartWidth * CGFloat(index + 1) / CGFloat(data.count - 1))

        let currentNormalized = range > 0 ? (currentValue - minValue) / range : 0.5
        let nextNormalized = range > 0 ? (nextValue - minValue) / range : 0.5

        let currentY = padding + (chartHeight * (1 - CGFloat(currentNormalized)))
        let nextY = padding + (chartHeight * (1 - CGFloat(nextNormalized)))

        Path { path in
            path.move(to: CGPoint(x: currentX, y: currentY))
            path.addLine(to: CGPoint(x: nextX, y: nextY))
        }
        .stroke(Color.white.opacity(0.5), lineWidth: 2)
    }

    @ViewBuilder
    private func dataPoints(chartStartX: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat, padding: CGFloat, minValue: Double, range: Double) -> some View {
        ForEach(Array(0..<data.count), id: \.self) { index in
            let value = data[index]
            let pointColor = getColorForValue(value)
            let x: CGFloat = data.count == 1 ? chartStartX + (chartWidth / 2) : chartStartX + (chartWidth * CGFloat(index) / CGFloat(data.count - 1))
            let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
            let y = padding + (chartHeight * (1 - CGFloat(normalizedValue)))

            Circle()
                .fill(pointColor)
                .frame(width: 4, height: 4)
                .position(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let dimensions = calculateChartDimensions(geometry)
            chartContent(geometry: geometry, dimensions: dimensions)
        }
    }
}

#Preview {
    MetricsView()
}
