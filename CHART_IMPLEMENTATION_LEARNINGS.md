# Sleep Consistency Chart Implementation Learnings

This document captures key learnings from implementing the Sleep Consistency charts in WellPath, including technical insights, helpful resources, and communication patterns that led to success.

## Table of Contents
1. [Chart Scrolling & Data Loading](#chart-scrolling--data-loading)
2. [Edge Detection & Visible Domain](#edge-detection--visible-domain)
3. [X-Axis Behavior](#x-axis-behavior)
4. [Visual Design Iterations](#visual-design-iterations)
5. [Helpful Resources](#helpful-resources)
6. [Communication Patterns](#communication-patterns)
7. [Code Patterns & Best Practices](#code-patterns--best-practices)

---

## Chart Scrolling & Data Loading

### Key Learnings

**1. Scroll Position Initialization**
- Initialize scroll position to `Date()` (today) for natural UX
- Use `hasInitializedScroll` flag to prevent repeated initialization
- Reset scroll when switching between periods (W/M/6M/Y)

```swift
@State private var scrollPosition: Date
@State private var hasInitializedScroll = false

init(pillar: String, color: Color) {
    _scrollPosition = State(initialValue: Date())
}
```

**2. Data Loading Strategy**
- Load different data types based on period:
  - W view: 35 days of daily data (5 weeks)
  - M view: 33 days of daily data
  - 6M view: 26 weeks of weekly averages
  - Y view: 12 months of monthly averages
- Reset selections when switching periods to avoid stale state

**3. Scroll Behavior**
- Use `.chartScrollableAxes(.horizontal)` for horizontal scrolling
- Bind scroll position with `.chartScrollPosition(x: $scrollPosition)`
- Set visible domain with `.chartXVisibleDomain(length:)` for consistent view window

```swift
Chart { /* content */ }
    .chartScrollableAxes(.horizontal)
    .chartScrollPosition(x: $scrollPosition)
    .chartXVisibleDomain(length: visibleDomainLength)
```

---

## Edge Detection & Visible Domain

### The Purple Bar Problem

**Issue**: Bars outside the visible range turned purple instead of using the sleep pillar color.

**Root Cause**: `calculateVisibleAverages()` returned `nil` for bars outside the visible range, causing color functions to fall back to `barColor` (purple).

**Solution**: Change all color function fallbacks to use `color` (sleep pillar color) instead of `barColor`.

```swift
private func getDailyBarColor(for dayData: ChartDayData) -> Color {
    guard let averages = calculateVisibleAverages() else {
        // No averages available - use sleep pillar color (NOT barColor)
        if let date = selectedDate, Calendar.current.isDate(dayData.date, inSameDayAs: date) {
            return color.opacity(0.6)
        }
        return color
    }
    // ... rest of logic
}
```

**Key Insight**: Always consider what happens when data is at the edges of your visible domain. Edge cases are literal in chart implementations.

### Calculating Visible Averages

```swift
private func calculateVisibleAverages() -> (bedtime: Date, waketime: Date)? {
    let calendar = Calendar.current

    // Get visible range based on scroll position and domain length
    guard let visibleStart = calendar.date(byAdding: .second, value: -Int(visibleDomainLength / 2), to: scrollPosition),
          let visibleEnd = calendar.date(byAdding: .second, value: Int(visibleDomainLength / 2), to: scrollPosition) else {
        return nil
    }

    // Filter data within visible range
    let visibleData = dailyData.filter { dayData in
        dayData.date >= visibleStart && dayData.date <= visibleEnd
    }

    // Calculate averages from visible data
    // ...
}
```

---

## X-Axis Behavior

### Axis Scaling and Labels

**1. Time-Based Axes**
- Charts with time data automatically scale based on visible domain
- Use `.chartXAxis` to customize label formatting
- Consider time zones when working with dates

**2. Visible Domain Length**
- Controls how much data is visible at once
- Calculated differently per period:
  ```swift
  private var visibleDomainLength: TimeInterval {
      switch selectedPeriod {
      case .week:
          return 7 * 24 * 60 * 60  // 7 days
      case .month:
          return 14 * 24 * 60 * 60 // 14 days
      case .sixMonth:
          return 12 * 7 * 24 * 60 * 60 // 12 weeks
      case .year:
          return 6 * 30 * 24 * 60 * 60 // ~6 months
      }
  }
  ```

**3. Chart Selection Behavior**
- Use `.chartAngleSelection()` or `.chartXSelection()` for bar selection
- Store selected date/week/month in state
- Reset selections when switching views

---

## Visual Design Iterations

### Iteration 1: Gradient-Filled Bands (❌ "Hideous")

**Approach**: Multiple colored bands with gradients (red ±60min, yellow ±60min, green ±30min)

**Why It Failed**:
- Too visually busy
- Colors were harsh (mustard yellow, bright red)
- Overwhelmed the actual data

### Iteration 2: Simplified Dotted Lines (✅ Success)

**Approach**: Clean dotted horizontal lines with subtle shading

```swift
// Dotted line style
let dottedStyle = StrokeStyle(lineWidth: 1.5, dash: [2, 4])

// Green dotted lines at ±30 minutes
RuleMark(y: .value("Lower 30", minus30))
    .foregroundStyle(color.opacity(0.7))
    .lineStyle(dottedStyle)

// Subtle shaded area between lines
RectangleMark(yStart: .value("Lower", minus30), yEnd: .value("Upper", plus30))
    .foregroundStyle(color.opacity(0.08))
```

**Key Principles**:
- **Simplicity**: Fewer visual elements, cleaner appearance
- **Subtlety**: Low opacity (8% for fill, 70% for lines)
- **Consistency**: Use pillar color throughout for coherence
- **Purpose**: Visual elements support data, don't compete with it

### Color Psychology

**Consistent Bars** (within ±30 min on both bedtime & waketime):
- Use full pillar color
- Conveys "good" / "on target"

**Inconsistent Bars** (outside range):
- Use `color.opacity(0.4)` instead of grey
- Stays within color palette
- Subtle visual de-emphasis
- User feedback: "love that" (vs. "i don't love this grey")

---

## Helpful Resources

### Apple Documentation

**Most Valuable Tools Used**:

1. **`mcp__apple-docs__search_apple_docs`**
   - Quick searches for specific APIs
   - Example: Searched "LinearGradient" to explore gradient options
   - Example: Searched "StrokeStyle" to find line styling options

2. **`mcp__apple-docs__get_apple_doc_content`**
   - Deep dives into specific documentation pages
   - Helped understand `RuleMark`, `RectangleMark`, `BarMark` capabilities

3. **Swift Charts Framework Documentation**
   - Core marks: `BarMark`, `RuleMark`, `RectangleMark`
   - Chart modifiers: `.chartScrollableAxes()`, `.chartXVisibleDomain()`
   - Selection: `.chartAngleSelection()`, `.chartXSelection()`

### Code Examples

**SleepChartKit Package**:
- Local package at `/Users/keegs/Documents/WellPath/SleepChartKit-main`
- Provided real-world examples of chart implementation
- Demonstrated data structure patterns

**SleepAnalysisPrimary.swift**:
- Existing implementation in the codebase
- Used as reference for consistent color scheme (`barColor`)
- Showed established patterns for view model integration

---

## Communication Patterns

### What Worked Well ✅

**1. Direct, Honest Feedback**
- "ok yeah that worked! its hideous...but it worked!"
  - Immediate, clear signal that approach was wrong
  - Positive reinforcement that it technically worked
  - Direct guidance on what to change

- "i don't love this grey"
  - Specific element called out
  - Opened door for alternative exploration

- "love that"
  - Clear success signal
  - Confirmed we were on the right track

**2. Visual Language**
- "make the bars green if they fall in the green area"
  - Concrete, visual description
  - Easy to translate to code logic

- "almost just a stroke on the top and bottom"
  - Specific visual goal
  - Led directly to `RuleMark` with `StrokeStyle`

**3. Incremental Requests**
- Start with one change, then refine
- Example progression:
  1. "remove the red part"
  2. "make the yellow less mustardy"
  3. "can we add a gradient?"
  4. "how about just lines?"
  5. "we lost the color in between our lines"

**4. Apple-Centric Direction**
- "make it more apple-ish"
  - Clear design philosophy target
  - Encouraged looking at Apple docs for patterns

- "is there a better way in apple docs"
  - Prompted research into official solutions
  - Led to better implementations

**5. Specific Edge Cases**
- "when a bar is selected in W or M view, it should just show Bedtime and Waketime, not Avg"
  - Precise scenario description
  - Clear expected behavior
  - Easy to implement conditional logic

- "when we get to an edge and the bar is still visible but not in the range, it turns purple"
  - Exact reproduction case
  - Clear bug description
  - Led directly to root cause

### What Was Less Helpful ⚠️

**1. Vague Requests** (though we didn't encounter many)
- Hypothetical: "make it look better"
  - Too subjective
  - No clear success criteria

**Better Alternative**: "i don't love this grey - what else could we do?"
- Identifies specific problem
- Opens exploration
- Allows for suggestions

**2. Multiple Changes At Once** (we avoided this)
- Could lead to confusion about what worked/didn't work
- Incremental approach was much clearer

---

## Code Patterns & Best Practices

### 1. Conditional Rendering Based on Data State

```swift
if viewModel.isLoading {
    ProgressView()
} else if let error = viewModel.error {
    ErrorView(error)
} else {
    ContentView()
}
```

**Why**: Clear user feedback for all states

### 2. Optional Unwrapping with Fallback

```swift
guard let averages = calculateVisibleAverages() else {
    // Fallback behavior for edge cases
    return color  // Use sensible default
}
```

**Why**: Graceful handling of edge cases (literally!)

### 3. Contextual UI Elements

```swift
Text(getSelectedData() != nil ? "Bedtime" : "Avg Bedtime")
```

**Why**: UI adapts to current context, provides accurate information

### 4. Color Opacity for Hierarchy

```swift
// Primary color
.foregroundStyle(color)

// De-emphasized
.foregroundStyle(color.opacity(0.4))

// Selected/highlighted
.foregroundStyle(color.opacity(0.6))

// Subtle background
.foregroundStyle(color.opacity(0.08))
```

**Why**: Maintains visual coherence while establishing hierarchy

### 5. Separation of Concerns

```swift
// Helper methods for different chart elements
@ChartContentBuilder
private func referenceBand(for avgTime: Date, type: BandType) -> some ChartContent { }

private func getDailyBarColor(for dayData: ChartDayData) -> Color { }

private func calculateVisibleAverages() -> (bedtime: Date, waketime: Date)? { }
```

**Why**: Readable, maintainable, testable code

### 6. State Management

```swift
// Reset related state together
.onChange(of: selectedPeriod) { oldValue, newValue in
    selectedDate = nil
    selectedWeek = nil
    selectedMonth = nil
    hasInitializedScroll = false
    // ... load new data
}
```

**Why**: Prevents stale state bugs

### 7. Markdown Rendering

```swift
// Parse markdown with fallback
if let attributedText = try? AttributedString(markdown: text) {
    Text(attributedText)
} else {
    Text(text)  // Fallback to plain text
}
```

**Why**: Graceful degradation if markdown parsing fails

---

## Key Takeaways

1. **Edge cases in charts are literal** - Always test behavior at the boundaries of your visible domain

2. **Simplicity wins** - Clean dotted lines beat complex gradient-filled bands

3. **Stay in the color palette** - Using `color.opacity(0.4)` > introducing new colors like grey

4. **Direct feedback accelerates development** - "hideous" saved hours of polishing the wrong approach

5. **Incremental iteration works** - Small changes with frequent feedback > big redesigns

6. **Apple docs are essential** - Reference official documentation for SwiftUI/Swift Charts patterns

7. **Context matters** - Labels, colors, and behavior should adapt to current state

8. **Build frequently** - Catch issues early with regular builds

9. **State management is critical** - Reset related state together to avoid bugs

10. **Plan for all data states** - Loading, error, empty, edge cases, normal - handle them all

---

## Future Considerations

### Performance Optimization
- Consider data virtualization for very large datasets
- Monitor memory usage with extensive scroll ranges
- Test with maximum data scenarios

### Accessibility
- Ensure color contrast meets WCAG standards
- Add VoiceOver descriptions for charts
- Consider reduced motion preferences

### Error Handling
- More granular error states
- Retry mechanisms for data loading
- User-friendly error messages

### Testing
- Unit tests for date calculations
- UI tests for scroll behavior
- Edge case test scenarios
- Visual regression tests

---

**Document Created**: 2025-11-19
**Project**: WellPath V2 Mobile (Swift)
**Component**: Sleep Consistency Charts
**Key File**: `WellPath/Views/TrackedMetrics/Sleep/SleepConsistency/SleepConsistencyPrimary.swift`
