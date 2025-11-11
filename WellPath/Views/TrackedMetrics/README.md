# TrackedMetrics Copy-Paste Guide

This guide explains how to add new metrics to the TrackedMetrics system using a simple copy-paste workflow.

## Architecture Overview

We use **TWO patterns** for metrics:

### Pattern A: Standard Metrics (RECOMMENDED)
Use the generic `ParentMetricBarChart` for simple bar charts showing values over time.

**Examples:** Protein Grams, Sleep Duration, Fiber, Steps, Water Intake

**Characteristics:**
- Single value tracked over time
- Standard D/W/M/6M/Y views
- No complex breakdowns
- Fast implementation (copy-paste ready)

### Pattern B: Custom Complex Metrics
Create custom chart components for specialized visualizations.

**Examples:** Protein Timing (stacked by meal), Protein Type (stacked by source), Sleep Hypnogram (timeline)

**Characteristics:**
- Multiple categories/breakdowns
- Custom data models
- Specialized interactions
- Requires custom ViewModels

---

## Adding a New Standard Metric

### Quick Checklist
1. ✅ Copy Primary view template
2. ✅ Copy ViewModel template
3. ✅ Register navigation route
4. ✅ Add database content
5. ✅ Done! (Chart + About works automatically)

---

### Step 1: Copy Primary View Template

**Example:** Adding Fiber metric

```bash
cd Views/TrackedMetrics/Nutrition
mkdir Fiber
cp Protein/ProteinPrimary.swift Fiber/FiberPrimary.swift
```

**Edit `FiberPrimary.swift` - Change these lines:**
```swift
// Line 11: struct name
struct FiberPrimary: View {

// Line 14: ViewModel init with your metric ID
@StateObject private var viewModel = FiberPrimaryViewModel(metricId: "DISP_FIBER_GRAMS")

// Line 56: Navigation title
.navigationTitle("Fiber")

// Line 101: Button text
Text("View More Fiber Data")

// Line 137/148/159: About section titles
Text("About Fiber")
```

---

### Step 2: Copy ViewModel Template

```bash
cd ViewModels/TrackedMetrics/Nutrition
mkdir Fiber
cp Protein/ProteinPrimaryViewModel.swift Fiber/FiberPrimaryViewModel.swift
```

**Edit `FiberPrimaryViewModel.swift` - Change class names and metric ID:**
```swift
// Line 13: Struct name
struct FiberPrimaryMetric: Identifiable {

// Line 32: Class name
class FiberPrimaryViewModel: ObservableObject {

// Line 44: Default metricId
init(metricId: String = "DISP_FIBER_GRAMS") {
```

---

### Step 3: Register Navigation Route

**File:** `TrackedMetricsListView.swift` (line 181)

**Add case:**
```swift
case "SCREEN_FIBER":
    FiberPrimary(pillar: pillar, color: MetricsUIConfig.getPillarColor(for: pillar))
```

---

### Step 4: Add Database Content

```sql
-- 1. Create display_screens entry
INSERT INTO display_screens (screen_id, name, overview, pillar, display_order, is_active)
VALUES ('SCREEN_FIBER', 'Dietary Fiber', 'Track daily fiber intake', 'Healthful Nutrition', 5, true);

-- 2. Create display_metrics entry with About content
INSERT INTO display_metrics (metric_id, metric_name, description, pillar, chart_type_id, about_content, longevity_impact, quick_tips, is_active)
VALUES (
    'DISP_FIBER_GRAMS',
    'Dietary Fiber',
    'Total fiber intake in grams',
    'Healthful Nutrition',
    'bar_vertical',
    'Dietary fiber is essential for digestive health...',
    'High fiber intake is associated with reduced risk...',
    '["Aim for 25-38g daily", "Mix soluble and insoluble fiber", "Increase intake gradually"]'::jsonb,
    true
);
```

---

### Step 5: Add to Xcode Project

1. Open Xcode
2. Right-click `Views/TrackedMetrics/Nutrition` → "Add Files to WellPath..."
3. Select the `Fiber` folder
4. Repeat for `ViewModels/TrackedMetrics/Nutrition/Fiber`

---

### Step 6: Build and Test

```bash
xcodebuild -scheme WellPath -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Test:**
- ✅ Navigation works
- ✅ Chart displays
- ✅ About tab shows content

---

## When to Create Custom Charts

Only when you need:
- **Stacked bars** (meal timing, protein types)
- **Multi-line comparisons** (animal vs plant)
- **Complex interactions** (sleep hypnogram timeline)

Reference files:
- `Views/Charts/MealTimingStackedChart.swift`
- `Views/Charts/ProteinTypeStackedChart.swift`

---

## Architecture Standards

### Naming
```
{Metric}PrimaryViewModel    // For Primary screens
{Metric}{Tab}ViewModel      // For Detail tabs
```

### Data Source
All ViewModels query `display_metrics` directly:
```swift
try await supabase.from("display_metrics")
    .select()
    .eq("metric_id", value: metricId)
```

### File Structure
```
Views/TrackedMetrics/{Pillar}/{Metric}/
  {Metric}Primary.swift
  {Metric}Detail.swift

ViewModels/TrackedMetrics/{Pillar}/{Metric}/
  {Metric}PrimaryViewModel.swift
```

---

## Complete Examples

- **Standard metric:** `Nutrition/Protein/ProteinPrimary.swift`
- **ViewModel:** `Nutrition/Protein/ProteinPrimaryViewModel.swift`
- **Custom chart:** `Sleep/SleepAnalysis/SleepAnalysisPrimary.swift`
