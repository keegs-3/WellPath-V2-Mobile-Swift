# Custom Views Roadmap

## Screen → View Mapping
Based on user priorities and database screens.

---

## ✅ Healthful Nutrition (7 screens)

| Priority | User Wants | Database Screen | Screen ID | Status |
|----------|------------|-----------------|-----------|--------|
| 1 | Protein | "Protein Intake" | `SCREEN_PROTEIN` | 🔨 Todo |
| 2 | Vegetables | "Vegetables" | Need ID | 🔨 Todo |
| 3 | Fruits | "Fruits" | Need ID | 🔨 Todo |
| 4 | Fiber & Whole Grains | "Fiber & Whole Grains" | Need ID | 🔨 Todo |
| 5 | Hydration | "Hydration" | Need ID | 🔨 Todo |
| 6 | Meals | "Meal Timing" | Need ID | 🔨 Todo |
| 7 | Nutrition Quality | "Nutrition Quality" | Need ID | 🔨 Todo |

**Note:**
- Nuts/Seeds - NOT in database (need to add?)
- Fats - NOT in database (need to add?)

---

## ✅ Movement + Exercise (6 screens)

| Priority | User Wants | Database Screen | Screen ID | Status |
|----------|------------|-----------------|-----------|--------|
| 1 | Steps | "Steps" | Need ID | 🔨 Todo |
| 2 | Cardio | "Cardio Activity" | Need ID | 🔨 Todo |
| 3 | Strength Training | "Strength Training" | Need ID | 🔨 Todo |
| 4 | HIIT | "HIIT" | Need ID | 🔨 Todo |
| 5 | Mobility | "Mobility" | Need ID | 🔨 Todo |
| 6 | Daily Activity | "Daily Activity" | Need ID | 🔨 Todo |

---

## ✅ Restorative Sleep (1 screen)

| Priority | User Wants | Database Screen | Screen ID | Status |
|----------|------------|-----------------|-----------|--------|
| 1 | Sleep Analysis | "Sleep Overview" | `SCREEN_SLEEP` | ✅ Done |

---

## ✅ Core Care (4 screens)

| Priority | User Wants | Database Screen | Screen ID | Status |
|----------|------------|-----------------|-----------|--------|
| 1 | Biometrics | "Biometrics" | Need ID | 🔨 Todo |
| 2 | Screenings | "Screening Compliance" | Need ID | 🔨 Todo |
| 3 | Substances | "Substance Tracking" | Need ID | 🔨 Todo |
| 4 | Skincare & Sun | "Skincare & Sun Protection" | Need ID | 🔨 Todo |

**Note:**
- Therapeutics - NOT in database (need to add?)

---

## 💡 Recommended: Cognitive Health (2 screens)

| Priority | Database Screen | Screen ID | Status |
|----------|-----------------|-----------|--------|
| 1 | "Cognitive Health" | Need ID | 🔨 Todo |
| 2 | "Light & Circadian" | Need ID | 🔨 Todo |

---

## 💡 Recommended: Stress Management (1 screen)

| Priority | Database Screen | Screen ID | Status |
|----------|-----------------|-----------|--------|
| 1 | "Mindfulness & Meditation" | Need ID | 🔨 Todo |

---

## 💡 Recommended: Connection + Purpose (1 screen)

| Priority | Database Screen | Screen ID | Status |
|----------|-----------------|-----------|--------|
| 1 | "Wellness & Connection" | Need ID | 🔨 Todo |

---

## Summary

**Total Custom Views Needed:** 22 screens

**Priority Order:**
1. ✅ Sleep Analysis (Done)
2. 🔨 Protein (Template for others)
3. 🔨 Steps (Template for movement metrics)
4. 🔨 Biometrics (Template for Core Care)
5. 🔨 Remaining 18 screens

---

## Implementation Plan

### Phase 1: Core Templates (Week 1)
- [x] Sleep Analysis (Done)
- [ ] Protein View (Nutrition template)
- [ ] Steps View (Movement template)
- [ ] Biometrics View (Core Care template)

### Phase 2: Nutrition Screens (Week 2)
- [ ] Vegetables
- [ ] Fruits
- [ ] Fiber & Whole Grains
- [ ] Hydration
- [ ] Meal Timing
- [ ] Nutrition Quality

### Phase 3: Movement Screens (Week 3)
- [ ] Cardio Activity
- [ ] Strength Training
- [ ] HIIT
- [ ] Mobility
- [ ] Daily Activity

### Phase 4: Core Care Screens (Week 4)
- [ ] Screenings
- [ ] Substances
- [ ] Skincare & Sun Protection

### Phase 5: Wellness Screens (Week 5)
- [ ] Cognitive Health
- [ ] Light & Circadian
- [ ] Mindfulness & Meditation
- [ ] Wellness & Connection

---

## View Template Pattern

Each custom view should follow this pattern:

```swift
struct [Metric]View: View {
    @StateObject private var viewModel = [Metric]ViewModel()
    @State private var selectedPeriod: TimePeriod = .weekly
    @State private var showingChildMetrics = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Summary Card
                [Metric]SummaryCard(...)

                // 2. Period Selector
                PeriodSelector(selectedPeriod: $selectedPeriod)

                // 3. Primary Chart
                [Metric]Chart(data: viewModel.data, period: selectedPeriod)

                // 4. Show More Button (if has child metrics)
                if viewModel.hasChildMetrics {
                    ShowMoreButton { showingChildMetrics = true }
                }

                // 5. About Section (optional)
                AboutSection(metric: viewModel.metric)
            }
        }
        .navigationTitle("[Metric Name]")
        .sheet(isPresented: $showingChildMetrics) {
            ChildMetricsSheet(...)
        }
    }
}
```

---

## Database Cleanup (Optional)

Consider removing these unused tables after migration:
- `display_screens_display_metrics` (junction table)
- `parent_detail_sections` (sections in code now)

Keep:
- `display_screens` (for screen metadata)
- `parent_display_metrics` (for metric definitions)
- `child_display_metrics` (for child metrics)

---

**Last Updated:** 2025-10-23
