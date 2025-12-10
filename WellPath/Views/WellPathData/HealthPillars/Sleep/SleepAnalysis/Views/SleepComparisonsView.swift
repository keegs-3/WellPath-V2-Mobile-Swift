//
//  SleepComparisonsView.swift
//  WellPath
//
//  Full view for Sleep Comparisons (placeholder - coming soon).
//  Receives viewId from navigation for database-driven content.
//

import SwiftUI

struct SleepComparisonsView: View {
    let color: Color
    let viewId: String
    @ObservedObject private var primaryViewModel: SleepAnalysisPrimaryViewModel
    @State private var showEntry = false
    @State private var showDataManagement = false
    @State private var showAboutModal = false

    // Track if we own the view models (for standalone use)
    private let ownsViewModels: Bool

    private var metricId: String { viewId }
    private let metricName = "Sleep Comparisons"

    /// Standalone initializer - creates its own view models
    init(color: Color, viewId: String = "DISP_SLEEP_COMPARISONS") {
        self.color = color
        self.viewId = viewId
        self._primaryViewModel = ObservedObject(wrappedValue: SleepAnalysisPrimaryViewModel(viewId: viewId))
        self.ownsViewModels = true
    }

    /// Card initializer - uses passed view models
    init(color: Color, viewId: String, primaryViewModel: SleepAnalysisPrimaryViewModel) {
        self.color = color
        self.viewId = viewId
        self._primaryViewModel = ObservedObject(wrappedValue: primaryViewModel)
        self.ownsViewModels = false
    }

    var body: some View {
        // Placeholder: Coming Soon view
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundColor(color.opacity(0.5))

            Text("Coming Soon")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Compare your sleep patterns against recommended benchmarks and your personal history.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .metricScreenBackground(color: color)
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: metricId,
                metricName: metricName,
                color: color,
                isPresented: $showAboutModal
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .metric,
                    itemId: viewId,
                    displayName: metricName,
                    pillar: "Restorative Sleep",
                    cardId: nil,
                    sectionId: "NAV_SLEEP"
                )

                Button {
                    showEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEntry) {
            SleepEntryView()
        }
        .sheet(isPresented: $showDataManagement) {
            SleepDataManagementView(color: color)
        }
        .task {
            // Only load data if we own the view models (standalone mode)
            if ownsViewModels {
                await primaryViewModel.loadPrimaryScreen()
            }
        }
    }
}

// MARK: - Legacy alias for backwards compatibility
typealias SleepComparisonsFullView = SleepComparisonsView

#Preview {
    NavigationStack {
        SleepComparisonsView(color: .indigo, viewId: "DISP_SLEEP_COMPARISONS")
    }
}
