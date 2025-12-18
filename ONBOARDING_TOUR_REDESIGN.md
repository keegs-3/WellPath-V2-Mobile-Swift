# Health Profile → Onboarding Tour Redesign

## Overview

Replacing the 348-question survey grind with an **onboarding tour** that walks users through WellPath Data screens while collecting baseline information.

**Key Insight:** Survey questions map directly to metric screens. Instead of asking "How much protein do you eat?" in a survey, ask it while showing the Protein tracking screen.

---

## The Numbers

| Section | Total | Scored | Unscored |
|---------|-------|--------|----------|
| introduction | 6 | 0 | 6 |
| cognitive_health | 12 | 4 | 8 |
| connection_purpose | 10 | 5 | 5 |
| core_care | 174 | 88 | 86 |
| healthful_nutrition | 68 | 21 | 47 |
| movement_exercise | 30 | 9 | 21 |
| restorative_sleep | 32 | 16 | 16 |
| stress_management | 16 | 3 | 13 |
| **TOTAL** | **348** | **146** | **202** |

- **146 scored questions** = Required for WellPath Score calculation
- **202 optional questions** = "Improve our algorithms" - shown but skippable

---

## Architecture

### 1. Onboarding Tour (Integrated with Metric Screens)

Most questions get asked while viewing their respective tracking screen:

```
┌─────────────────────────────────────┐
│ 🥗 Protein                         │
│                                     │
│ [Chart area - empty during tour]    │
│                                     │
│ ─────────────────────────────────   │
│ 📋 Set Your Baseline                │
│ ┌─────────────────────────────┐     │
│ │ Do you track protein? ●     │     │
│ │ ○ Yes  ● No                 │     │
│ │                             │     │
│ │ Estimate your daily intake: │     │
│ │ [____] g                    │     │
│ │                             │     │
│ │ ○ Skip (optional)           │     │
│ └─────────────────────────────┘     │
│                                     │
│ [← Back]            [Next: Veggies] │
└─────────────────────────────────────┘
```

### 2. Health History (Dedicated UI)

Family history, personal history, and screenings use a card-based UI:

```
┌─────────────────────────────────────┐
│ Family Health History              │
├─────────────────────────────────────┤
│ Does anyone in your family have:    │
│                                     │
│ ┌─────────────────────────────┐     │
│ │ Heart Disease               │     │
│ │ ○ Yes  ○ No  ○ Unknown     │     │
│ └─────────────────────────────┘     │
│                                     │
│ ┌─────────────────────────────┐     │
│ │ Diabetes                    │     │
│ │ ○ Yes  ○ No  ○ Unknown     │     │
│ └─────────────────────────────┘     │
│                                     │
│ ... more conditions ...             │
│                                     │
│ [← Back]                    [Next →]│
└─────────────────────────────────────┘
```

### 3. Supplements/Medications

Placed contextually:
- Sleep supplements → Sleep tour section
- Performance/recovery supplements → Movement tour section
- Dietary supplements → Nutrition tour section
- General wellness supplements → Health History section

---

## Complete Question-to-Screen Mapping

### NUTRITION TOUR (21 scored questions)

| Screen | Question # | Question | Type |
|--------|------------|----------|------|
| **ProteinScreen** | 2.09 | Do you track your daily protein intake? | scored |
| | 2.11 | How many grams of protein per day? | scored (function) |
| | 2.17 | How much protein from plant-based sources? | scored |
| **VegetablesScreen** | 2.65 | How many servings of vegetables daily? | scored |
| **FruitsScreen** | 2.19 | How many servings of fruit daily? | scored |
| **LegumesScreen** | 2.23 | How often do you consume legumes? | scored |
| **WholeGrainsScreen** | 2.21 | How often do you consume whole grains? | scored |
| **NutsSeedsScreen** | 2.25 | How often do you consume seeds? | scored |
| **FatsScreen** | 2.27 | How often do you consume healthy fats? | scored |
| | 2.15 | How often do you eat fatty fish? | scored |
| **WaterScreen** | 2.29 | How much water do you drink daily? | scored |
| **CaffeineScreen** | 2.31 | How much caffeine do you consume per day? | scored |
| | 2.33 | What are your primary sources of caffeine? | scored |
| | 2.34 | What time is your last caffeinated beverage? | scored |
| **MealPatternsScreen** | 2.03 | How many full meals per day? | scored |
| | 2.05 | How many snacks per day? | scored |
| | 2.07 | How often do you eat out? | scored |
| **UltraProcessedScreen** | 2.13 | How often do you consume processed meat? | scored |
| | 2.67 | How often do you consume red meat? | scored |
| *(Calories - new or existing)* | 2.59 | Do you track your daily caloric intake? | scored |
| | 2.62 | How many calories per day? | scored (function) |

### MOVEMENT TOUR (9 scored questions)

| Screen | Question # | Question | Type |
|--------|------------|----------|------|
| **StepsScreen** | 3.21 | How many steps do you typically take per day? | scored |
| **CardioScreen** | 3.04 | How often do you engage in cardio? | scored (function) |
| | 3.08 | On cardio days, how many total minutes? | scored (function) |
| **StrengthScreen** | 3.05 | How often do you engage in strength training? | scored (function) |
| | 3.09 | On strength days, how many total minutes? | scored (function) |
| **MobilityScreen** | 3.06 | How often do you do flexibility/mobility? | scored (function) |
| | 3.10 | On flexibility days, how many total minutes? | scored (function) |
| **HIITScreen** | 3.07 | How often do you engage in HIIT? | scored (function) |
| | 3.11 | On HIIT days, how many total minutes? | scored (function) |

### SLEEP TOUR (16 scored questions)

| Screen | Question # | Question | Type |
|--------|------------|----------|------|
| **SleepAnalysisScreen** | 4.02 | How many hours of sleep per night? | scored |
| | 4.03 | How often do you feel rested upon waking? | scored |
| | 4.04 | How consistent is your sleep schedule? | scored |
| **Sleep Protocols** | 4.07 | Which sleep hygiene protocols do you follow? | scored (function) |
| **Sleep Issues** | 4.12 | Do you experience any sleep issues? | scored (function) |
| | 4.13 | How often difficult to fall asleep? | scored (function) |
| | 4.14 | How often difficulty staying asleep? | scored (function) |
| | 4.15 | How often wake up too early? | scored (function) |
| | 4.16 | How often experience nightmares? | scored (function) |
| | 4.17 | How often experience restless legs? | scored (function) |
| | 4.18 | How often do you snore? | scored (function) |
| **Sleep Apnea** | 4.28 | Ever been diagnosed with sleep apnea? | scored (function) |
| | 4.29 | How long since sleep apnea diagnosis? | scored (function) |
| | 4.30 | Severity at time of diagnosis? | scored (function) |
| | 4.31 | Current treatments for sleep apnea? | scored (function) |
| | 4.32 | How much has treatment improved symptoms? | scored (function) |

### SUBSTANCES TOUR (38 scored questions via functions)

| Screen | Questions | Summary |
|--------|-----------|---------|
| **AlcoholScreen** | 8.01, 8.05-8.07, 8.20, 8.24-8.26 | Current use, duration, past use |
| **TobaccoScreen** | 8.01-8.04, 8.20-8.23 | Current use, duration, past use |
| **NicotineScreen** | 8.01, 8.11-8.13, 8.20, 8.30-8.32 | Current use, duration, past use |
| **CannabisScreen** | 8.01, 8.08-8.10, 8.20, 8.27-8.29 | Current use, duration, past use |

### STRESS/MENTAL HEALTH TOUR (7 scored questions)

| Screen | Question # | Question | Type |
|--------|------------|----------|------|
| **MindfulnessScreen** | 6.01 | How would you rate your current stress level? | scored (function) |
| | 6.02 | How often do you feel stressed? | scored (function) |
| | 6.07 | What methods do you use to manage stress? | scored (function) |
| **MentalHealthListView** | 10.13 | PHQ-2: Little interest or pleasure? | scored |
| | 10.14 | PHQ-2: Feeling down, depressed? | scored |
| | 10.15 | GAD-2: Feeling nervous, anxious? | scored |
| | 10.16 | GAD-2: Not being able to stop worrying? | scored |

### COGNITIVE TOUR (4 scored questions)

| Screen | Question # | Question | Type |
|--------|------------|----------|------|
| **CognitiveScreen** | 5.01 | Rate your current cognitive function | scored |
| | 5.02 | Any concerns about cognitive function? | scored |
| | 5.06 | How often do you engage in brain-challenging activities? | scored |
| | 5.08 | What types of cognitive activities? | scored (function) |

### CONNECTION TOUR (5 scored questions)

| Screen | Question # | Question | Type |
|--------|------------|----------|------|
| **SocialScreen** | 7.01 | Rate quality of social relationships | scored |
| | 7.02 | How often interact with friends/family? | scored |
| | 7.04 | Satisfaction with social interaction amount? | scored |
| | 7.07 | Do you have someone to talk to for support? | scored |
| | 7.09 | How comfortable in social situations? | scored |

### HEALTH HISTORY (58 scored questions - dedicated UI)

| Category | Question #s | Count |
|----------|-------------|-------|
| **Family History** | 9.01-9.38 | ~15 conditions |
| **Personal History** | 9.40-9.74 | ~15 conditions |
| **Preventive Screenings** | 10.01-10.11, 10.34 | 9 screening types |
| **Personal Care** | 8.58-8.64 | 4 questions |

---

## Database Changes Needed

### 1. Add screen mapping to questions

```sql
ALTER TABLE survey_questions_base
ADD COLUMN target_screen_id TEXT,
ADD COLUMN is_required BOOLEAN DEFAULT false,
ADD COLUMN display_order_in_screen SMALLINT;
```

### 2. Mark questions as required (scored)

```sql
UPDATE survey_questions_base q
SET is_required = true
WHERE EXISTS (
    SELECT 1 FROM wellpath_scoring_question_pillar_weights pw
    WHERE pw.question_number = q.question_number
)
OR EXISTS (
    SELECT 1 FROM wellpath_scoring_survey_function_questions sfq
    WHERE sfq.question_number = q.question_number
);
```

### 3. Create screen mapping table

```sql
CREATE TABLE onboarding_tour_screens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    screen_id TEXT UNIQUE NOT NULL,
    pillar_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    display_order SMALLINT NOT NULL,
    ios_view_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### 4. Populate screen mappings

```sql
INSERT INTO onboarding_tour_screens (screen_id, pillar_name, display_name, display_order, ios_view_name) VALUES
-- Nutrition
('SCREEN_PROTEIN', 'Healthful Nutrition', 'Protein', 1, 'ProteinScreen'),
('SCREEN_VEGETABLES', 'Healthful Nutrition', 'Vegetables', 2, 'VegetablesScreen'),
('SCREEN_FRUITS', 'Healthful Nutrition', 'Fruits', 3, 'FruitsScreen'),
-- ... etc
```

---

## iOS Implementation

### 1. OnboardingTourManager

```swift
@MainActor
class OnboardingTourManager: ObservableObject {
    @Published var currentScreenIndex: Int = 0
    @Published var tourScreens: [TourScreen] = []
    @Published var isInTourMode: Bool = false

    // Questions for current screen
    @Published var currentQuestions: [SurveyQuestion] = []
    @Published var responses: [String: QuestionResponse] = [:]

    func startTour() async { }
    func nextScreen() { }
    func previousScreen() { }
    func saveResponses() async { }
    func skipCurrentScreen() { }
}
```

### 2. TourQuestionCard Component

```swift
struct TourQuestionCard: View {
    let questions: [SurveyQuestion]
    @Binding var responses: [String: QuestionResponse]
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("📋 Set Your Baseline")
                .font(.headline)

            ForEach(questions) { question in
                QuestionRow(question: question, response: $responses[question.id])
            }

            HStack {
                Button("Skip") { onComplete() }
                Button("Save & Continue") {
                    // Save responses
                    onComplete()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
```

### 3. Modify Existing Screens

Each screen checks if it's in tour mode and shows the question card:

```swift
struct ProteinScreen: View {
    @EnvironmentObject var tourManager: OnboardingTourManager

    var body: some View {
        ScrollView {
            // Existing chart content
            if !tourManager.isInTourMode {
                ProteinChartCard()
            } else {
                // Show placeholder during tour
                TourChartPlaceholder(metricName: "Protein")
            }

            // Tour questions (shown when in tour mode OR as optional later)
            if tourManager.isInTourMode || showOptionalQuestions {
                TourQuestionCard(
                    questions: tourManager.currentQuestions,
                    responses: $tourManager.responses,
                    onComplete: { tourManager.nextScreen() }
                )
            }
        }
    }
}
```

### 4. Tour Flow Wrapper

```swift
struct OnboardingTourView: View {
    @StateObject var tourManager = OnboardingTourManager()

    var body: some View {
        NavigationStack {
            // Current screen based on tourManager.currentScreenIndex
            currentTourScreen
                .environmentObject(tourManager)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        TourProgressIndicator(
                            current: tourManager.currentScreenIndex,
                            total: tourManager.tourScreens.count
                        )
                    }
                }
        }
    }

    @ViewBuilder
    var currentTourScreen: some View {
        switch tourManager.tourScreens[tourManager.currentScreenIndex].screenId {
        case "SCREEN_PROTEIN": ProteinScreen()
        case "SCREEN_VEGETABLES": VegetablesScreen()
        // ... etc
        }
    }
}
```

---

## Baseline Tracking

Responses become baselines that can be compared to tracked data:

```swift
struct PatientBaseline {
    let metricId: String
    let baselineValue: Double
    let baselineDate: Date
    let source: BaselineSource // .survey, .healthKit, .manual
}

// When user tracks protein:
func compareToBaseline(trackedValue: Double, metricId: String) -> BaselineComparison {
    guard let baseline = getBaseline(for: metricId) else { return .noBaseline }

    let percentDiff = ((trackedValue - baseline.baselineValue) / baseline.baselineValue) * 100

    if percentDiff > 10 {
        return .aboveBaseline(percent: percentDiff)
    } else if percentDiff < -10 {
        return .belowBaseline(percent: abs(percentDiff))
    } else {
        return .atBaseline
    }
}
```

---

## Implementation Status (Updated 2025-12-17)

### Completed
- [x] **Database Changes** - Added `target_screen_id`, `is_required`, `display_order_in_screen` to `survey_questions_base`
- [x] **Tour Screens Table** - Created `onboarding_tour_screens` with 34 screens across 8 sections
- [x] **Populate Mappings** - All 146 scored questions mapped to their target screens
- [x] **TourModels.swift** - Data models (`TourScreen`, `TourSection`, `TourQuestion`, `TourResponse`, `TourProgress`)
- [x] **OnboardingTourManager.swift** - Core state management service
- [x] **TourQuestionCard.swift** - Reusable question UI component (single-select, multi-select, free-response, numeric)
- [x] **OnboardingTourView.swift** - Main tour orchestration view with section intros

### Remaining
- [ ] **Health History UI** - Build dedicated `FamilyHistoryView`, `PersonalHistoryView`, `ScreeningsListView`
- [ ] **Integration** - Add `LaunchTourButton` to app entry points
- [ ] **Baseline System** - Store and compare baselines vs tracked data
- [ ] **Polish** - Animations, loading states, error handling

### Files Created
- `WellPath/Models/Onboarding/TourModels.swift`
- `WellPath/Services/Onboarding/OnboardingTourManager.swift`
- `WellPath/Views/Onboarding/TourQuestionCard.swift`
- `WellPath/Views/Onboarding/OnboardingTourView.swift`

---

## Implementation Order

1. ~~**Database Changes** - Add columns, create mapping table~~ ✓
2. ~~**Populate Mappings** - Map all 146 questions to screens~~ ✓
3. ~~**OnboardingTourManager** - Core state management~~ ✓
4. ~~**TourQuestionCard** - Reusable question UI component~~ ✓
5. **Modify First Pillar** - Start with Nutrition screens
6. **Health History UI** - Build dedicated family/personal history views
7. ~~**Wire Up Flow** - OnboardingTourView orchestration~~ ✓
8. **Baseline System** - Store and compare baselines
9. **Polish** - Progress indicators, animations, skip logic

---

## Files to Create/Modify

### New Files
- `Services/Onboarding/OnboardingTourManager.swift`
- `Views/Onboarding/OnboardingTourView.swift`
- `Views/Onboarding/TourQuestionCard.swift`
- `Views/Onboarding/TourProgressIndicator.swift`
- `Views/Onboarding/TourChartPlaceholder.swift`
- `Views/HealthHistory/FamilyHistoryView.swift`
- `Views/HealthHistory/PersonalHistoryView.swift`
- `Models/Onboarding/TourScreen.swift`
- `Models/Onboarding/PatientBaseline.swift`

### Modified Files
- All metric screen views (add tour mode support)
- `HealthProfileView.swift` (redirect to tour)
- `HealthProfileViewModel.swift` (load tour data)

---

## Success Criteria

- [ ] User completes onboarding in 15-20 minutes
- [ ] All 146 scored questions collected
- [ ] User learns the app while answering questions
- [ ] Baselines established for tracked metrics
- [ ] Optional questions available on metric screens after onboarding
- [ ] Health history uses clean card-based UI
- [ ] WellPath Score calculation unchanged
