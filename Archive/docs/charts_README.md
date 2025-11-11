# WellPath Charts Documentation

Complete Swift Charts reference and implementation templates for WellPath health data visualizations.

## 📁 Contents

### 📖 Documentation
- **`charts_reference.md`** - Comprehensive Swift Charts API reference
  - All chart mark types (Line, Bar, Area, Point, Rectangle, Rule)
  - Customization options (axes, legends, scales, selection)
  - Performance optimization techniques
  - Accessibility guidelines
  - Common patterns and pitfalls

- **`implementation_guide.md`** - WellPath-specific implementation guide
  - Architecture and project structure
  - Infinite scroll implementation
  - Time period views (D/W/M/6M/Y)
  - Data aggregation strategies
  - API integration patterns
  - Testing strategies
  - Quick start checklist

### 💻 Example Templates

#### Sleep Analysis
- **`examples/SleepAnalysisChart.swift`** - Main sleep trends chart
  - Quality score trend line with area fill
  - Duration bars
  - Reference lines (8h target, average)
  - Infinite scroll with window-based loading
  - Time period toggles (D/W/M/6M/Y)
  - Interactive selection with detail card
  - Stage breakdown summary

- **`examples/SleepStagesTimelineChart.swift`** - Detailed night visualization
  - Floating bar chart (RectangleMark) for sleep stages
  - Interactive timeline with stage selection
  - Hypnogram alternative view
  - Stage duration breakdown
  - Per-period quality metrics

#### Biomarkers
- **`examples/BiomarkerComparisonChart.swift`** - Multi-metric comparison
  - Trend view (line chart with reference ranges)
  - Comparison view (normalized bar chart)
  - Distribution view (scatter plot with statistics)
  - Reference range visualization
  - Optimal range highlighting
  - Status indicators (Optimal/Normal/Low/High)
  - Latest values summary

## 🚀 Quick Start

### 1. Read the Reference
Start with `charts_reference.md` to understand Swift Charts fundamentals.

### 2. Choose Your Template
Pick the example that matches your use case:
- Sleep tracking → `SleepAnalysisChart.swift`
- Detailed night analysis → `SleepStagesTimelineChart.swift`
- Biomarker tracking → `BiomarkerComparisonChart.swift`

### 3. Integrate with Your API
Replace mock data generators with real API calls:

```swift
// In your ViewModel
private func fetchSleepData(for range: ClosedRange<Date>) async -> [DailySleepSummary] {
    // Replace this:
    return generateMockSummary(for: range)
    
    // With this:
    return try await WellPathAPI.fetchSleepData(
        startDate: range.lowerBound,
        endDate: range.upperBound
    )
}
```

### 4. Customize
- Update colors to match WellPath theme
- Adjust reference ranges for your biomarkers
- Configure time periods based on your data granularity
- Add your specific metrics and calculations

## 📊 Key Features Implemented

### ✅ Infinite Scroll
- Window-based data loading
- Smart buffering (loads ahead and behind)
- Prevents duplicate fetches
- Smooth scrolling performance

### ✅ Time Period Views
- Day (D) - Hourly granularity
- Week (W) - Daily points
- Month (M) - Daily points
- 6 Months (6M) - Weekly aggregation
- Year (Y) - Monthly aggregation

### ✅ Performance Optimized
- Data decimation for long periods
- Lazy loading strategy
- Efficient state management
- Drawing group for complex charts

### ✅ Interactive
- Tap/drag to select data points
- Detail cards on selection
- Reference line annotations
- Zoom via time period toggles

### ✅ Accessible
- VoiceOver support
- Chart descriptors
- Proper labels and values
- High contrast colors

## 🎨 Chart Types Available

### Trend Charts (Line/Area)
Perfect for: Sleep quality over time, biomarker trends, continuous metrics
- Smooth interpolation
- Area fills
- Multiple series comparison

### Bar Charts
Perfect for: Daily comparisons, category comparisons, normalized values
- Vertical or horizontal
- Grouped or stacked
- Annotations

### Floating Bars (Rectangle)
Perfect for: Time ranges, sleep stages, activity blocks
- Start/end times
- Category-based
- Interactive selection

### Scatter Plots (Point)
Perfect for: Distribution analysis, outlier detection, correlation
- Configurable symbols
- Size and color encoding
- Statistical overlays

### Reference Lines (Rule)
Perfect for: Targets, averages, thresholds
- Horizontal or vertical
- Dashed styling
- Annotations

## 🔧 Common Customizations

### Change Color Scheme
```swift
.chartForegroundStyleScale([
    "Deep Sleep": Color.blue,
    "REM": Color.purple,
    "Light": Color.cyan
])
```

### Adjust Loading Buffer
```swift
var loadBufferDays: Int {
    switch self {
    case .day: return 3      // Load ±3 days
    case .week: return 14    // Load ±2 weeks
    case .month: return 60   // Load ±2 months
    // etc.
    }
}
```

### Modify Time Formats
```swift
var xAxisFormat: Date.FormatStyle {
    switch self {
    case .day: return .dateTime.hour()
    case .week: return .dateTime.weekday(.abbreviated)
    // etc.
    }
}
```

## 📱 Platform Support

- iOS 16.0+ (Swift Charts introduced)
- iPadOS 16.0+
- macOS 13.0+ (Ventura)

## 🐛 Troubleshooting

### Chart not scrolling
- Ensure `.chartScrollableAxes(.horizontal)` is set
- Verify `scrollPosition` is bound with `$`
- Check that `chartXVisibleDomain` is configured

### Data not loading
- Verify API endpoints are correct
- Check date range calculations
- Ensure `@Published` properties update on MainActor
- Add print statements to trace loading flow

### Performance issues
- Reduce data points (use aggregation)
- Add `.drawingGroup()` modifier
- Check for memory leaks in data retention
- Profile with Instruments

### Selection not working
- Verify `.chartXSelection(value:)` is bound
- Check overlay gesture recognizer setup
- Ensure data conforms to `Identifiable`

## 📚 Additional Resources

### Apple Documentation
- [Swift Charts Overview](https://developer.apple.com/documentation/charts)
- [Creating a Chart](https://developer.apple.com/documentation/charts/creating-a-chart-using-swift-charts)
- [WWDC 2022: Hello Swift Charts](https://developer.apple.com/videos/play/wwdc2022/10136/)
- [WWDC 2023: Explore Pie Charts and Interactivity](https://developer.apple.com/videos/play/wwdc2023/10037/)

### Sample Projects
- [Apple Sample Code: Visualizing Your App's Data](https://developer.apple.com/documentation/charts/visualizing_your_app_s_data)
- [Food Truck: Building a SwiftUI Multiplatform App](https://developer.apple.com/documentation/swiftui/food_truck_building_a_swiftui_multiplatform_app)

## 💡 Tips for Success

1. **Start Simple** - Begin with basic line chart, add features incrementally
2. **Mock Data First** - Get UI working before connecting real API
3. **Test with Real Volumes** - Ensure performance with actual data sizes
4. **Accessibility Matters** - Add chart descriptors from the start
5. **Iterate on UX** - Get feedback on time periods and interaction patterns

## 🎯 Next Steps

1. ✅ Review `charts_reference.md` for API details
2. ✅ Copy example templates into your Xcode project
3. ✅ Replace mock data with API integration
4. ✅ Test infinite scroll with production data volumes
5. ✅ Customize colors and styling
6. ✅ Add accessibility features
7. ✅ Implement unit tests
8. ✅ Get user feedback and iterate

## 📝 Notes

- All examples include mock data generators for quick testing
- View models follow MVVM pattern with async/await
- State management uses `@StateObject` and `@Published`
- API integration points are clearly marked with `// TODO` comments
- Performance optimizations are included but can be tuned to your data

## 🤝 Contributing

This documentation is specific to WellPath. When adding new chart types:
1. Follow the existing patterns
2. Include infinite scroll support
3. Add time period views
4. Provide mock data
5. Document in this README

---

**Last Updated**: October 2025  
**Swift Charts Version**: iOS 16+  
**WellPath Version**: Current
