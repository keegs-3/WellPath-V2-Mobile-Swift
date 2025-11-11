//
//  StepsPrimaryViewModel.swift
//  WellPath
//
//  Wrapper around StandardMetricViewModel for Steps metric
//  Uses generic pattern with DISP_STEPS metric_id
//

import Foundation

@MainActor
class StepsPrimaryViewModel: ObservableObject {
    // Delegate to StandardMetricViewModel
    private let standardViewModel: StandardMetricViewModel

    // Published properties that mirror StandardMetricViewModel
    @Published var displayMetric: DisplayMetric?
    @Published var metrics: [StandardMetric] = []
    @Published var aboutContent: String?
    @Published var longevityImpact: String?
    @Published var quickTips: [String]?
    @Published var isLoading = false
    @Published var error: String?

    init() {
        // Initialize with Steps metric_id
        self.standardViewModel = StandardMetricViewModel(metricId: "DISP_STEPS")

        // Set up observation of standardViewModel properties
        Task { @MainActor in
            for await _ in standardViewModel.$displayMetric.values {
                self.displayMetric = standardViewModel.displayMetric
            }
        }

        Task { @MainActor in
            for await _ in standardViewModel.$metrics.values {
                self.metrics = standardViewModel.metrics
            }
        }

        Task { @MainActor in
            for await _ in standardViewModel.$aboutContent.values {
                self.aboutContent = standardViewModel.aboutContent
            }
        }

        Task { @MainActor in
            for await _ in standardViewModel.$longevityImpact.values {
                self.longevityImpact = standardViewModel.longevityImpact
            }
        }

        Task { @MainActor in
            for await _ in standardViewModel.$quickTips.values {
                self.quickTips = standardViewModel.quickTips
            }
        }

        Task { @MainActor in
            for await _ in standardViewModel.$isLoading.values {
                self.isLoading = standardViewModel.isLoading
            }
        }

        Task { @MainActor in
            for await _ in standardViewModel.$error.values {
                self.error = standardViewModel.error
            }
        }
    }

    /// Load primary screen data for Steps
    func loadPrimaryScreen() async {
        await standardViewModel.loadPrimaryScreen()
    }
}
