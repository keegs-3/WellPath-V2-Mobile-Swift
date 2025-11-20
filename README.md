# WellPath V2 Mobile (Swift/SwiftUI)

Native iOS app for WellPath health tracking platform, built with Swift and SwiftUI.

## Overview

WellPath is a personalized health tracking platform that integrates with Apple Health to monitor sleep, exercise, nutrition, and other wellness metrics. The app features:

- **Dashboard**: Layered radial chart showing overall wellness score across health pillars
- **Metrics Tracking**: Detailed views for sleep, cardio, nutrition with Apple Charts
- **HealthKit Integration**: Auto-sync data from Apple Health
- **Supabase Backend**: Real-time data sync and aggregation
- **Tracked Metrics Entry**: Manual entry for metrics not captured by HealthKit

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Charts**: Apple Charts (iOS 16+)
- **Backend**: Supabase (PostgreSQL, Auth, Edge Functions)
- **Health Integration**: HealthKit
- **Architecture**: MVVM

## Getting Started

### Prerequisites

- macOS 13.0+ with Xcode 15.0+
- iOS 16.0+ (target deployment)
- Active Supabase project
- Apple Developer account (for device testing)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_ORG/WellPath-V2-Mobile-Swift.git
   cd WellPath-V2-Mobile-Swift
   ```

2. **Open in Xcode**

   You'll need to create the Xcode project first:
   - Open Xcode
   - File → New → Project
   - Choose "iOS" → "App"
   - Product Name: `WellPath`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Save to this repository directory

   Then add all the files from the `WellPath/` directory to the project.

3. **Add Swift Package Dependencies**

   In Xcode:
   - File → Add Packages
   - Add: `https://github.com/supabase/supabase-swift`

4. **Configure Supabase**

   Open `WellPath/Services/SupabaseManager.swift` and update:
   ```swift
   supabaseURL: URL(string: "YOUR_SUPABASE_URL")!
   supabaseKey: "YOUR_SUPABASE_ANON_KEY"
   ```

5. **Enable HealthKit**

   - Select WellPath target
   - Signing & Capabilities → + Capability → HealthKit

6. **Run the app**

   Press ⌘R to build and run on simulator or device.

## Project Structure

```
WellPath/
├── WellPathApp.swift              # App entry point
├── ContentView.swift               # Root view
│
├── Services/
│   └── SupabaseManager.swift       # Supabase client singleton
│
├── ViewModels/
│   └── SleepViewModel.swift        # Sleep data business logic
│
├── Views/
│   ├── MainTabView.swift           # Tab bar navigation
│   │
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── PillarChartCard.swift   # Wellness score chart
│   │
│   ├── Sleep/
│   │   ├── SleepDetailView.swift   # Sleep chart with period selector
│   │   └── SleepEntryView.swift    # Manual sleep entry
│   │
│   ├── Metrics/
│   │   └── MetricsView.swift       # Metrics list
│   │
│   ├── Challenges/
│   │   └── ChallengesView.swift
│   │
│   ├── Education/
│   │   └── EducationView.swift
│   │
│   └── TrackedMetrics/
│       └── TrackedMetricsEntryView.swift  # + button modal
│
└── Info.plist                      # HealthKit permissions
```

## Key Features

### Apple Health Pattern Period Selector

Matches native Apple Health UX:

| Period | Display | Aggregation |
|--------|---------|-------------|
| Daily (D) | TOTAL | SUM for counts, AVG for rates |
| Weekly (W) | AVERAGE | AVG per day |
| Monthly (M) | AVERAGE | AVG per day |
| 6-Month (6M) | DAILY AVERAGE | AVG per day |
| Yearly (Y) | DAILY AVERAGE | AVG per day |

### Reusable Components

- **PeriodSelector**: Period toggle (D/W/M/6M/Y) - reusable across all metric charts
- **SleepChart**: Apple Charts BarMark template - clone for cardio, nutrition, etc.
- **TrackedMetricsEntry**: Centralized entry flow for all manual tracking

### Data Flow

```
Manual Entry → patient_data_entries → instance_calculations → aggregations → aggregation_results_cache → Charts
                                                                                          ↑
HealthKit Sync ────────────────────────────────────────────────────────────────────────┘
```

## Architecture

### MVVM Pattern

- **Models**: Codable structs for Supabase data (e.g., `AggregationResult`)
- **ViewModels**: `@Published` properties, async data fetching, business logic
- **Views**: SwiftUI views, user interactions, UI state

### Supabase Integration

Direct client integration (no middleware API):
- Auth: `SupabaseManager.shared.client.auth`
- Database: `SupabaseManager.shared.client.from("table")`
- RLS policies enforce data security

### HealthKit Integration

- Request permissions on first launch
- Background sync for sleep, workouts
- Store in `patient_data_entries` with `source='healthkit'`

## Backend Requirements

Ensure these Supabase tables exist:

- `patient_data_entries` - Raw health data entries
- `aggregation_results_cache` - Pre-computed aggregations
- `display_metrics` - UI metric configurations
- `display_metrics_aggregations` - Metric → aggregation mappings
- `aggregation_periods` - Period definitions (daily, weekly, etc.)

Required RLS policies:
```sql
-- Allow users to read their own aggregation results
CREATE POLICY allow_read_aggregation_cache
ON aggregation_results_cache FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Allow users to insert their own data entries
CREATE POLICY allow_insert_data_entries
ON patient_data_entries FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());
```

## Development Guidelines

### Adding New Metrics

1. **Create Detail View** (copy `SleepDetailView.swift`):
   - Replace metric references
   - Update chart colors/icons
   - Adjust y-axis units

2. **Create ViewModel** (copy `SleepViewModel.swift`):
   - Update `agg_metric_id` query parameter
   - Update unit conversions if needed

3. **Add to Navigation**:
   - Add row to `MetricsView.swift`
   - Add entry form to `TrackedMetricsEntryView.swift`

4. **Configure Backend**:
   - Ensure display_metric exists
   - Link to aggregation_metric
   - Set up calculation rules

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint (TODO: add config)
- Async/await for all async operations
- `@MainActor` for view models
- Proper error handling with `.alert()`

## Testing

- Unit tests: TODO
- UI tests: TODO
- HealthKit testing: Requires physical device

## Deployment

- Target: iOS 16.0+
- Devices: iPhone only (iPad support TODO)
- TestFlight: TODO
- App Store: TODO

## Related Repositories

- **Backend**: [WellPath-V2-Backend](https://github.com/YOUR_ORG/WellPath-V2-Backend) - Supabase schema, migrations, edge functions
- **Web (Clinician Portal)**: [WellPath-Web](https://github.com/YOUR_ORG/WellPath-Web) - Next.js clinician dashboard

## License

Copyright © 2025 WellPath. All rights reserved.

## Support

For issues, questions, or contributions, please open a GitHub issue or contact the development team.

