//
//  VegetablesDetail.swift
//  WellPath
//
//  Detail screen for Vegetables with Timing and Type views
//

import SwiftUI

enum VegetablesDetailTab: String, CaseIterable {
    case timing = "Timing"
    case type = "Type"
}

struct VegetablesDetail: View {
    @State private var selectedTab: VegetablesDetailTab = .timing

    let color = MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    let screenIcon = MetricsUIConfig.getIcon(for: "Vegetables")

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(VegetablesDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selected tab (each tab handles its own scrolling)
            Group {
                switch selectedTab {
                case .timing:
                    VegetablesTimingView(color: color)
                case .type:
                    VegetablesTypeView(color: color)
                }
            }
        }
        .background(
            ZStack {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

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
        .navigationTitle("Vegetables Details")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Timing View (Chart/About split)

struct VegetablesTimingView: View {
    let color: Color
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_VEGETABLES_MEAL_TIMING")
    @State private var selectedView: TimingView = .chart

    enum TimingView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            // View picker
            Picker("View", selection: $selectedView) {
                ForEach(TimingView.allCases, id: \.self) { view in
                    Text(view.rawValue).tag(view)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if selectedView == .chart {
                VegetablesMealTimingStackedChart(color: color)
            } else {
                // About content (scrollable)
                ScrollView {
                    if let education = educationViewModel.education {
                        VStack(alignment: .leading, spacing: 24) {
                            if let about = education.aboutContent {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(color)
                                        Text("About Vegetables Timing")
                                            .font(.headline)
                                    }
                                    Text(about)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }

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
                        .padding()
                    }
                }
            }
        }
        .task {
            await educationViewModel.loadEducation()
        }
    }
}

// MARK: - Type View (Chart/About split)

struct VegetablesTypeView: View {
    let color: Color
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_VEGETABLES_TYPE")
    @State private var selectedView: TypeView = .chart

    enum TypeView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            // View picker
            Picker("View", selection: $selectedView) {
                ForEach(TypeView.allCases, id: \.self) { view in
                    Text(view.rawValue).tag(view)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if selectedView == .chart {
                VegetablesTypeStackedChart(color: color)
            } else {
                // About content (scrollable)
                ScrollView {
                    if let education = educationViewModel.education {
                        VStack(alignment: .leading, spacing: 24) {
                            if let about = education.aboutContent {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(color)
                                        Text("About Vegetables Types")
                                            .font(.headline)
                                    }
                                    Text(about)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }

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
                        .padding()
                    }
                }
            }
        }
        .task {
            await educationViewModel.loadEducation()
        }
    }
}

#Preview {
    NavigationStack {
        VegetablesDetail()
    }
}
