# Custom Views Implementation Guide

## ✅ Architecture Complete!

We've successfully refactored WellPath to use custom views instead of the complex database-driven generic view. Here's how it works and how to extend it.

---

## 📐 How It Works

### Database Structure

1. **display_screens** - The navigation targets (what users tap on)
   - `screen_id`: e.g., "SCREEN_PROTEIN"
   - `name`: e.g., "Protein Intake"
   - `pillar`: FK to pillar (e.g., "Healthful Nutrition")

2. **display_metrics** - The charts/visualizations shown ON screens
   - `display_metric_id`: Unique metric ID
   - `display_screen_id`: FK to display_screens
   - `display_name`: e.g., "Daily Protein"
   - `chart_type_id`: e.g., "bar_vertical", "sleep_stages_horizontal"
   - `is_primary`: Boolean - is this the primary chart?
   - `is_active`: Boolean - is this metric active?

### Swift Architecture

```
TrackedMetricsListView
  ├─> screenDestination(for: DisplayScreen)
  │     └─> Routes to custom views based on screen_id
  │
  ├─> ProteinView (template)
  │     └─> BaseMetricViewModel(screenId: "SCREEN_PROTEIN")
  │           └─> Queries display_metrics table
  │                 └─> Finds primary & child metrics
  │                       └─> ChartTypeFactory renders chart
  │
  └─> Sleep DetailView (existing custom view)
```

---

## 🎯 What's Complete

### ✅ Core Infrastructure
- [x] Updated `DisplayMetric` model with new FK structure
- [x] Created `BaseMetricViewModel` for querying metrics
- [x] Created `ChartTypeFactory` for dynamic chart rendering
- [x] Created shared UI components in `MetricViewComponents.swift`
- [x] Updated navigation routing in `TrackedMetricsListView`

### ✅ Template Views
- [x] `SleepDetailView` - Fully custom with SleepChartKit
- [x] `ProteinView` - Template demonstrating the pattern

### ✅ 45 Screens Mapped
All screen_ids are mapped in routing (see `TrackedMetricsListView.swift:164-210`)

---

## 🚀 Creating a New Custom View

Follow this pattern to create views for the remaining screens:

### Step 1: Create the View File

```swift
// WellPath/Views/[Pillar]/[Name]View.swift
import SwiftUI

struct [Name]View: View {
    @StateObject private var viewModel = BaseMetricViewModel(screenId: "SCREEN_[ID]")
    @State private var showingChildMetrics = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                MetricErrorView(error: error) {
                    Task { await viewModel.loadMetrics() }
                }
            } else if let primary = viewModel.primaryMetric {
                ScrollView {
                    VStack(spacing: 24) {
                        // Primary metric chart
                        ChartTypeFactory.createChart(for: primary, color: .[COLOR])

                        // Show More button if there are child metrics
                        if !viewModel.childMetrics.isEmpty {
                            ShowMoreButton(count: viewModel.childMetrics.count) {
                                showingChildMetrics = true
                            }
                        }

                        // About section if available
                        if primary.aboutWhat != nil || primary.aboutWhy != nil {
                            MetricAboutSection(metric: primary)
                        }
                    }
                    .padding()
                }
            } else {
                EmptyMetricsView()
            }
        }
        .navigationTitle("[Metric Name]")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingChildMetrics) {
            MetricChildSheet(
                metrics: viewModel.childMetrics,
                parentName: viewModel.primaryMetric?.displayName ?? "[Name]",
                color: .[COLOR]
            )
        }
        .task {
            await viewModel.loadMetrics()
        }
    }
}

#Preview {
    NavigationView {
        [Name]View()
    }
}
```

### Step 2: Add to Routing

Edit `TrackedMetricsListView.swift`, add to the switch statement:

```swift
case "SCREEN_[ID]":
    [Name]View()
```

### Step 3: Regenerate & Build

```bash
xcodegen generate
xcodebuild -project WellPath.xcodeproj -scheme WellPath build
```

---

## 📋 Views to Create (Priority Order)

### High Priority Nutrition (7 views)
- [ ] `VegetablesView` → `SCREEN_VEGETABLES` (green)
- [ ] `FruitsView` → `SCREEN_FRUITS` (red)
- [ ] `FiberWholeGrainsView` → `SCREEN_FIBER` or `SCREEN_WHOLE_GRAINS` (brown)
- [ ] `HydrationView` → `SCREEN_HYDRATION` (blue)
- [ ] `MealTimingView` → `SCREEN_MEAL_TIMING` (orange)
- [ ] `NutritionQualityView` → `SCREEN_NUTRITION_QUALITY` (purple)

### High Priority Movement (6 views)
- [ ] `StepsView` → `SCREEN_STEPS` (cyan)
- [ ] `CardioView` → `SCREEN_CARDIO` (red)
- [ ] `StrengthTrainingView` → `SCREEN_STRENGTH` (blue)
- [ ] `HIITView` → `SCREEN_HIIT` (orange)
- [ ] `MobilityView` → `SCREEN_MOBILITY` (green)
- [ ] `DailyActivityView` → `SCREEN_ACTIVITY` (purple)

### High Priority Core Care (4 views)
- [ ] `BiometricsView` → `SCREEN_BIOMETRICS` (red)
- [ ] `ScreeningsView` → `SCREEN_COMPLIANCE` (blue)
- [ ] `SubstancesView` → `SCREEN_SUBSTANCES` (orange)
- [ ] `SkincareView` → `SCREEN_SKINCARE` (yellow)

### Recommended Wellness (6 views)
- [ ] `CognitiveHealthView` → `SCREEN_COGNITIVE` (purple)
- [ ] `LightCircadianView` → `SCREEN_LIGHT_EXPOSURE` (yellow)
- [ ] `MindfulnessView` → `SCREEN_MINDFULNESS` or `SCREEN_MEDITATION` (blue)
- [ ] `WellnessConnectionView` → `SCREEN_WELLNESS` (green)
- [ ] `SocialConnectionView` → `SCREEN_SOCIAL` (cyan)
- [ ] `GratitudeView` → `SCREEN_GRATITUDE` (pink)

---

## 🎨 Recommended Colors by Pillar

| Pillar | Color |
|--------|-------|
| Healthful Nutrition | `.green` |
| Movement + Exercise | `.red` / `.orange` |
| Restorative Sleep | `.purple` / `.indigo` |
| Core Care | `.blue` |
| Cognitive Health | `.yellow` / `.orange` |
| Stress Management | `.mint` / `.cyan` |
| Connection + Purpose | `.pink` / `.green` |

Use `MetricsUIConfig.getPillarColor(for: pillar)` to get the pillar color dynamically.

---

## 🧩 Reusable Components

All these are in `MetricViewComponents.swift`:

- `ShowMoreButton` - Expand to show child metrics
- `MetricAboutSection` - "About this metric" card
- `MetricAboutItem` - Individual about item
- `MetricErrorView` - Error state with retry
- `EmptyMetricsView` - Empty state placeholder
- `MetricChildSheet` - Modal sheet for child metrics

---

## 📊 Chart Types

`ChartTypeFactory` currently supports:

| chart_type_id | Component |
|---------------|-----------|
| `sleep_stages_horizontal` | SleepAnalysisChart (SleepChartKit) |
| `bar_vertical` | ParentMetricBarChart |
| `bar_horizontal` | ParentMetricBarChart |
| `bar_stacked` | ParentMetricBarChart |
| Other types | ParentMetricBarChart (fallback) |

To add new chart types, update `ChartTypeFactory.swift`.

---

## 🗄️ Database Checklist

For each screen to work, ensure:

1. **Screen exists** in `display_screens`:
   - `screen_id` matches routing case
   - `is_active = true`
   - `pillar` is set correctly

2. **At least one metric** in `display_metrics`:
   - `display_screen_id` matches the screen
   - `is_primary = true` (marks primary chart)
   - `is_active = true`
   - `chart_type_id` is set
   - `display_name` is user-friendly

3. **Optional child metrics**:
   - `parent_metric_id` references the primary
   - `is_primary = false`
   - `is_active = true`

---

## 🧪 Testing a New View

1. Create the view file
2. Add to routing
3. Build (`xcodebuild build`)
4. Navigate: Dashboard → Tracked Metrics → [Pillar] → [Screen]
5. Verify:
   - ✅ Loading state appears
   - ✅ Primary chart renders (or empty state if no metrics)
   - ✅ "Show More" button appears if child metrics exist
   - ✅ About section displays if populated

---

## 📝 Example: Creating VegetablesView

### 1. Create the file

```swift
// WellPath/Views/Nutrition/VegetablesView.swift
import SwiftUI

struct VegetablesView: View {
    @StateObject private var viewModel = BaseMetricViewModel(screenId: "SCREEN_VEGETABLES")
    @State private var showingChildMetrics = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                MetricErrorView(error: error) {
                    Task { await viewModel.loadMetrics() }
                }
            } else if let primary = viewModel.primaryMetric {
                ScrollView {
                    VStack(spacing: 24) {
                        ChartTypeFactory.createChart(for: primary, color: .green)

                        if !viewModel.childMetrics.isEmpty {
                            ShowMoreButton(count: viewModel.childMetrics.count) {
                                showingChildMetrics = true
                            }
                        }

                        if primary.aboutWhat != nil || primary.aboutWhy != nil {
                            MetricAboutSection(metric: primary)
                        }
                    }
                    .padding()
                }
            } else {
                EmptyMetricsView()
            }
        }
        .navigationTitle("Vegetables")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingChildMetrics) {
            MetricChildSheet(
                metrics: viewModel.childMetrics,
                parentName: viewModel.primaryMetric?.displayName ?? "Vegetables",
                color: .green
            )
        }
        .task {
            await viewModel.loadMetrics()
        }
    }
}

#Preview {
    NavigationView {
        VegetablesView()
    }
}
```

### 2. Add to routing

In `TrackedMetricsListView.swift`:

```swift
case "SCREEN_VEGETABLES":
    VegetablesView()
```

### 3. Build & Test

```bash
xcodegen generate
xcodebuild -project WellPath.xcodeproj -scheme WellPath build
```

---

## 🎉 Benefits of This Architecture

✅ **Simple** - Each view is just ~60 lines of clean Swift
✅ **Maintainable** - Easy to find and edit specific screens
✅ **Flexible** - Custom layout per screen, not generic
✅ **Data-Driven** - Still queries database for metrics
✅ **Fast to Iterate** - No complex database migrations
✅ **Parent/Child Support** - "Show More" reveals child metrics
✅ **Chart Flexibility** - ChartTypeFactory allows any chart type

---

## 📞 Questions?

Check the template files:
- `ProteinView.swift` - Complete example
- `BaseMetricViewModel.swift` - How metrics are loaded
- `MetricViewComponents.swift` - Reusable UI pieces
- `ChartTypeFactory.swift` - Chart type mapping

---

**Last Updated:** 2025-10-23
**Status:** ✅ Ready for implementation
**Next:** Populate `display_metrics` table and create remaining views
