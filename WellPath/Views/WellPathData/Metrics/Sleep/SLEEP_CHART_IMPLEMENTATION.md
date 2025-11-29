# Sleep Chart Implementation Guide

## Overview
This document describes the implementation details for the 6-month sleep analysis chart, which can be adapted for other time period views (daily, weekly, monthly, yearly).

## Key Technical Challenges & Solutions

### 1. Y-Axis Orientation (Custom 6 PM to 6 PM Sleep Day)

**Problem**: Need to display times chronologically from 6 PM (top) to 6 PM next day (bottom), so 11 PM appears higher than 7 AM.

**Solution**: Use direct time offsets from 6 PM reference point
- 6 PM = 0 minutes
- 11 PM = 300 minutes (5 hours after 6 PM)
- 7 AM = 780 minutes (13 hours after 6 PM)
- 6 PM next day = 1440 minutes (24 hours)

**Key Code Pattern**:
```swift
// Reference point: 6 PM today
let sixPMReference = /* create 6 PM date */

// Convert bedtime/waketime to offsets
let bedtimeOffset = 300  // 11 PM = 300 min from 6 PM
let waketimeOffset = 780 // 7 AM = 780 min from 6 PM

// Create chart dates
let chartBedtime = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference)
let chartWaketime = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference)
```

**Why This Works**:
- Swift Charts naturally places domain start at bottom, end at top
- Using direct offsets (not inverted/negative) allows natural progression
- BarMark with `yStart: bedtime, yEnd: waketime` renders correctly when bedtime < waketime in offset values

### 2. Dynamic Y-Axis Domain

**Problem**: Chart should adjust to show only the relevant sleep time range, not full 6 PM to 6 PM.

**Solution**: Calculate domain from actual data range
```swift
var yAxisDomain: ClosedRange<Date> {
    let weeksWithData = chartData.filter { $0.week != nil }

    if weeksWithData.isEmpty {
        // Default: 8 PM (120 min) to 8 AM (840 min)
        domainStartMinutes = 120
        domainEndMinutes = 840
    } else {
        // Find earliest bedtime and latest waketime
        let bedtimes = weeksWithData.compactMap { /* extract bedtime offsets */ }
        let waketimes = weeksWithData.compactMap { /* extract waketime offsets */ }

        domainStartMinutes = bedtimes.min() ?? 120
        domainEndMinutes = waketimes.max() ?? 840
    }

    // Create domain dates from offsets
    return domainStart...domainEnd
}
```

### 3. Y-Axis Labels

**Problem**: Need to display times as "10p", "1a", "7a" instead of raw offset values.

**Solution**: Convert offset back to clock time
```swift
.chartYAxis {
    AxisMarks(position: .leading, values: .stride(by: 3600)) { value in
        if let date = value.as(Date.self) {
            let minutesSinceReference = calendar.dateComponents([.minute],
                                                               from: sixPMReference,
                                                               to: date).minute ?? 0

            // Convert to hour (0 min = 6 PM = 18:00, 300 min = 11 PM = 23:00)
            let hour = (minutesSinceReference / 60 + 18) % 24
            let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            let period = hour < 12 ? "a" : "p"

            AxisValueLabel("\(displayHour)\(period)")
        }
    }
}
```

### 4. Timezone Handling (UTC Database Dates)

**Critical Problem**: Database stores week dates as UTC start-of-day (e.g., 2024-11-03 00:00:00+00), but local calendar operations shift dates.

**Example of Bug**:
- Database: 2024-11-03 00:00:00 UTC (Monday)
- In PST (UTC-8): Displays as 2024-11-02 16:00:00 PST (Sunday evening!)
- `calendar.startOfDay(for:)` on that: 2024-11-02 00:00:00 PST (Sunday) ❌

**Solution**: Always use UTC calendar for database dates
```swift
// WRONG - causes date shift
let calendar = Calendar.current
let localStart = calendar.startOfDay(for: weekStartDate) // Shifts date!

// CORRECT - preserves database dates
var utcCalendar = Calendar.current
utcCalendar.timeZone = TimeZone(identifier: "UTC")!

let formatter = DateFormatter()
formatter.timeZone = TimeZone(identifier: "UTC")!
formatter.dateFormat = "MMM d"

// No startOfDay needed - dates are already start-of-day in UTC
let result = formatter.string(from: weekStartDate)
```

**Where This Applies**:
1. `formatWeekRange()` - displaying selected week dates
2. `visibleDateRangeString()` - displaying scroll window range
3. Any date arithmetic on database dates (adding days, calculating week end)

**Rule**: If date comes from database and represents a "day" (not time), treat it as UTC and never use local calendar operations.

### 5. Chart Data Structure

**ChartWeekData Model**:
```swift
struct ChartWeekData: Identifiable {
    let id = UUID()
    let weekStartDate: Date        // For X-axis positioning (from database, UTC)
    let chartBedtime: Date         // Y-axis value (6 PM reference + offset)
    let chartWaketime: Date        // Y-axis value (6 PM reference + offset)
    let week: WeeklyAverage?       // Original data (nil for empty weeks)
}
```

**Why Separate Chart Fields**:
- `weekStartDate`: Database date in UTC, used for X-axis and display
- `chartBedtime/Waketime`: Computed dates relative to 6 PM reference for Y-axis
- `week`: Original data for metadata (actual times, durations, etc.)

### 6. Empty Weeks Handling

**Problem**: Need to show X-axis labels for weeks with no data.

**Solution**: Generate placeholder data for all weeks in range
```swift
// Generate continuous weekly data
let allWeeks = generateWeeklyRange(from: startDate, to: endDate)

chartData = allWeeks.map { weekStart in
    if let actualWeek = weeklyAverages.first(where: {
        calendar.isDate($0.weekStartDate, equalTo: weekStart, toGranularity: .day)
    }) {
        // Week has data - create full ChartWeekData
        return ChartWeekData(weekStartDate: weekStart,
                            chartBedtime: computed,
                            chartWaketime: computed,
                            week: actualWeek)
    } else {
        // Empty week - placeholder for X-axis
        return ChartWeekData(weekStartDate: weekStart,
                            chartBedtime: sixPMReference,
                            chartWaketime: sixPMReference,
                            week: nil)
    }
}
```

**Chart Rendering**:
```swift
Chart(chartData) { weekData in
    if let week = weekData.week {
        // Only render bars for weeks with data
        BarMark(
            x: .value("Week", weekData.weekStartDate, unit: .weekOfYear),
            yStart: .value("Bedtime", weekData.chartBedtime),
            yEnd: .value("Waketime", weekData.chartWaketime)
        )
    }
    // X-axis labels appear for all weeks (including empty)
}
```

### 7. Chart Selection & Tap Handling

**Pattern**:
```swift
@State private var selectedWeek: WeeklyAverage?

// In chart
.chartOverlay { proxy in
    GeometryReader { geometry in
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleChartTap(proxy: proxy, location: location)
            }
    }
}

private func handleChartTap(proxy: ChartProxy, location: CGPoint) {
    guard let tappedDate: Date = proxy.value(atX: location.x) else { return }

    // Find closest week with data
    let closest = chartData.compactMap { $0.week }.min(by: {
        abs($0.weekStartDate.timeIntervalSince(tappedDate)) <
        abs($1.weekStartDate.timeIntervalSince(tappedDate))
    })

    if let week = closest {
        selectedWeek = (selectedWeek?.id == week.id) ? nil : week
    }
}
```

### 8. Scrollable Chart Domain

**Pattern** (like MetricDetailView):
```swift
@State private var scrollPosition: Date

Chart(chartData) { /* ... */ }
    .chartScrollableAxes(.horizontal)
    .chartXVisibleDomain(length: visibleDomainLength)
    .chartScrollPosition(x: $scrollPosition)

// Initialize scroll to show today at ~90% of visible window
private func initializeScrollPosition() {
    let visibleSeconds = 26 * 7 * 24 * 60 * 60 // 26 weeks
    let ninetyPercentOffset = visibleSeconds * 0.90
    scrollPosition = calendar.date(byAdding: .second,
                                   value: -Int(ninetyPercentOffset),
                                   to: Date()) ?? Date()
}
```

## File Structure for New Chart Views

```
Views/TrackedMetrics/Sleep/
├── SleepConsistency/
│   ├── SleepConsistencyPrimary.swift       # Main view with W/M/6M/Y tabs
│   ├── SleepConsistencyDay.swift           # D view (7 days, daily data)
│   ├── SleepConsistencyWeek.swift          # W view (5 weeks, daily data)
│   ├── SleepConsistencyMonth.swift         # M view (33 days, daily data)
│   ├── SleepConsistencySixMonth.swift      # 6M view (26 weeks, weekly data)
│   └── SleepConsistencyYear.swift          # Y view (52 weeks, monthly data)
```

## Data Requirements by View

### Day View (D) - 7 days
- **Data**: Daily bedtime/waketime from `daily_metrics_cache` (AGG_SLEEP_BEDTIME, AGG_SLEEP_WAKETIME)
- **X-axis**: Date (day granularity)
- **Y-axis**: Time (6 PM to 6 PM)
- **Bars**: One per day

### Week View (W) - 5 weeks = 35 days
- **Data**: Daily bedtime/waketime from `daily_metrics_cache`
- **X-axis**: Date (day granularity)
- **Y-axis**: Time (6 PM to 6 PM)
- **Bars**: One per day

### Month View (M) - 33 days
- **Data**: Daily bedtime/waketime from `daily_metrics_cache`
- **X-axis**: Date (day granularity)
- **Y-axis**: Time (6 PM to 6 PM)
- **Bars**: One per day

### 6-Month View (6M) - 26 weeks
- **Data**: Weekly average bedtime/waketime from `aggregation_results_cache`
- **X-axis**: Week start date (week granularity)
- **Y-axis**: Time (6 PM to 6 PM)
- **Bars**: One per week

### Year View (Y) - 12 months
- **Data**: Monthly average bedtime/waketime from `aggregation_results_cache`
- **X-axis**: Month start date (month granularity)
- **Y-axis**: Time (6 PM to 6 PM)
- **Bars**: One per month

## Consistency Box Implementation

For the consistency view, add a semi-transparent rectangle showing ±30 min from visible average:

```swift
Chart(chartData) { weekData in
    // Sleep bars
    if let week = weekData.week {
        BarMark(...)
    }

    // Consistency range box (rendered first, behind bars)
    RectangleMark(
        xStart: .value("Start", visibleRangeStart),
        xEnd: .value("End", visibleRangeEnd),
        yStart: .value("Lower", avgBedtime - 30min),
        yEnd: .value("Upper", avgWaketime + 30min)
    )
    .foregroundStyle(Color.blue.opacity(0.1))
    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
}
```

**Calculation**:
1. Get visible weeks based on scroll position
2. Calculate average bedtime/waketime from visible weeks
3. Extend box 30 min above/below visible window
4. Draw as background layer

## Common Pitfalls

1. ❌ **Don't** use inverted/negative offsets for Y-axis
   - ✅ Use direct offsets, let Swift Charts natural ordering work

2. ❌ **Don't** use local calendar for database dates
   - ✅ Always use UTC calendar and formatter

3. ❌ **Don't** call `startOfDay` on dates already normalized
   - ✅ Database dates are already start-of-day in UTC

4. ❌ **Don't** try to use `.reversed: true` parameter
   - ✅ Not a real API in Swift Charts

5. ❌ **Don't** use `.scaleEffect(y: -1)` to flip chart
   - ✅ It flips everything including labels upside down

6. ❌ **Don't** filter out empty weeks from chart data
   - ✅ Include placeholders for proper X-axis labels and scrolling

## Testing Checklist

- [ ] Y-axis shows times in correct order (11 PM above 7 AM)
- [ ] Y-axis labels display as "10p", "1a", "7a" format
- [ ] Domain adjusts to data range (not full 6 PM-6 PM when not needed)
- [ ] Empty weeks show X-axis labels but no bars
- [ ] Selected week displays correct date range (no day shift)
- [ ] Scroll window displays week-aligned dates
- [ ] Tapping bars selects/deselects correctly
- [ ] Chart scrolls smoothly
- [ ] Scroll initializes to show today at ~90%
- [ ] Dates match database (UTC) - no timezone shift

## Database Tables

### aggregation_results_cache
```sql
- patient_id: uuid
- agg_metric_id: text (AGG_SLEEP_BEDTIME, AGG_SLEEP_WAKETIME)
- period_type: text (weekly, monthly)
- period_start: timestamptz (UTC start-of-day)
- period_end: timestamptz
- calculation_type_id: text (AVG)
- value_time: time (HH:mm:ss format)
```

### daily_metrics_cache
```sql
- patient_id: uuid
- metric_id: text (daily sleep metrics)
- date: date (UTC)
- value: numeric
- value_time: time (HH:mm:ss format)
```

## Key Files Reference

- `SleepAnalysisPrimary.swift:1695-2520` - 6-month chart implementation
- `SleepAnalysisViewModel.swift:1086-1188` - Weekly averages fetch
- `BiometricsService.swift` - Data fetching layer
- `MetricDetailView.swift:1301-1311` - Week date formatting reference
