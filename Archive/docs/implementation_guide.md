# WellPath Charts Implementation Guide

## Architecture Overview

### Chart Component Structure

```
WellPath/
├── Charts/
│   ├── Core/
│   │   ├── ChartModels.swift           # Shared data models
│   │   ├── ChartTheme.swift            # Colors, fonts, spacing
│   │   ├── ChartFormatters.swift       # Date/number formatters
│   │   └── ChartHelpers.swift          # Utility functions
│   ├── Sleep/
│   │   ├── SleepAnalysisChart.swift    # Main sleep trends
│   │   ├── SleepStagesChart.swift      # Floating bar timeline
│   │   └── SleepHypnogramChart.swift   # Hypnogram view
│   ├── Biomarkers/
│   │   ├── BiomarkerComparisonChart.swift
│   │   ├── BiomarkerRangeChart.swift
│   │   └── BiomarkerDistributionChart.swift
│   ├── Activity/
│   │   ├── StepsChart.swift
│   │   ├── HeartRateChart.swift
│   │   └── CaloriesChart.swift
│   └── ViewModels/
│       ├── ChartViewModel.swift        # Base class
│       ├── SleepChartViewModel.swift
│       └── BiomarkerChartViewModel.swift
```

## Infinite Scroll Implementation

### Strategy

1. **Window-based loading**: Load data in chunks based on visible date range
2. **Buffer zones**: Pre-load data ahead/behind scroll position
3. **Pagination**: Track loaded ranges to avoid duplicate fetches
4. **Efficient updates**: Use `@Published` with `@MainActor` for UI updates

### Implementation Pattern

```swift
class InfiniteScrollChartViewModel: ObservableObject {
    @Published var data: [DataPoint] = []
    @Published var isLoading = false
    
    private var loadedRange: ClosedRange<Date>?
    private var isLoadingMore = false
    
    func handleScroll(to position: Date?, visibleDomain: TimeInterval) {
        guard let position = position,
              let loaded = loadedRange,
              !isLoadingMore else { return }
        
        let bufferZone = visibleDomain * 0.5 // 50% buffer
        
        // Load past data
        if position.timeIntervalSince(loaded.lowerBound) < bufferZone {
            loadMore(direction: .past)
        }
        
        // Load future data
        if loaded.upperBound.timeIntervalSince(position) < bufferZone {
            loadMore(direction: .future)
        }
    }
    
    private func loadMore(direction: ScrollDirection) {
        isLoadingMore = true
        
        Task {
            let newData = await fetchData(for: calculateRange(direction))
            await MainActor.run {
                switch direction {
                case .past:
                    self.data.insert(contentsOf: newData, at: 0)
                case .future:
                    self.data.append(contentsOf: newData)
                }
                updateLoadedRange(newData)
                isLoadingMore = false
            }
        }
    }
}
```

## Time Period Views (D/W/M/6M/Y)

### Unified Period Handler

```swift
enum TimePeriod: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"
    
    var config: PeriodConfig {
        switch self {
        case .day:
            return PeriodConfig(
                visibleDays: 1,
                loadBufferDays: 3,
                xAxisStride: .hour,
                xAxisFormat: .dateTime.hour(),
                pointsToShow: 24,
                aggregation: .none
            )
        case .week:
            return PeriodConfig(
                visibleDays: 7,
                loadBufferDays: 14,
                xAxisStride: .day,
                xAxisFormat: .dateTime.weekday(.abbreviated),
                pointsToShow: 168,
                aggregation: .hourly
            )
        case .month:
            return PeriodConfig(
                visibleDays: 30,
                loadBufferDays: 30,
                xAxisStride: .day,
                xAxisFormat: .dateTime.day(),
                pointsToShow: 720,
                aggregation: .daily
            )
        case .sixMonths:
            return PeriodConfig(
                visibleDays: 180,
                loadBufferDays: 90,
                xAxisStride: .weekOfYear,
                xAxisFormat: .dateTime.month(.abbreviated).day(),
                pointsToShow: 180,
                aggregation: .daily
            )
        case .year:
            return PeriodConfig(
                visibleDays: 365,
                loadBufferDays: 180,
                xAxisStride: .month,
                xAxisFormat: .dateTime.month(.abbreviated),
                pointsToShow: 365,
                aggregation: .weekly
            )
        }
    }
}

struct PeriodConfig {
    let visibleDays: Int
    let loadBufferDays: Int
    let xAxisStride: Calendar.Component
    let xAxisFormat: Date.FormatStyle
    let pointsToShow: Int
    let aggregation: DataAggregation
}

enum DataAggregation {
    case none, hourly, daily, weekly
}
```

## Data Aggregation for Performance

### Smart Decimation

```swift
class DataAggregator {
    static func aggregate(_ data: [DataPoint], method: DataAggregation) -> [DataPoint] {
        switch method {
        case .none:
            return data
        case .hourly:
            return aggregateByHour(data)
        case .daily:
            return aggregateByDay(data)
        case .weekly:
            return aggregateByWeek(data)
        }
    }
    
    private static func aggregateByDay(_ data: [DataPoint]) -> [DataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: data) { point in
            calendar.startOfDay(for: point.date)
        }
        
        return grouped.map { date, points in
            DataPoint(
                date: date,
                value: points.map(\.value).reduce(0, +) / Double(points.count),
                metadata: AggregatedMetadata(
                    count: points.count,
                    min: points.map(\.value).min() ?? 0,
                    max: points.map(\.value).max() ?? 0
                )
            )
        }.sorted { $0.date < $1.date }
    }
}
```

## Loading States & Error Handling

### Proper State Management

```swift
enum ChartLoadingState {
    case idle
    case loading
    case loaded([DataPoint])
    case error(Error)
    case loadingMore(existing: [DataPoint])
}

class ChartViewModel: ObservableObject {
    @Published var state: ChartLoadingState = .idle
    
    func loadData() async {
        state = .loading
        
        do {
            let data = try await dataService.fetchData()
            state = .loaded(data)
        } catch {
            state = .error(error)
        }
    }
    
    func loadMore() async {
        guard case .loaded(let existing) = state else { return }
        state = .loadingMore(existing: existing)
        
        do {
            let moreData = try await dataService.fetchMoreData()
            state = .loaded(existing + moreData)
        } catch {
            state = .error(error)
        }
    }
}
```

### Loading UI

```swift
@ViewBuilder
func chartWithLoadingState(_ state: ChartLoadingState) -> some View {
    switch state {
    case .idle:
        Color.clear
    case .loading:
        ProgressView()
    case .loaded(let data):
        actualChart(data: data)
    case .error(let error):
        errorView(error)
    case .loadingMore(let existing):
        ZStack {
            actualChart(data: existing)
            VStack {
                Spacer()
                ProgressView()
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
            }
        }
    }
}
```

## Performance Optimization

### Best Practices

1. **Limit data points**: Show max 500-1000 points at once
2. **Use `.drawingGroup()`**: For complex charts with many marks
3. **Lazy loading**: Only load visible data
4. **Debounce scroll**: Don't trigger loads on every scroll event
5. **Cache processed data**: Store aggregated results

### Example Optimization

```swift
var optimizedChart: some View {
    Chart {
        ForEach(displayData) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
        }
    }
    .drawingGroup() // Render as single image
}

var displayData: [DataPoint] {
    let maxPoints = 1000
    if fullData.count <= maxPoints {
        return fullData
    }
    
    // Decimate data
    let stride = fullData.count / maxPoints
    return fullData.enumerated()
        .filter { $0.offset % stride == 0 }
        .map { $0.element }
}
```

## API Integration Pattern

### Service Layer

```swift
protocol ChartDataService {
    func fetchData(startDate: Date, endDate: Date) async throws -> [DataPoint]
    func fetchSleepData(startDate: Date, endDate: Date) async throws -> [SleepPeriod]
    func fetchBiomarkers(startDate: Date, endDate: Date) async throws -> [BiomarkerReading]
}

class WellPathChartDataService: ChartDataService {
    private let apiClient: APIClient
    
    func fetchData(startDate: Date, endDate: Date) async throws -> [DataPoint] {
        let endpoint = "/api/health/data"
        let params = [
            "start": ISO8601DateFormatter().string(from: startDate),
            "end": ISO8601DateFormatter().string(from: endDate)
        ]
        
        let response: DataResponse = try await apiClient.request(
            endpoint: endpoint,
            method: .get,
            parameters: params
        )
        
        return response.data.map { DataPoint(from: $0) }
    }
}
```

## Accessibility

### VoiceOver Support

```swift
extension Chart {
    func makeAccessible(
        title: String,
        summary: String,
        dataPoints: [DataPoint]
    ) -> some View {
        self
            .accessibilityLabel(title)
            .accessibilityValue(summary)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityChartDescriptor(
                createDescriptor(
                    title: title,
                    dataPoints: dataPoints
                )
            )
    }
}

func createDescriptor(
    title: String,
    dataPoints: [DataPoint]
) -> AXChartDescriptor {
    let xAxis = AXCategoricalDataAxisDescriptor(
        title: "Date",
        categoryOrder: dataPoints.map { 
            $0.date.formatted(date: .abbreviated, time: .omitted) 
        }
    )
    
    let min = dataPoints.map(\.value).min() ?? 0
    let max = dataPoints.map(\.value).max() ?? 100
    
    let yAxis = AXNumericDataAxisDescriptor(
        title: "Value",
        range: Double(min)...Double(max),
        gridlinePositions: []
    )
    
    let series = AXDataSeriesDescriptor(
        name: title,
        isContinuous: true,
        dataPoints: dataPoints.map { point in
            AXDataPoint(
                x: point.date.formatted(date: .abbreviated, time: .omitted),
                y: Double(point.value)
            )
        }
    )
    
    return AXChartDescriptor(
        title: title,
        summary: nil,
        xAxis: xAxis,
        yAxis: yAxis,
        series: [series]
    )
}
```

## Testing Strategy

### Unit Tests

```swift
class ChartViewModelTests: XCTestCase {
    func testInfiniteScrollLoading() async throws {
        let viewModel = SleepChartViewModel()
        let mockService = MockChartDataService()
        viewModel.dataService = mockService
        
        // Initial load
        await viewModel.loadInitialData(for: .week)
        XCTAssertEqual(viewModel.sleepData.count, 7)
        
        // Scroll to trigger load
        let scrollPosition = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Date()
        )!
        await viewModel.handleScroll(to: scrollPosition, period: .week)
        
        XCTAssertGreaterThan(viewModel.sleepData.count, 7)
    }
}
```

### Preview Mock Data

```swift
extension View {
    func withMockChartData() -> some View {
        self.environmentObject(MockChartViewModel())
    }
}

#Preview {
    SleepAnalysisChart()
        .withMockChartData()
}
```

## Common Pitfalls to Avoid

1. **Don't load all historical data at once**
   - Always use window-based loading
   - Implement proper pagination

2. **Don't forget to decimate data for long periods**
   - Year view should not show 365 × 24 hourly data points
   - Aggregate appropriately

3. **Don't block main thread**
   - All data fetching must be async
   - Use `@MainActor` for UI updates

4. **Don't ignore memory management**
   - Release old data outside visible window
   - Implement LRU cache if needed

5. **Don't hardcode date formatting**
   - Use `TimePeriod.xAxisFormat`
   - Respect user locale settings

## Color Schemes

```swift
struct WellPathChartColors {
    // Sleep
    static let deepSleep = Color(red: 0.2, green: 0.3, blue: 0.7)
    static let remSleep = Color(red: 0.6, green: 0.4, blue: 0.9)
    static let lightSleep = Color(red: 0.7, green: 0.8, blue: 1.0)
    static let awake = Color.red.opacity(0.3)
    
    // Biomarkers
    static let optimal = Color.green
    static let normal = Color.blue
    static let warning = Color.orange
    static let critical = Color.red
    
    // Activity
    static let steps = Color.green
    static let heartRate = Color.red
    static let calories = Color.orange
    static let exercise = Color.purple
    
    // Chart elements
    static let gridLine = Color.gray.opacity(0.2)
    static let referenceRange = Color.blue.opacity(0.1)
    static let selectionIndicator = Color.gray.opacity(0.3)
}
```

## Quick Start Checklist

- [ ] Copy models and view models to your project
- [ ] Set up data service layer with proper API endpoints
- [ ] Implement infinite scroll in your main charts
- [ ] Add time period toggles (D/W/M/6M/Y)
- [ ] Configure proper data aggregation for each period
- [ ] Add loading states and error handling
- [ ] Implement accessibility features
- [ ] Test scroll performance with real data
- [ ] Add unit tests for view models
- [ ] Configure proper colors matching WellPath theme

## Next Steps

1. Start with `SleepAnalysisChart.swift` as your template
2. Replace mock data with real API calls
3. Test infinite scroll with large datasets
4. Optimize rendering for your specific data volumes
5. Add any custom biomarker-specific charts
