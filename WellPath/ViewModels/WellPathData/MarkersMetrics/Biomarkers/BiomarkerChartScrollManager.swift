//
//  BiomarkerChartScrollManager.swift
//  WellPath
//
//  Scroll manager for biomarker charts.
//  Loads ALL clinical samples once on init, then re-buckets locally for display.
//  Biomarker data is sparse (lab results every few months) so full load is efficient.
//

import Foundation
import SwiftUI
import Supabase

/// Chart data point for biomarker display (value of 0 means no data for that slot)
struct BiomarkerChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    var value: Double
    var sample: BiomarkerSample?

    var hasData: Bool { value > 0 && sample != nil }
}

@MainActor
class BiomarkerChartScrollManager: ObservableObject {
    @Published var chartData: [BiomarkerChartPoint] = []
    @Published var isLoading = false

    // Store ALL raw samples - only fetched once
    private var allSamples: [BiomarkerSample] = []
    private var hasLoadedSamples = false

    private var selectedPeriod: BiomarkerTimePeriod
    private let quantityType: String
    private let supabase = SupabaseManager.shared.client

    /// Calendar component for the current period's timeline granularity
    var calendarComponent: Calendar.Component {
        switch selectedPeriod {
        case .week: return .day
        case .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        case .fiveYear: return .quarter  // Quarterly buckets for 5Y view
        }
    }

    /// Number of visible units in the chart window
    var numberOfBars: Int {
        switch selectedPeriod {
        case .week: return 7
        case .month: return 30
        case .sixMonth: return 26
        case .year: return 12
        case .fiveYear: return 20  // 5 years × 4 quarters = 20 quarters
        }
    }

    /// Date range for the current period view
    /// End date needs to extend past "now" to support scroll positioning where "now" is at 90% from left
    private var viewDateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current

        // End date needs to extend into future based on visible bars
        // With 90% scroll offset, right edge = now + (bars * 0.1)
        let futureBuffer = Int(Double(numberOfBars) * 0.15) // 15% buffer

        let start: Date
        let end: Date
        switch selectedPeriod {
        case .week:
            start = calendar.date(byAdding: .day, value: -60, to: now) ?? now
            end = calendar.date(byAdding: .day, value: futureBuffer, to: now) ?? now
        case .month:
            start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            end = calendar.date(byAdding: .day, value: futureBuffer, to: now) ?? now
        case .sixMonth:
            start = calendar.date(byAdding: .year, value: -2, to: now) ?? now
            end = calendar.date(byAdding: .weekOfYear, value: futureBuffer, to: now) ?? now
        case .year:
            start = calendar.date(byAdding: .year, value: -3, to: now) ?? now
            end = calendar.date(byAdding: .month, value: futureBuffer, to: now) ?? now
        case .fiveYear:
            start = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            end = calendar.date(byAdding: .month, value: futureBuffer, to: now) ?? now
        }

        return (start, end)
    }

    init(period: BiomarkerTimePeriod, quantityType: String) {
        self.selectedPeriod = period
        self.quantityType = quantityType

        // Generate initial empty timeline synchronously
        let range = viewDateRange
        chartData = generateEmptyTimeline(from: range.start, to: range.end)
        chartData.sort { $0.date > $1.date }

        // Load all samples once
        Task {
            await loadAllSamples()
        }
    }

    func updatePeriod(_ period: BiomarkerTimePeriod) {
        guard period != selectedPeriod else { return }
        self.selectedPeriod = period

        // Regenerate chart data from cached samples - NO database call needed
        rebuildChartData()
    }

    /// Load ALL samples for this biomarker type (only called once)
    private func loadAllSamples() async {
        guard !hasLoadedSamples else { return }
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            let results: [BiomarkerSample] = try await supabase
                .from("patient_clinical_samples")
                .select("id, patient_id, clinical_type, value, unit, sample_time, source")
                .eq("patient_id", value: patientId)
                .eq("clinical_type", value: quantityType)
                .order("sample_time", ascending: false)
                .execute()
                .value

            print("📊 BiomarkerChart: Loaded ALL \(results.count) samples for \(quantityType)")

            allSamples = results
            hasLoadedSamples = true

            // Now rebuild chart data with actual values
            rebuildChartData()

        } catch {
            print("❌ Error loading biomarker samples: \(error)")
        }

        isLoading = false
    }

    /// Rebuild chart data from cached samples for current period
    private func rebuildChartData() {
        let range = viewDateRange
        let calendar = Calendar.current

        // Generate empty timeline for current period
        var timeline = generateEmptyTimeline(from: range.start, to: range.end)

        // Bucket samples by current period's granularity
        var bucketData: [Date: BiomarkerSample] = [:]

        for sample in allSamples {
            let bucketStart: Date
            switch calendarComponent {
            case .day:
                bucketStart = calendar.startOfDay(for: sample.sampleTime)
            case .weekOfYear:
                bucketStart = calendar.dateInterval(of: .weekOfYear, for: sample.sampleTime)?.start ?? sample.sampleTime
            case .month:
                bucketStart = calendar.dateInterval(of: .month, for: sample.sampleTime)?.start ?? sample.sampleTime
            default:
                bucketStart = sample.sampleTime
            }

            // Keep the most recent sample for each bucket
            if bucketData[bucketStart] == nil || sample.sampleTime > bucketData[bucketStart]!.sampleTime {
                bucketData[bucketStart] = sample
            }
        }

        // Overlay actual data onto timeline
        for (bucketDate, sample) in bucketData {
            if let index = timeline.firstIndex(where: {
                calendar.isDate($0.date, equalTo: bucketDate, toGranularity: calendarComponent)
            }) {
                timeline[index] = BiomarkerChartPoint(date: bucketDate, value: sample.value, sample: sample)
            }
        }

        // Update published property
        chartData = timeline.sorted { $0.date > $1.date }
    }

    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [BiomarkerChartPoint] {
        var timeline: [BiomarkerChartPoint] = []
        var currentDate = startDate
        let calendar = Calendar.current

        while currentDate <= endDate {
            timeline.append(BiomarkerChartPoint(date: currentDate, value: 0, sample: nil))
            currentDate = calendar.date(byAdding: calendarComponent, value: 1, to: currentDate) ?? endDate
        }

        return timeline
    }

    /// Handle scroll position changes - no-op since we load all data upfront
    func handleScroll(position: Date) {
        // No incremental loading needed - all data is already loaded
    }

    /// Get data points that have actual values (non-zero)
    var dataPointsWithValues: [BiomarkerChartPoint] {
        chartData.filter { $0.hasData }
    }

    /// Get the underlying samples for record display
    var samples: [BiomarkerSample] {
        allSamples.sorted { $0.sampleTime > $1.sampleTime }
    }

    // Legacy properties for compatibility
    var isLoadingOlder: Bool { false }
    var isLoadingNewer: Bool { false }
}
