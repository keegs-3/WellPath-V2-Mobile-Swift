# Swift Charts Reference for WellPath

## Core Framework Documentation

### Chart Container
The main container for all chart visualizations.

```swift
import Charts

Chart {
    // Chart content goes here
}
.frame(height: 200)
.chartXAxis { /* custom X axis */ }
.chartYAxis { /* custom Y axis */ }
```

## Mark Types

### LineMark
Perfect for time-series data like sleep trends, biomarkers over time.

```swift
LineMark(
    x: .value("Date", date),
    y: .value("Value", value)
)
.foregroundStyle(Color.blue)
.lineStyle(StrokeStyle(lineWidth: 2))
.interpolationMethod(.catmullRom) // Smooth curves
```

### PointMark
Individual data points, useful for discrete measurements.

```swift
PointMark(
    x: .value("Date", date),
    y: .value("Value", value)
)
.foregroundStyle(Color.blue)
.symbolSize(50)
```

### AreaMark
Filled area under a line, great for sleep phases visualization.

```swift
AreaMark(
    x: .value("Time", time),
    yStart: .value("Start", startValue),
    yEnd: .value("End", endValue)
)
.foregroundStyle(Color.blue.opacity(0.3))
```

### BarMark
Vertical or horizontal bars for comparisons.

```swift
BarMark(
    x: .value("Category", category),
    y: .value("Value", value)
)
.foregroundStyle(Color.blue)
.cornerRadius(4)
```

### RectangleMark (Floating Bars)
Perfect for sleep periods, activity blocks, time ranges.

```swift
RectangleMark(
    x: .value("Start", startTime),
    xEnd: .value("End", endTime),
    y: .value("Category", category)
)
.foregroundStyle(Color.blue)
.cornerRadius(4)
```

### RuleMark
Reference lines (average, target, threshold).

```swift
RuleMark(
    y: .value("Average", averageValue)
)
.foregroundStyle(Color.gray.opacity(0.5))
.lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
.annotation(position: .top, alignment: .trailing) {
    Text("Avg: \(averageValue, format: .number)")
        .font(.caption)
        .foregroundColor(.gray)
}
```

## Chart Customization

### Axes

```swift
.chartXAxis {
    AxisMarks(values: .stride(by: .day)) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel(format: .dateTime.month().day())
    }
}

.chartYAxis {
    AxisMarks(position: .leading) { value in
        AxisGridLine()
        AxisValueLabel()
    }
}
```

### Legends

```swift
.chartLegend(position: .top, alignment: .leading)

// Or custom legend
.chartLegend {
    HStack {
        ForEach(dataCategories) { category in
            Label(category.name, systemImage: "circle.fill")
                .foregroundColor(category.color)
        }
    }
}
```

### Scrolling Content

```swift
.chartScrollableAxes(.horizontal)
.chartXVisibleDomain(length: visibleDays * 24 * 3600) // Visible window in seconds
.chartScrollPosition(x: $scrollPosition)
```

### Scales and Domains

```swift
// Fixed scale
.chartYScale(domain: 0...100)

// Date range
.chartXScale(domain: startDate...endDate)

// Automatic with padding
.chartYScale(domain: .automatic(includesZero: false))
```

### Interactive Selection

```swift
.chartAngleSelection(value: $selectedAngle)
.chartXSelection(value: $selectedDate)

// With custom overlay
.chartOverlay { proxy in
    GeometryReader { geometry in
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                        if let date: Date = proxy.value(atX: x) {
                            selectedDate = date
                        }
                    }
            )
    }
}
```

## Data Formatting

### Date Formatters

```swift
// For X-axis labels
.dateTime.month().day()           // "Dec 25"
.dateTime.hour()                  // "10 AM"
.dateTime.weekday()               // "Mon"
.dateTime.month()                 // "December"
```

### Number Formatters

```swift
// For Y-axis values
.number.precision(.fractionLength(0))     // Integers
.number.precision(.fractionLength(1))     // One decimal
.percent                                   // Percentage
```

## Performance Optimization

### Lazy Loading Strategy

```swift
// Load data in chunks based on visible range
func loadDataForRange(_ range: ClosedRange<Date>) async {
    let newData = await dataService.fetchData(for: range)
    withAnimation {
        self.chartData.append(contentsOf: newData)
    }
}

// Monitor scroll position to trigger loading
.onChange(of: scrollPosition) { _, newValue in
    if shouldLoadMore(at: newValue) {
        Task {
            await loadDataForRange(calculateNextRange(from: newValue))
        }
    }
}
```

### Data Decimation
Reduce data points when zoomed out:

```swift
func decimateData(_ data: [DataPoint], targetPoints: Int) -> [DataPoint] {
    guard data.count > targetPoints else { return data }
    
    let stride = data.count / targetPoints
    return data.enumerated()
        .filter { $0.offset % stride == 0 }
        .map { $0.element }
}
```

## Common Patterns

### Multiple Series

```swift
Chart {
    ForEach(seriesData) { series in
        ForEach(series.points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Series", series.name))
        }
    }
}
```

### Stacked Areas

```swift
Chart {
    ForEach(categories) { category in
        ForEach(category.data) { point in
            AreaMark(
                x: .value("Time", point.time),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Category", category.name))
        }
    }
}
.chartForegroundStyleScale([
    "Deep": .blue,
    "REM": .purple,
    "Light": .cyan
])
```

### Annotations

```swift
.chartOverlay { proxy in
    if let selectedPoint = selectedDataPoint {
        GeometryReader { geometry in
            if let xPosition = proxy.position(forX: selectedPoint.date),
               let yPosition = proxy.position(forY: selectedPoint.value) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedPoint.date, format: .dateTime)
                    Text("\(selectedPoint.value, format: .number)")
                }
                .padding(8)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 4)
                .position(
                    x: xPosition + geometry[proxy.plotAreaFrame].origin.x,
                    y: yPosition + geometry[proxy.plotAreaFrame].origin.y - 50
                )
            }
        }
    }
}
```

## Time Period Views (D/W/M/6M/Y)

### Date Range Calculator

```swift
enum TimePeriod: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"
    
    var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            return calendar.startOfDay(for: now)...now
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return start...now
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return start...now
        case .sixMonths:
            let start = calendar.date(byAdding: .month, value: -6, to: now)!
            return start...now
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return start...now
        }
    }
    
    var visibleDays: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 180
        case .year: return 365
        }
    }
    
    var xAxisStride: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week: return .day
        case .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }
}
```

## Accessibility

```swift
.accessibilityLabel("Sleep quality chart")
.accessibilityValue("Shows sleep quality from \(startDate) to \(endDate)")
.accessibilityChartDescriptor(createChartDescriptor())

func createChartDescriptor() -> AXChartDescriptor {
    let xAxis = AXCategoricalDataAxisDescriptor(
        title: "Date",
        categoryOrder: dates.map { $0.formatted() }
    )
    
    let yAxis = AXNumericDataAxisDescriptor(
        title: "Quality Score",
        range: 0...100,
        gridlinePositions: []
    )
    
    let series = AXDataSeriesDescriptor(
        name: "Sleep Quality",
        isContinuous: true,
        dataPoints: dataPoints.map {
            AXDataPoint(x: $0.date.formatted(), y: $0.value)
        }
    )
    
    return AXChartDescriptor(
        title: "Sleep Quality Over Time",
        summary: nil,
        xAxis: xAxis,
        yAxis: yAxis,
        series: [series]
    )
}
```

## Color Schemes for Health Data

```swift
struct HealthColors {
    static let sleep = Color(red: 0.4, green: 0.5, blue: 0.9)
    static let deepSleep = Color(red: 0.2, green: 0.3, blue: 0.7)
    static let remSleep = Color(red: 0.6, green: 0.4, blue: 0.9)
    static let lightSleep = Color(red: 0.7, green: 0.8, blue: 1.0)
    
    static let heartRate = Color.red
    static let steps = Color.green
    static let calories = Color.orange
    
    static let good = Color.green
    static let moderate = Color.yellow
    static let poor = Color.red
}
```

## Common Pitfalls

1. **Too many data points**: Decimate data when showing long time periods
2. **Memory leaks**: Always use `@State` for scroll position and selection
3. **Performance**: Use `.drawingGroup()` for complex charts with many elements
4. **Date handling**: Always use `Calendar` for date calculations, never manual arithmetic
5. **Accessibility**: Always provide chart descriptors for VoiceOver users

## Useful Resources

- Official Documentation: https://developer.apple.com/documentation/charts
- WWDC 2022 Session: "Hello Swift Charts" (Session 10136)
- WWDC 2023 Session: "Explore pie charts and interactivity in Swift Charts" (Session 10037)
- Sample Code: https://developer.apple.com/documentation/charts/visualizing_your_app_s_data
