# Chart Standardization Guide

This document outlines the standard patterns for chart layouts, titles, and spacing across all WellPath metric views.

## Reference Implementation

The **Sleep Duration** view (`SleepDurationView.swift`) serves as the reference implementation for chart standardization.

## Standard Layout Structure

```
VStack(spacing: 0) {
    // 1. Period Selector
    Picker("Period", selection: $selectedPeriod) { ... }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 16)

    // 2. Header with Value Display
    HStack(alignment: .top, spacing: 40) {
        VStack(alignment: .leading, spacing: 4) {
            Text(labelText)           // "DAILY TOTAL" or "AVERAGE"
                .font(.caption)
                .foregroundColor(.secondary)
            Text(valueText)           // "7h 32m" or "156g"
                .font(.system(size: 48, weight: .semibold))
            Text(dateRangeText)       // "Dec 1 - Dec 7, 2025"
                .font(.subheadline)
                .foregroundColor(.secondary)
        }

        Spacer()

        Button { showAboutModal = true } {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundColor(color)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
    .padding(.top, 12)

    // 3. Chart
    Chart { ... }
        .frame(height: 280)
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
}
.background(Color(uiColor: .systemGroupedBackground))
```

## Standard Spacing Values

| Element | Spacing |
|---------|---------|
| Period selector top padding | 16pt |
| Header top padding (after selector) | 12pt |
| Chart top padding (after header) | 16pt |
| Chart bottom padding | 24pt |
| Horizontal padding (all elements) | 16pt (via `.padding(.horizontal)`) |

## Standard Heights

| Chart Type | Height |
|------------|--------|
| Standard bar/line charts | 280pt |
| Loading/empty state containers | 300pt |
| Mini card charts | 50-60pt |

## Period Selector Labels

The header label changes based on whether a specific bar is selected:

```swift
Text(selectedBarDate != nil ? selectedPeriod.barLabel : selectedPeriod.aggregateLabel)
```

**TimePeriod extensions needed:**

```swift
extension TimePeriod {
    var barLabel: String {
        switch self {
        case .day: return "HOURLY"
        case .week: return "DAILY TOTAL"
        case .month: return "DAILY TOTAL"
        case .sixMonth: return "WEEKLY AVERAGE"
        case .year: return "MONTHLY AVERAGE"
        }
    }

    var aggregateLabel: String {
        switch self {
        case .day: return "DAILY TOTAL"
        case .week: return "DAILY AVERAGE"
        case .month: return "DAILY AVERAGE"
        case .sixMonth: return "DAILY AVERAGE"
        case .year: return "DAILY AVERAGE"
        }
    }
}
```

## Background Pattern

All metric detail views should use the two-layer background:

```swift
// Outer wrapper (applied to NavigationStack content)
.metricScreenBackground(color: pillarColor)

// Inner chart container
.background(Color(uiColor: .systemGroupedBackground))
```

## Y-Axis Guidelines

### Label Formatting
- Use abbreviated units: "8h" not "8 hours", "150g" not "150 grams"
- Max 6 labels on Y-axis for readability
- For time-based metrics, use hour-based labels with even spacing

### Preventing Label Cutoff
Charts should use `.chartYAxis { AxisMarks(position: .leading) }` and ensure adequate left padding:

```swift
Chart { ... }
    .chartYAxis {
        AxisMarks(position: .leading) { value in
            AxisValueLabel {
                if let hours = value.as(Double.self) {
                    Text("\(Int(hours))h")
                }
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                .foregroundStyle(Color.secondary.opacity(0.2))
        }
    }
    .padding(.horizontal)  // This provides space for Y-axis labels
```

## X-Axis Formatting by Period

```swift
private func getAxisStride() -> Calendar.Component {
    switch selectedPeriod {
    case .day: return .hour
    case .week: return .day
    case .month: return .weekOfYear
    case .sixMonth: return .month
    case .year: return .month
    }
}

private func getAxisFormat() -> Date.FormatStyle {
    switch selectedPeriod {
    case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
    case .week: return .dateTime.weekday(.narrow)  // M, T, W...
    case .month: return .dateTime.day(.defaultDigits)  // 1, 2, 3...
    case .sixMonth: return .dateTime.month(.abbreviated)  // Jan, Feb...
    case .year: return .dateTime.month(.narrow)  // J, F, M...
    }
}
```

## Empty State Pattern

When no data exists:

```swift
if viewModel.chartData.isEmpty {
    VStack(spacing: 12) {
        Image(systemName: "chart.bar.xaxis")  // or metric-specific icon
            .font(.system(size: 48))
            .foregroundColor(.secondary.opacity(0.5))
        Text("No data available")
            .font(.headline)
            .foregroundColor(.secondary)
        Text("Data will appear here once tracked.")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 300)
}
```

## Files to Update

The following views should be audited for consistency:

### Sleep Pillar
- [x] `SleepDurationView.swift` - Reference implementation
- [x] `SleepAnalysisView.swift` - Y-axis fixed to .leading
- [x] `SleepConsistencyView.swift` - Y-axis fixed to .leading
- [x] `SleepPercentagesChart.swift` - Y-axis fixed to .leading

### Nutrition Pillar
- [ ] `ProteinPrimary.swift`
- [ ] `ProteinTimingChart.swift`
- [ ] `ProteinTypeChart.swift`
- [ ] Other nutrient views

### Movement Pillar
- [ ] `StepsPrimary.swift`
- [ ] `CardioPrimary.swift`
- [ ] Other movement views

## Checklist for Each View

When standardizing a chart view:

1. [ ] Period selector has correct padding (top: 16pt, horizontal: default)
2. [ ] Header uses standard layout with value, label, date range, info button
3. [ ] Chart height is 280pt (or appropriate standard)
4. [ ] Chart has correct padding (top: 16pt, bottom: 24pt, horizontal: default)
5. [ ] Y-axis uses `.position(.leading)` with abbreviated labels
6. [ ] X-axis uses period-appropriate stride and format
7. [ ] Empty state shows icon + message when no data
8. [ ] Background uses two-layer pattern
9. [ ] Info button triggers About modal
