//
//  WeeklySleepChart.swift
//  WellPath
//
//  Weekly aggregated chart for 6-Month view.
//  Shows averaged sleep stage data by week.
//

import SwiftUI
import Charts

struct WeeklySleepChart: View {
    @ObservedObject var viewModel: SleepAnalysisViewModel
    @Binding var selectedStage: SleepStage?
    @Binding var visibleRangeBinding: (start: Date, end: Date)?
    @StateObject private var dataManager = WeeklySleepDataManager()
    @State private var scrollPosition: Date
    @State private var selectedWeek: WeeklyAverage?
    @State private var hasInitializedScroll = false  // Track if we've set initial scroll position
    var height: CGFloat = 340 // Default total height
    var onVisibleRangeChange: ((Date, Date) -> Void)? = nil
    var showAbout: Binding<Bool>? = nil

    init(viewModel: SleepAnalysisViewModel, selectedStage: Binding<SleepStage?> = .constant(nil), visibleRangeBinding: Binding<(start: Date, end: Date)?>? = nil, height: CGFloat = 340, onVisibleRangeChange: ((Date, Date) -> Void)? = nil, showAbout: Binding<Bool>? = nil) {
        self.viewModel = viewModel
        self._selectedStage = selectedStage
        self._visibleRangeBinding = visibleRangeBinding ?? .constant(nil)
        self.height = height
        self.onVisibleRangeChange = onVisibleRangeChange
        self.showAbout = showAbout
        // Initialize scroll position to today (will be adjusted in onAppear)
        _scrollPosition = State(initialValue: Date())
    }

    private let barColor = Color(red: 0x6E / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0)
    
    // Chart data model for BarMark
    private struct ChartWeekData: Identifiable {
        let id: UUID
        let weekStartDate: Date
        let week: WeeklyAverage?
        let chartBedtime: Date // Bedtime adjusted for 6 PM to 6 PM day span
        let chartWaketime: Date // Waketime adjusted for 6 PM to 6 PM day span
        
        init(weekStartDate: Date, week: WeeklyAverage?, referenceDate: Date) {
            self.id = UUID()
            self.weekStartDate = weekStartDate
            self.week = week
            
            let calendar = Calendar.current
            
            if let week = week {
                // Extract hour and minute from actual bedtime/waketime
                let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgBedtime)
                let waketimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgWaketime)
                
                let bedtimeHour = bedtimeComponents.hour ?? 20
                let bedtimeMinute = bedtimeComponents.minute ?? 0
                let waketimeHour = waketimeComponents.hour ?? 8
                let waketimeMinute = waketimeComponents.minute ?? 0
                
                // Calculate minutes from 6 PM (0 = 6 PM, 1440 = next day 6 PM)
                let bedtimeMinutes: Int
                let waketimeMinutes: Int
                
                if bedtimeHour >= 18 {
                    bedtimeMinutes = (bedtimeHour - 18) * 60 + bedtimeMinute
                } else {
                    bedtimeMinutes = (24 - 18 + bedtimeHour) * 60 + bedtimeMinute
                }
                
                if waketimeHour >= 18 {
                    waketimeMinutes = (waketimeHour - 18) * 60 + waketimeMinute
                } else {
                    waketimeMinutes = (24 - 18 + waketimeHour) * 60 + waketimeMinute
                }
                
                // Map times directly to 6 PM to 6 PM sleep day using Date objects
                // Use reference date at 6 PM, then ADD minutes to create Date values
                guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
                    self.chartBedtime = referenceDate
                    self.chartWaketime = referenceDate
                    return
                }
                
                // Use DIRECT offsets representing actual times from 6 PM
                // 6 PM = 0, 11 PM = 300 min, 7 AM = 780 min, 6 PM next = 1440 min
                let bedtimeOffset = bedtimeMinutes  // 11 PM = 300 min
                let waketimeOffset = waketimeMinutes  // 7 AM = 780 min

                if let bedtimeFinal = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference),
                   let waketimeFinal = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference) {
                    self.chartBedtime = bedtimeFinal  // 11 PM (actual time)
                    self.chartWaketime = waketimeFinal  // 7 AM next day (actual time)
                } else {
                    // Fallback: use direct minutes
                    if let bedtimeDate = calendar.date(byAdding: .minute, value: bedtimeMinutes, to: sixPMReference),
                       let waketimeDate = calendar.date(byAdding: .minute, value: waketimeMinutes, to: sixPMReference) {
                        self.chartBedtime = bedtimeDate
                        self.chartWaketime = waketimeDate
                    } else {
                        self.chartBedtime = sixPMReference
                        self.chartWaketime = sixPMReference
                    }
                }
            } else {
                // Default data: 8 PM to 8 AM
                // 8 PM = 120 min, 8 AM = 840 min
                guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
                    self.chartBedtime = referenceDate
                    self.chartWaketime = referenceDate
                    return
                }
                
                let maxMinutes = 24 * 60
                let bedtimeOffset = maxMinutes - 120  // 8 PM: larger offset = larger Date (top)
                let waketimeOffset = maxMinutes - 840  // 8 AM: smaller offset = smaller Date (bottom)
                
                if let bedtimeDate = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference),
                   let waketimeDate = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference) {
                    self.chartBedtime = bedtimeDate
                    self.chartWaketime = waketimeDate
                } else {
                    self.chartBedtime = sixPMReference
                    self.chartWaketime = sixPMReference
                }
            }
        }
    }
    
    // Generate chart data - continuous 26-week range from data manager
    // Sort by date: oldest (left) to newest (right) - like MetricDetailView
    private var chartData: [ChartWeekData] {
        let calendar = Calendar.current
        let referenceDate = calendar.startOfDay(for: Date())
        
        // Use data manager's timeline and sort oldest to newest (left to right)
        let result = dataManager.chartWeekData
            .map { weekGroup in
                ChartWeekData(weekStartDate: weekGroup.weekStartDate, week: weekGroup.week, referenceDate: referenceDate)
            }
            .sorted { $0.weekStartDate < $1.weekStartDate }
        
        NSLog("[SLEEP] 📊 chartData: Generated \(result.count) weeks (dataManager has \(dataManager.chartWeekData.count) weeks)")
        let weeksWithData = result.filter { $0.week != nil }
        NSLog("[SLEEP] 📊 chartData: \(weeksWithData.count) weeks have data")
        
        return result
    }
    
    // Y-axis domain: Dynamic range based on data
    // Default: 8PM to 8AM (120 to 840 minutes from 6PM)
    // Can flex to 6PM-6PM (0 to 1440 minutes) based on data range
    // Uses inverted mapping: date = sixPMReference + (maxMinutes - actualMinutes)
    private var yAxisDomain: ClosedRange<Date> {
        NSLog("[SLEEP] 📊 Y-axis domain calculation started")
        let calendar = Calendar.current
        // Use a fixed reference date (today) - all times will be relative to this
        let referenceDate = calendar.startOfDay(for: Date())
        guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
            NSLog("[SLEEP] ⚠️ Failed to create sixPMReference")
            let fallback = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
            return fallback...fallback
        }
        
        NSLog("[SLEEP] 📊 Y-axis: sixPMReference = \(sixPMReference) (referenceDate: \(referenceDate))")
        
        let maxMinutes = 24 * 60
        
        // Get visible weeks based on scroll position (like MetricDetailView)
        let visibleWeeks = getVisibleWeeks()
        let weeksWithData = visibleWeeks.compactMap { $0.week }
        NSLog("[SLEEP] 📊 Y-axis: Found \(weeksWithData.count) weeks with data out of \(visibleWeeks.count) visible weeks")
        
        // Initialize with extremes so any data will update them
        // Default range: 8PM to 8AM (120 to 840 minutes from 6PM)
        var earliestBedtimeMinutes: Int? = nil  // Will find minimum from data
        var latestWaketimeMinutes: Int? = nil   // Will find maximum from data
        
        if !weeksWithData.isEmpty {
            // Calculate actual range from data
            for week in weeksWithData {
                let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgBedtime)
                let waketimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgWaketime)
                
                guard let bedtimeHour = bedtimeComponents.hour,
                      let bedtimeMinute = bedtimeComponents.minute,
                      let waketimeHour = waketimeComponents.hour,
                      let waketimeMinute = waketimeComponents.minute else {
                    continue
                }
                
                // Calculate minutes from 6PM
                let bedtimeMinutes: Int
                let waketimeMinutes: Int
                
                if bedtimeHour >= 18 {
                    bedtimeMinutes = (bedtimeHour - 18) * 60 + bedtimeMinute
                } else {
                    bedtimeMinutes = (24 - 18 + bedtimeHour) * 60 + bedtimeMinute
                }
                
                if waketimeHour >= 18 {
                    waketimeMinutes = (waketimeHour - 18) * 60 + waketimeMinute
                } else {
                    waketimeMinutes = (24 - 18 + waketimeHour) * 60 + waketimeMinute
                }
                
                // Track earliest bedtime (smallest value) and latest waketime (largest value)
                if earliestBedtimeMinutes == nil || bedtimeMinutes < earliestBedtimeMinutes! {
                    earliestBedtimeMinutes = bedtimeMinutes
                }
                if latestWaketimeMinutes == nil || waketimeMinutes > latestWaketimeMinutes! {
                    latestWaketimeMinutes = waketimeMinutes
                }
                NSLog("[SLEEP] 📊 Y-axis: Week data - bedtime: \(bedtimeHour):\(String(format: "%02d", bedtimeMinute)) (\(bedtimeMinutes) min), waketime: \(waketimeHour):\(String(format: "%02d", waketimeMinute)) (\(waketimeMinutes) min)")
            }
            
            NSLog("[SLEEP] 📊 Y-axis: Before buffer - earliest bedtime: \(earliestBedtimeMinutes ?? -1) min, latest waketime: \(latestWaketimeMinutes ?? -1) min")
            
            // Add 1 hour (60 minutes) buffer on each end
            if let earliest = earliestBedtimeMinutes {
                earliestBedtimeMinutes = max(0, earliest - 60)  // Can go to 6PM (0)
            }
            if let latest = latestWaketimeMinutes {
                latestWaketimeMinutes = min(maxMinutes, latest + 60)  // Can go to next 6PM (1440)
            }
            
            NSLog("[SLEEP] 📊 Y-axis: After buffer - earliest bedtime: \(earliestBedtimeMinutes ?? -1) min, latest waketime: \(latestWaketimeMinutes ?? -1) min")
        }
        
        // Use calculated range if data exists, otherwise use default 8PM-8AM
        let finalBedtimeMinutes = earliestBedtimeMinutes ?? 120  // Default to 8PM if no data
        let finalWaketimeMinutes = latestWaketimeMinutes ?? 840   // Default to 8AM if no data
        
        NSLog("[SLEEP] 📊 Y-axis: Final minutes - bedtime: \(finalBedtimeMinutes) min, waketime: \(finalWaketimeMinutes) min")
        
        // Map times to Date objects using DIRECT offsets
        // This creates actual times: 6 PM + 300 min = 11 PM, 6 PM + 780 min = 7 AM next day
        let bedtimeOffset = finalBedtimeMinutes  // 11 PM (actual time from 6 PM)
        let waketimeOffset = finalWaketimeMinutes  // 7 AM next day (actual time from 6 PM)
        
        NSLog("[SLEEP] 📊 Y-axis: Calculated offsets - bedtimeOffset: \(bedtimeOffset) min (1440 - \(finalBedtimeMinutes)), waketimeOffset: \(waketimeOffset) min (1440 - \(finalWaketimeMinutes))")
        
        // Note: bedtimeTimeAsDate and waketimeTimeAsDate are calculated but not used directly
        // The domain is calculated from minutes offsets below
        
        // Log the actual times represented
        let bedtimeHour = (finalBedtimeMinutes / 60 + 18) % 24
        let bedtimeMin = finalBedtimeMinutes % 60
        let waketimeHour = (finalWaketimeMinutes / 60 + 18) % 24
        let waketimeMin = finalWaketimeMinutes % 60
        NSLog("[SLEEP] 📊 Y-axis: Domain represents times - bedtime: \(String(format: "%02d:%02d", bedtimeHour, bedtimeMin)) (\(finalBedtimeMinutes) min), waketime: \(String(format: "%02d:%02d", waketimeHour, waketimeMin)) (\(finalWaketimeMinutes) min)")
        
        // Create domain based on data range, or default to 8 PM - 8 AM if no data
        let domainStartMinutes: Int
        let domainEndMinutes: Int

        if weeksWithData.isEmpty {
            // No data: default to 8 PM (120 min) to 8 AM (840 min)
            domainStartMinutes = 120   // 8 PM
            domainEndMinutes = 840     // 8 AM
        } else {
            // Use actual data range (already has buffer added)
            domainStartMinutes = finalBedtimeMinutes  // Earliest bedtime
            domainEndMinutes = finalWaketimeMinutes    // Latest waketime
        }

        guard let domainStart = calendar.date(byAdding: .minute, value: domainStartMinutes, to: sixPMReference),
              let domainEnd = calendar.date(byAdding: .minute, value: domainEndMinutes, to: sixPMReference) else {
            NSLog("[SLEEP] ⚠️ Y-axis: Failed to create domain dates")
            return sixPMReference...sixPMReference
        }

        // Domain: earliest bedtime to latest waketime (adjusted to data)
        let startHour = (domainStartMinutes / 60 + 18) % 24
        let endHour = (domainEndMinutes / 60 + 18) % 24
        NSLog("[SLEEP] ✅ Y-axis: Domain set - [\(domainStart) (\(startHour):00) ... \(domainEnd) (\(endHour):00)]")
        return domainStart...domainEnd
    }
    

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryMetrics

            if dataManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else if chartData.isEmpty {
                Text("No weekly data available")
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .foregroundColor(.secondary)
            } else {
                chartView
            }
        }
        .onAppear {
            Task {
                await dataManager.generateInitialData()
            }
        }
    }

    // Calculate average time in bed and time asleep from visible weeks with data
    private func calculateVisibleWeeklyAverages() -> (timeInBed: TimeInterval, timeAsleep: TimeInterval)? {
        let visibleWeeks = getVisibleWeeks().compactMap { $0.week }
        guard !visibleWeeks.isEmpty else { return nil }

        var totalTimeInBed: TimeInterval = 0
        var totalTimeAsleep: TimeInterval = 0

        for week in visibleWeeks {
            totalTimeInBed += week.avgTimeInBed
            totalTimeAsleep += week.avgTimeAsleep
        }

        let count = Double(visibleWeeks.count)
        return (totalTimeInBed / count, totalTimeAsleep / count)
    }
    
    private var summaryMetrics: some View {
        let averages = selectedWeek == nil ? calculateVisibleWeeklyAverages() : nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AVG. TIME IN BED").font(.caption).foregroundColor(.secondary)
                    if let week = selectedWeek {
                        Text(formatDuration(week.avgTimeInBed))
                            .font(.title2).fontWeight(.semibold)
                    } else if let avg = averages {
                        Text(formatDuration(avg.timeInBed))
                            .font(.title2).fontWeight(.semibold)
                    } else {
                        Text("No Data")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AVG. TIME ASLEEP").font(.caption).foregroundColor(.secondary)
                    if let week = selectedWeek {
                        Text(formatDuration(week.avgTimeAsleep))
                            .font(.title2).fontWeight(.semibold)
                    } else if let avg = averages {
                        Text(formatDuration(avg.timeAsleep))
                            .font(.title2).fontWeight(.semibold)
                    } else {
                        Text("No Data")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Info button (top-aligned with metrics)
                if let showAboutBinding = showAbout {
                    Button(action: {
                        withAnimation {
                            showAboutBinding.wrappedValue = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(barColor)
                    }
                }
            }
            if let week = selectedWeek {
                Text(formatWeekRange(week.weekStartDate, week.weekEndDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(visibleDateRangeString())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // Get visible weeks based on scroll position (like MetricDetailView's getVisibleData)
    private func getVisibleWeeks() -> [ChartWeekData] {
        NSLog("[SLEEP] 📊 getVisibleWeeks: chartData count = \(chartData.count), scrollPosition = \(scrollPosition)")
        guard !chartData.isEmpty else {
            NSLog("[SLEEP] ⚠️ getVisibleWeeks: chartData is empty")
            return []
        }
        
        let calendar = Calendar.current
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60 // 26 weeks in seconds
        
        // scrollPosition is the LEFT/START edge of the visible domain (like MetricDetailView)
        guard let endDate = calendar.date(byAdding: .second, value: Int(visibleDomainLength), to: scrollPosition) else {
            NSLog("[SLEEP] ⚠️ getVisibleWeeks: Failed to calculate endDate, using fallback")
            // Fallback to most recent weeks
            let count = min(26, chartData.count)
            let startIndex = max(0, chartData.count - count)
            let fallback = Array(chartData[startIndex..<chartData.count])
            NSLog("[SLEEP] 📊 getVisibleWeeks: Fallback - returning \(fallback.count) weeks")
            return fallback
        }
        
        NSLog("[SLEEP] 📊 getVisibleWeeks: Visible window from \(scrollPosition) to \(endDate) (26 weeks = \(visibleDomainLength) seconds)")
        
        // Get first and last week dates for logging
        if let firstWeek = chartData.first, let lastWeek = chartData.last {
            NSLog("[SLEEP] 📊 getVisibleWeeks: chartData range - first: \(firstWeek.weekStartDate), last: \(lastWeek.weekStartDate)")
        }
        
        // Filter weeks that fall within the visible window (from scrollPosition to endDate)
        // A week is visible if its start date falls within [scrollPosition, endDate]
        // Use <= for endDate to match MetricDetailView's behavior
        let visibleWeeks = chartData.filter { weekData in
            weekData.weekStartDate >= scrollPosition && weekData.weekStartDate <= endDate
        }
        
        NSLog("[SLEEP] 📊 getVisibleWeeks: Found \(visibleWeeks.count) weeks in visible window")
        if let firstVisible = visibleWeeks.first, let lastVisible = visibleWeeks.last {
            NSLog("[SLEEP] 📊 getVisibleWeeks: Visible range - first: \(firstVisible.weekStartDate), last: \(lastVisible.weekStartDate)")
        }
        
        if visibleWeeks.isEmpty {
            let fallback = Array(chartData.prefix(26))
            NSLog("[SLEEP] ⚠️ getVisibleWeeks: No visible weeks, using fallback - returning \(fallback.count) weeks")
            return fallback
        }
        
        return visibleWeeks
    }
    
    // Generate dynamic date range string based on visible weeks (like MetricDetailView)
    private func visibleDateRangeString() -> String {
        NSLog("[SLEEP] 📅 visibleDateRangeString: Calculating date range")
        let visibleWeeks = getVisibleWeeks()
        guard !visibleWeeks.isEmpty else {
            NSLog("[SLEEP] ⚠️ visibleDateRangeString: No visible weeks")
            return ""
        }

        let dates = visibleWeeks.map { $0.weekStartDate }
        guard let firstDate = dates.min(),
              let lastDate = dates.max() else {
            NSLog("[SLEEP] ⚠️ visibleDateRangeString: Failed to get min/max dates")
            return ""
        }

        // Calculate week end for last week (Monday + 6 days = Sunday)
        // Use UTC calendar since weekStartDate is in UTC
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let lastWeekEnd = utcCalendar.date(byAdding: .day, value: 6, to: lastDate) ?? lastDate

        let startYear = utcCalendar.component(.year, from: firstDate)
        let endYear = utcCalendar.component(.year, from: lastWeekEnd)

        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")! // Format in UTC to match database dates

        let result: String
        if startYear == endYear {
            // Same year: "Jul 7 - Jan 4, 2025"
            formatter.dateFormat = "MMM d"
            result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastWeekEnd)), \(endYear)"
        } else {
            // Cross-year: "Jul 7, 2024 - Jan 4, 2025"
            formatter.dateFormat = "MMM d, yyyy"
            result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastWeekEnd))"
        }
        NSLog("[SLEEP] 📅 visibleDateRangeString: Result = '\(result)' (from \(firstDate) to \(lastWeekEnd) in UTC)")
        return result
    }
    
    private func formatWeeklyDateRange() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate Monday of the week that is 26 weeks ago
        var startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        startComponents.weekOfYear = (startComponents.weekOfYear ?? 0) - 26
        startComponents.weekday = 2 // Monday
        guard let startWeekMonday = calendar.date(from: startComponents) else {
            return ""
        }

        // Calculate Sunday of the current week (the 26th week)
        // Get the current week's Monday using yearForWeekOfYear, then add 6 days to get Sunday
        var currentWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        currentWeekComponents.weekday = 2 // Monday
        guard let currentWeekMonday = calendar.date(from: currentWeekComponents) else {
            return ""
        }
        guard let currentWeekSunday = calendar.date(byAdding: .day, value: 6, to: currentWeekMonday) else {
            return ""
        }

        // Check if years match
        let startYear = calendar.component(.year, from: startWeekMonday)
        let endYear = calendar.component(.year, from: currentWeekSunday)

        let formatter = DateFormatter()
        if startYear == endYear {
            // Same year: "Jul 7 - Jan 4, 2025"
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startWeekMonday)) - \(formatter.string(from: currentWeekSunday)), \(endYear)"
        } else {
            // Cross-year: "Jul 7, 2024 - Jan 4, 2025"
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startWeekMonday)) - \(formatter.string(from: currentWeekSunday))"
        }
    }
    
    @ViewBuilder
    private var dateRangeText: some View {
        Text(formatWeeklyDateRange())
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    private var chartHeight: CGFloat { height - 60 } // Subtract space for controls
    private let weekSpacing: CGFloat = 4
    private let visibleWeeks: Int = 26
    private let barWidthRatio: CGFloat = 0.8

    private var chartView: some View {
                                VStack(spacing: 0) {
            sleepChart
            loadingIndicators
        }
        .onAppear {
            // Only initialize scroll position if we haven't already
            // This prevents the chart from snapping back to today when switching tabs
            guard !hasInitializedScroll else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                initializeScrollPosition()
                hasInitializedScroll = true
            }
        }
        .onChange(of: dataManager.chartWeekData.count) { oldValue, newValue in
            // Re-initialize scroll position only on first data load
            if oldValue == 0 && newValue > 0 && !hasInitializedScroll {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    initializeScrollPosition()
                    hasInitializedScroll = true
                }
            }
        }
    }
    
    // Chart content - extracted to avoid type-checking issues
    // Use ALL chartData (like MetricDetailView) - includes empty weeks for proper X-axis and scrolling
    private var sleepChart: some View {
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60 // 26 weeks in seconds

        return Chart {
            ForEach(chartData) { weekData in
                // Render BarMark for all weeks to ensure X-axis labels appear
                // Only show actual bars when data exists
                if weekData.week != nil {
                    BarMark(
                        x: .value("Week", weekData.weekStartDate, unit: .weekOfYear),
                        // yStart must be < yEnd: bedtime (300 min, 11 PM) < waketime (780 min, 7 AM)
                        yStart: .value("Bedtime", weekData.chartBedtime),     // Earlier time (11 PM)
                        yEnd: .value("Waketime", weekData.chartWaketime),     // Later time (7 AM)
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(getBarColor(for: weekData))
                    // No corner radius for 6M view - flat bars like Apple Health
                } else {
                    // Render invisible bar for empty weeks to maintain X-axis structure
                    BarMark(
                        x: .value("Week", weekData.weekStartDate, unit: .weekOfYear),
                        yStart: .value("Bedtime", weekData.chartBedtime),     // Earlier
                        yEnd: .value("Waketime", weekData.chartWaketime),     // Later
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(Color.clear)
                }
            }
        }
        .frame(height: chartHeight)
        .chartBackground { proxy in
            // Selection indicator line - rendered as background so bars overlay it
            if let selectedWeek = selectedWeek,
               let xPosition = proxy.position(forX: selectedWeek.weekStartDate) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .position(x: xPosition, y: geometry.size.height / 2)
                }
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    handleChartTap(proxy: proxy, location: value.location)
                }
        }
        .onChange(of: scrollPosition) { oldValue, newValue in
            NSLog("[SLEEP] 📍 scrollPosition changed: \(oldValue) → \(newValue)")
            handleChartScrolling(position: newValue)
            // Force view update to refresh date range
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                if let dateValue = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatYAxisTimeLabel(for: dateValue))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.2))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                if value.as(Date.self) != nil {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    // Loading indicators
    private var loadingIndicators: some View {
        HStack {
            if dataManager.isLoadingOlder {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading older data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if dataManager.isLoadingNewer {
                Text("Loading newer data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .frame(height: 20)
        .padding(.horizontal)
    }
    
    // Helper: Get bar color based on selection
    private func getBarColor(for weekData: ChartWeekData) -> Color {
        // If a stage is selected, make all bars darker grey
        if selectedStage != nil {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
        // Normal selection highlighting
        if let week = weekData.week, selectedWeek?.id == week.id {
            return barColor.opacity(0.6)
        }
        return barColor
    }
    
    // Helper: Handle chart tap gesture
    private func handleChartTap(proxy: ChartProxy, location: CGPoint) {
        NSLog("[SLEEP] 📍 handleChartTap: Tap at location \(location)")
        guard let tappedDate: Date = proxy.value(atX: location.x) else {
            NSLog("[SLEEP] ⚠️ handleChartTap: Could not get date from tap location")
            return
        }

        NSLog("[SLEEP] 📍 handleChartTap: Tapped date = \(tappedDate)")

        // Find closest week with data
        let closest = chartData.compactMap { $0.week }.min(by: {
            abs($0.weekStartDate.timeIntervalSince(tappedDate)) < abs($1.weekStartDate.timeIntervalSince(tappedDate))
        })

        let calendar = Calendar.current
        if let week = closest {
            if selectedWeek?.id == week.id {
                NSLog("[SLEEP] 📍 handleChartTap: Deselecting week \(week.weekStartDate)")
                selectedWeek = nil
                // Reset visible range to full 26-week window
                let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60
                if let endDate = calendar.date(byAdding: .second, value: Int(visibleDomainLength), to: scrollPosition) {
                    visibleRangeBinding = (scrollPosition, endDate)
                }
            } else {
                NSLog("[SLEEP] 📍 handleChartTap: Selecting week \(week.weekStartDate) - \(formatTime(week.avgBedtime)) to \(formatTime(week.avgWaketime))")
                selectedWeek = week
                // Update visible range to just the selected week for amounts calculation
                if let weekEnd = calendar.date(byAdding: .day, value: 6, to: week.weekStartDate) {
                    visibleRangeBinding = (week.weekStartDate, weekEnd)
                    NSLog("[SLEEP] 📍 handleChartTap: Updated visibleRangeBinding to \(week.weekStartDate) - \(weekEnd)")
                }
            }
        } else {
            NSLog("[SLEEP] ⚠️ handleChartTap: No closest week found")
        }
    }
    
    // Helper: Initialize scroll position (like MetricDetailView lines 630-643)
    // Position scroll so today is ~90% across visible window (leaving 10% for future)
    private func initializeScrollPosition() {
        NSLog("[SLEEP] 📍 initializeScrollPosition: Starting, chartData count = \(chartData.count)")
        guard !chartData.isEmpty else {
            NSLog("[SLEEP] ⚠️ initializeScrollPosition: chartData is empty, skipping")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let visibleDuration = 26 // 26 weeks for sixMonth
        
        // Position scroll so today is ~90% across the visible window (leaving 10% for future)
        // scrollPosition is the LEFT edge of the visible window
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let newPosition = calendar.date(
            byAdding: .weekOfYear,
            value: -offsetFromEnd,
            to: now
        ) ?? now
        
        // Calculate what the visible window will be
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60
        let visibleEnd = calendar.date(byAdding: .second, value: Int(visibleDomainLength), to: newPosition) ?? newPosition
        
        NSLog("[SLEEP] 📍 initializeScrollPosition: Setting scroll position to \(newPosition)")
        NSLog("[SLEEP] 📍 initializeScrollPosition: Visible window will be from \(newPosition) to \(visibleEnd)")
        if let firstWeek = chartData.first, let lastWeek = chartData.last {
            NSLog("[SLEEP] 📍 initializeScrollPosition: chartData range - first: \(firstWeek.weekStartDate), last: \(lastWeek.weekStartDate)")
        }
        
        scrollPosition = newPosition
    }
    
    // Handle scrolling for infinite scroll (like MetricDetailView)
    private func handleChartScrolling(position: Date) {
        guard !dataManager.chartWeekData.isEmpty else { return }

        // Notify parent of visible range change
        let calendar = Calendar.current
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60 // 26 weeks
        if let endDate = calendar.date(byAdding: .second, value: Int(visibleDomainLength), to: position) {
            // Update binding for parent
            visibleRangeBinding = (position, endDate)
            onVisibleRangeChange?(position, endDate)
        }

        // Find the week at scroll position
        let weekAtPosition = dataManager.chartWeekData.first(where: { weekGroup in
            let weekStart = weekGroup.weekStartDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return weekStart <= position && position < weekEnd
        })
        
        if let weekGroup = weekAtPosition, let week = weekGroup.week {
            dataManager.checkEdges(visibleWeek: week)
        } else if let weekGroup = weekAtPosition {
            // Even without data, check edges
            if let oldestTimeline = dataManager.chartWeekData.first?.weekStartDate,
               let newestTimeline = dataManager.chartWeekData.last?.weekStartDate {
                let daysFromOldest = calendar.dateComponents([.day], from: oldestTimeline, to: weekGroup.weekStartDate).day ?? 0
                let daysFromNewest = calendar.dateComponents([.day], from: weekGroup.weekStartDate, to: newestTimeline).day ?? 0
                
                if daysFromOldest >= 0 && daysFromOldest <= 21 && !dataManager.isLoadingOlder {
                    NSLog("[SLEEP] 📊 Near oldest edge (empty week), loading older data")
                    Task { await dataManager.loadOlderData() }
                } else if daysFromNewest >= 0 && daysFromNewest <= 21 && !dataManager.isLoadingNewer {
                    let now = Date()
                    let twoMonthsAhead = calendar.date(byAdding: .month, value: 2, to: now) ?? now
                    if newestTimeline < twoMonthsAhead {
                        NSLog("[SLEEP] 📊 Near newest edge (empty week), loading newer data")
                        Task { await dataManager.loadNewerData() }
                    }
                }
            }
        }
    }
    
    // Format Y-axis time label from inverted Date domain
    // Mapping: date = sixPMReference + (maxMinutes - actualMinutes)
    private func formatYAxisTimeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        // Use the SAME reference date as yAxisDomain (today)
        let referenceDate = calendar.startOfDay(for: Date())
        guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
            NSLog("[SLEEP] ⚠️ formatYAxisTimeLabel: Failed to create sixPMReference")
            return ""
        }
        
        let maxMinutes = 24 * 60
        // Calculate minutes difference - using DIRECT offsets
        let minutesSinceReference = calendar.dateComponents([.minute], from: sixPMReference, to: date).minute ?? 0

        // Direct mapping: date = sixPMReference + actualMinutes
        let actualMinutes = minutesSinceReference

        // Handle wrap-around: ensure in range 0-1440
        let normalizedMinutes: Int
        if actualMinutes >= 0 && actualMinutes < maxMinutes {
            normalizedMinutes = actualMinutes
        } else if actualMinutes < 0 {
            normalizedMinutes = ((actualMinutes % maxMinutes) + maxMinutes) % maxMinutes
        } else {
            normalizedMinutes = actualMinutes % maxMinutes
        }
        
        // Convert to hour: 0 minutes = 6 PM (18:00), 300 minutes = 11 PM (23:00), 780 minutes = 7 AM (7:00)
        let hour = (normalizedMinutes / 60 + 18) % 24
        
        let result = formatHourLabel(hour)
        NSLog("[SLEEP] 📊 formatYAxisTimeLabel: date = \(date), actualMinutes = \(normalizedMinutes), hour = \(hour), result = '\(result)'")
        return result
    }
    

    // Format Date to readable time string (e.g., "11:00 PM", "7:15 AM")
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    // Normalize date to UTC midnight
    private func normalizeToUTCMidnight(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return utcCalendar.date(from: components) ?? date
    }
    
    private func formatWeekRange(_ start: Date, _ end: Date) -> String {
        NSLog("[SLEEP] 📅 formatWeekRange: Input - start: \(start), end: \(end)")
        // Dates from database are already start-of-day in UTC (e.g., 2024-11-03 00:00:00+00)
        // Use UTC calendar to extract date components to avoid timezone shifts
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")! // Format in UTC to match database dates

        let year = utcCalendar.component(.year, from: end)
        let result = "\(formatter.string(from: start)) - \(formatter.string(from: end)), \(year)"
        NSLog("[SLEEP] 📅 formatWeekRange: Result - '\(result)' (from \(start) to \(end) in UTC)")
        return result
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Year View (Monthly Aggregations)
struct MonthlySleepChart: View {
    @ObservedObject var viewModel: SleepAnalysisViewModel
    @State private var scrollPosition: Date?
    @State private var selectedMonth: MonthlyAverage?
    @State private var scrolledMonthID: Date?

    private let barColor = Color(red: 0x6E / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryMetrics

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else if viewModel.monthlyAverages.isEmpty {
                Text("No monthly data available")
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .foregroundColor(.secondary)
            } else {
                chartView
            }
        }
        .onAppear {
            // Only load if we don't have data and aren't already loading
            guard viewModel.monthlyAverages.isEmpty && !viewModel.isLoading else { return }
            Task {
                await viewModel.loadInitialMonthlyAverages()
            }
        }
    }

    // Calculate average bedtime and waketime from visible months (first 12 months with data)
    private func calculateVisibleMonthlyAverages() -> (bedtime: Date, waketime: Date) {
        let months = groupedByMonth()
        let visibleMonths = months.compactMap { $0.month } // Only months with data
        guard !visibleMonths.isEmpty else {
            // Return default times (11 PM bedtime, 7 AM waketime)
            let calendar = Calendar.current
            let bedtime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
            let waketime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
            return (bedtime, waketime)
        }
        
        // Calculate average by averaging the time components
        let calendar = Calendar.current
        var totalBedtimeSeconds: TimeInterval = 0
        var totalWaketimeSeconds: TimeInterval = 0
        var count = 0
        
        for month in visibleMonths {
            let bedtimeComponents = calendar.dateComponents([.hour, .minute, .second], from: month.avgBedtime)
            let waketimeComponents = calendar.dateComponents([.hour, .minute, .second], from: month.avgWaketime)
            
            if let bedtimeHour = bedtimeComponents.hour, let bedtimeMinute = bedtimeComponents.minute,
               let waketimeHour = waketimeComponents.hour, let waketimeMinute = waketimeComponents.minute {
                totalBedtimeSeconds += Double(bedtimeHour * 3600 + bedtimeMinute * 60)
                totalWaketimeSeconds += Double(waketimeHour * 3600 + waketimeMinute * 60)
                count += 1
            }
        }
        
        guard count > 0 else {
            let defaultBedtime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
            let defaultWaketime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
            return (defaultBedtime, defaultWaketime)
        }
        
        let avgBedtimeSeconds = totalBedtimeSeconds / Double(count)
        let avgWaketimeSeconds = totalWaketimeSeconds / Double(count)
        
        let bedtimeHour = Int(avgBedtimeSeconds) / 3600
        let bedtimeMinute = (Int(avgBedtimeSeconds) % 3600) / 60
        let waketimeHour = Int(avgWaketimeSeconds) / 3600
        let waketimeMinute = (Int(avgWaketimeSeconds) % 3600) / 60
        
        let avgBedtime = calendar.date(bySettingHour: bedtimeHour, minute: bedtimeMinute, second: 0, of: Date()) ?? Date()
        let avgWaketime = calendar.date(bySettingHour: waketimeHour, minute: waketimeMinute, second: 0, of: Date()) ?? Date()
        
        return (avgBedtime, avgWaketime)
    }
    
    private var summaryMetrics: some View {
        let averages = selectedMonth == nil ? calculateVisibleMonthlyAverages() : nil
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Bedtime").font(.caption).foregroundColor(.secondary)
                    if let month = selectedMonth {
                        Text(formatTime(month.avgBedtime))
                            .font(.title2).fontWeight(.semibold)
                    } else if let avg = averages {
                        Text(formatTime(avg.bedtime))
                            .font(.title2).fontWeight(.semibold)
                    } else {
                        Text("No Data")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Waketime").font(.caption).foregroundColor(.secondary)
                    if let month = selectedMonth {
                        Text(formatTime(month.avgWaketime))
                            .font(.title2).fontWeight(.semibold)
                    } else if let avg = averages {
                        Text(formatTime(avg.waketime))
                            .font(.title2).fontWeight(.semibold)
                    } else {
                        Text("No Data")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if let month = selectedMonth {
                Text(formatMonthLabel(month.monthStartDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                monthlyDateRangeText
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private func formatMonthlyDateRange() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate 12 months ago (first day of that month)
        guard let startMonth = calendar.date(byAdding: .month, value: -12, to: today) else {
            return ""
        }
        var startComponents = calendar.dateComponents([.year, .month], from: startMonth)
        startComponents.day = 1
        guard let startMonthFirstDay = calendar.date(from: startComponents) else {
            return ""
        }

        // Calculate end of current month (last day)
        var endComponents = calendar.dateComponents([.year, .month], from: today)
        endComponents.day = 1
        guard let currentMonthFirstDay = calendar.date(from: endComponents),
              let currentMonthLastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: currentMonthFirstDay) else {
            return ""
        }

        let normalizedStart = normalizeToUTCMidnight(startMonthFirstDay)
        let normalizedEnd = normalizeToUTCMidnight(currentMonthLastDay)

        // Check if range spans Jan-Dec of the same year
        let startMonthComponent = calendar.component(.month, from: normalizedStart)
        let endMonthComponent = calendar.component(.month, from: normalizedEnd)
        let startYear = calendar.component(.year, from: normalizedStart)
        let endYear = calendar.component(.year, from: normalizedEnd)

        // If Jan-Dec of same year, show just the year
        if startMonthComponent == 1 && endMonthComponent == 12 && startYear == endYear {
            return "\(startYear)"
        }

        // Otherwise, show "Nov 2024-Nov 2025" format
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: normalizedStart)) - \(formatter.string(from: normalizedEnd))"
    }
    
    @ViewBuilder
    private var monthlyDateRangeText: some View {
        Text(formatMonthlyDateRange())
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    private let chartHeight: CGFloat = 280
    private let monthSpacing: CGFloat = 4
    private let visibleMonths: Int = 12
    private let barWidthRatio: CGFloat = 0.8
    
    // Generate continuous 12-month range (like groupedByDate for W/M views)
    private func groupedByMonth() -> [(monthStartDate: Date, month: MonthlyAverage?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate 12 months ago (first day of that month)
        guard let startMonth = calendar.date(byAdding: .month, value: -12, to: today) else {
            return []
        }
        var startComponents = calendar.dateComponents([.year, .month], from: startMonth)
        startComponents.day = 1
        guard let startMonthFirstDay = calendar.date(from: startComponents) else {
            return []
        }
        
        // Create dictionary mapping month start dates to MonthlyAverage
        let monthDataMap = Dictionary(grouping: viewModel.monthlyAverages) { month in
            calendar.startOfDay(for: month.monthStartDate)
        }.compactMapValues { $0.first }
        
        var groups: [(monthStartDate: Date, month: MonthlyAverage?)] = []
        var currentMonth = startMonthFirstDay
        
        // Generate 12 months
        for _ in 0..<12 {
            let monthStart = calendar.startOfDay(for: currentMonth)
            let monthData = monthDataMap[monthStart]
            groups.append((monthStartDate: monthStart, month: monthData))
            
            // Move to first day of next month
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { break }
            currentMonth = nextMonth
        }
        
        return groups
    }

    private var chartView: some View {
        GeometryReader { geometry in
            let timeRange = calculateMonthlyTimeRange()
            let chartAreaWidth = geometry.size.width - 50
            let totalSpacing = monthSpacing * CGFloat(visibleMonths - 1)
            let monthWidth = (chartAreaWidth - totalSpacing) / CGFloat(visibleMonths)
            let barWidth = monthWidth * barWidthRatio
            let barXOffset = (monthWidth - barWidth) / 2.0

            HStack(alignment: .top, spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: monthSpacing) {
                            let months = groupedByMonth()
                            ForEach(Array(months.enumerated()), id: \.offset) { _, monthGroup in
                                VStack(spacing: 0) {
                                    // Month column
                                    ZStack(alignment: .leading) {
                                        // Grid lines
                                        Canvas { context, size in
                                            drawMonthlyGridLines(context: context, size: size, timeRange: timeRange)
                                        }
                                        .frame(width: monthWidth, height: chartHeight)

                                        // Selection indicator: single center line (Apple Health style) - drawn before bar to render behind it
                                        if let month = monthGroup.month, selectedMonth?.id == month.id {
                                            Rectangle()
                                                .fill(Color.secondary)
                                                .frame(width: 2)
                                                .frame(height: chartHeight)
                                                .offset(x: barXOffset + barWidth / 2)
                                        }

                                        // Sleep bar (only if data exists) - drawn after selection line to render in front
                                        if let month = monthGroup.month {
                                            Canvas { context, size in
                                                drawMonthlyBar(
                                                    context: context,
                                                    size: size,
                                                    month: month,
                                                    timeRange: timeRange,
                                                    barXOffset: barXOffset,
                                                    barWidth: barWidth,
                                                    isSelected: selectedMonth?.id == month.id
                                                )
                                            }
                                            .frame(width: monthWidth, height: chartHeight)
                                        }
                                    }
                                    .frame(width: monthWidth, height: chartHeight)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let month = monthGroup.month {
                                            selectedMonth = month
                                        }
                                    }
                                    
                                    // Month label (single letter) - BELOW the chart
                                    Text(monthInitial(monthGroup.monthStartDate))
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.secondary)
                                        .frame(height: 24)
                                        .frame(width: monthWidth)
                                }
                                .id(monthGroup.monthStartDate)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 12)
                    }
                    .scrollPosition(id: $scrolledMonthID, anchor: .leading)
                        .scrollTargetBehavior(.viewAligned)
                        .onChange(of: scrolledMonthID) { _, newID in
                            guard let newID = newID else { return }
                            // Find the month by monthStartDate and update visible range for edge detection
                            let months = groupedByMonth()
                            if let monthGroup = months.first(where: { $0.monthStartDate == newID }),
                               let month = monthGroup.month {
                                checkMonthlyEdges(visibleMonth: month)
                            }
                        }
                        .onAppear {
                            // Find month containing today
                            let months = groupedByMonth()
                            let calendar = Calendar.current
                            let today = Date()

                            // Find the month that contains today
                            let todayMonth = months.first(where: { month in
                                guard let monthData = month.month else { return false }
                                let monthStart = monthData.monthStartDate
                                guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return false }
                                return monthStart <= today && today < monthEnd
                            })

                            if let currentMonth = todayMonth {
                                // Scroll to show today's month on the right with padding
                                scrolledMonthID = currentMonth.monthStartDate
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    proxy.scrollTo(currentMonth.monthStartDate, anchor: .trailing)
                                }
                            } else if let lastMonth = months.last {
                                scrolledMonthID = lastMonth.monthStartDate
                            }
                        }
                }

                // Y-axis
                monthlyYAxisView(timeRange: timeRange).frame(width: 50)
            }
        }
        .frame(height: chartHeight + 24) // chartHeight + X-axis label height
    }
    
    private func adjustedHour(from date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let clockHour = hour + (minute / 60.0)
        
        return clockHour >= 18.0 ? clockHour - 18.0 : clockHour + 6.0
    }
    
    private func calculateMonthlyTimeRange() -> (startHour: Double, endHour: Double, totalHours: Double) {
        // Calculate visible months (first 12 months with data)
        let months = groupedByMonth()
        let visibleMonths = months.compactMap { $0.month } // Only months with data
        guard !visibleMonths.isEmpty else {
            // Fallback: 8PM to 8AM
            return (2.0, 14.0, 12.0)
        }
        
        var earliest = 24.0
        var latest = 0.0
        
        for month in visibleMonths {
            let bedtimeHour = adjustedHour(from: month.avgBedtime)
            let waketimeHour = adjustedHour(from: month.avgWaketime)
            earliest = min(earliest, bedtimeHour)
            latest = max(latest, waketimeHour)
        }
        
        guard earliest < 24.0 && latest > 0.0 else {
            // No valid data, use default
            return (2.0, 14.0, 12.0)
        }
        
        let bufferedStart = max(0, earliest - 1)
        let bufferedEnd = min(24, latest + 1)
        let totalHours = bufferedEnd - bufferedStart
        
        guard totalHours > 0 else {
            return (2.0, 14.0, 12.0)
        }
        
        return (bufferedStart, bufferedEnd, totalHours)
    }
    
    // Edge detection for Y view (similar to checkEdges for W/M views)
    private func checkMonthlyEdges(visibleMonth: MonthlyAverage) {
        let calendar = Calendar.current
        let monthDates = viewModel.monthlyAverages.map { calendar.startOfDay(for: $0.monthStartDate) }
        
        guard let oldestData = monthDates.min(), let newestData = monthDates.max() else { return }
        
        let visibleDate = calendar.startOfDay(for: visibleMonth.monthStartDate)
        
        // Load older data when scrolled near beginning (oldest)
        if let diff = calendar.dateComponents([.month], from: oldestData, to: visibleDate).month, diff >= 0, diff <= 3, !viewModel.isLoadingOlder {
            Task { await viewModel.loadEarlierMonthlyAverages() }
        }
        
        // Load newer data when scrolled near end (newest)
        if let diff = calendar.dateComponents([.month], from: visibleDate, to: newestData).month, diff >= 0, diff <= 3, !viewModel.isLoadingNewer {
            Task { await viewModel.loadLaterMonthlyAverages() }
        }
    }
    
    private func drawMonthlyGridLines(context: GraphicsContext, size: CGSize, timeRange: (startHour: Double, endHour: Double, totalHours: Double)) {
        let hourLabels = generateMonthlyHourLabels(timeRange: timeRange)
        for adjustedHour in hourLabels {
            let yPosition = ((adjustedHour - timeRange.startHour) / timeRange.totalHours) * size.height
            // Clamp yPosition to valid bounds
            guard yPosition >= 0 && yPosition <= size.height else { continue }
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: yPosition))
                p.addLine(to: CGPoint(x: size.width, y: yPosition))
            }
            context.stroke(path, with: .color(Color.gray.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5))
        }
    }
    
    private func drawMonthlyBar(context: GraphicsContext, size: CGSize, month: MonthlyAverage, timeRange: (startHour: Double, endHour: Double, totalHours: Double), barXOffset: CGFloat, barWidth: CGFloat, isSelected: Bool) {
        let bedtimeHour = adjustedHour(from: month.avgBedtime)
        let waketimeHour = adjustedHour(from: month.avgWaketime)
        
        guard waketimeHour > bedtimeHour else { return }
        guard timeRange.totalHours > 0 else { return }
        
        let segmentStart = bedtimeHour
        let segmentEnd = waketimeHour
        let segmentDuration = segmentEnd - segmentStart
        
        let yPosition = ((segmentStart - timeRange.startHour) / timeRange.totalHours) * size.height
        let height = max((segmentDuration / timeRange.totalHours) * size.height, 2.0)
        
        // Clamp bar coordinates to valid bounds
        let clampedY = max(0, min(yPosition, size.height - height))
        let clampedHeight = min(height, size.height - clampedY)
        
        guard clampedHeight >= 2.0 else { return }
        
        let rect = CGRect(x: barXOffset, y: clampedY, width: barWidth, height: clampedHeight)
        var segmentContext = context
        if isSelected { segmentContext.opacity = 1.0 }
        segmentContext.fill(Path(rect), with: .color(barColor))
    }
    
    private func generateMonthlyHourLabels(timeRange: (startHour: Double, endHour: Double, totalHours: Double)) -> [Double] {
        var labels: [Double] = []
        let interval: Double = 3
        let startHour = (Int(timeRange.startHour) / Int(interval)) * Int(interval)
        var currentHour = Double(startHour)
        
        while currentHour <= timeRange.endHour {
            labels.append(currentHour)
            currentHour += interval
        }
        
        return labels
    }
    
    private func monthlyYAxisView(timeRange: (startHour: Double, endHour: Double, totalHours: Double)) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Y-axis line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                    .frame(height: geometry.size.height)
                    .offset(x: 45)
                
                ForEach(generateMonthlyHourLabels(timeRange: timeRange), id: \.self) { adjustedHour in
                    let yPosition = ((adjustedHour - timeRange.startHour) / timeRange.totalHours) * geometry.size.height
                    // Clamp yPosition to valid bounds within the geometry
                    let clampedY = max(10, min(yPosition, geometry.size.height - 10))
                    let displayHour = clockHour(from: adjustedHour)
                    
                    Text(formatHourLabel(displayHour))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .position(x: 25, y: clampedY)
                }
            }
        }
        .frame(width: 50, height: chartHeight)
    }
    
    private func clockHour(from adjustedHour: Double) -> Int {
        let adjusted = Int(adjustedHour)
        return adjusted < 6 ? adjusted + 18 : adjusted - 6
    }

    // Format Date to readable time string (e.g., "11:00 PM", "7:15 AM")
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func monthInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMMM"
        let month = formatter.string(from: date)
        return String(month.prefix(1))
    }
    

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    // Normalize date to UTC midnight
    private func normalizeToUTCMidnight(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return utcCalendar.date(from: components) ?? date
    }
    
    private func formatMonthLabel(_ date: Date) -> String {
        let normalizedDate = normalizeToUTCMidnight(date)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, yyyy"
        return formatter.string(from: normalizedDate)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    WeeklySleepChart(viewModel: SleepAnalysisViewModel(), selectedStage: .constant(nil), showAbout: .constant(false))
}


