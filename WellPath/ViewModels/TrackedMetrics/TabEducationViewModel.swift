//
//  TabEducationViewModel.swift
//  WellPath
//
//  Shared view model for loading education content (about, health impact, quick tips)
//  from display_metrics table for detail screen tabs
//

import SwiftUI

// MARK: - Tab Education ViewModel

@MainActor
class TabEducationViewModel: ObservableObject {
    @Published var education: MetricEducation?

    private let metricId: String
    private let supabase = SupabaseManager.shared.client

    init(metricId: String) {
        self.metricId = metricId
    }

    func loadEducation() async {
        do {
            struct MetricEducationResponse: Codable {
                let aboutContent: String?
                let longevityImpact: String?
                let quickTips: [String]?

                enum CodingKeys: String, CodingKey {
                    case aboutContent = "about_content"
                    case longevityImpact = "longevity_impact"
                    case quickTips = "quick_tips"
                }
            }

            let results: [MetricEducationResponse] = try await supabase
                .from("display_metrics")
                .select("about_content, longevity_impact, quick_tips")
                .eq("metric_id", value: metricId)
                .limit(1)
                .execute()
                .value

            if let result = results.first {
                education = MetricEducation(
                    aboutContent: result.aboutContent,
                    longevityImpact: result.longevityImpact,
                    quickTips: result.quickTips
                )
            }

        } catch {
            print("❌ Error loading education for \(metricId): \(error)")
        }
    }
}

// MARK: - Metric Education Model

struct MetricEducation {
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
}
