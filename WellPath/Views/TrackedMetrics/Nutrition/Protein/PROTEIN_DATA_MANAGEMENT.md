# Protein Data Management

## Overview

Simple data management pipeline for protein tracking, similar to sleep but without the middle grouping layer.

## Flow

```
ProteinPrimary (list.bullet button)
    ↓
ProteinDataManagementView (grouped by date, shows source icons)
    ↓
ProteinEntryDetailView (individual entry details with delete)
```

## Components

### ProteinDataManagementView
- **Purpose**: Shows all protein entries grouped by date
- **Features**:
  - Source icons (WellPath logo or HealthKit heart)
  - Date filtering
  - Edit mode with multi-select
  - Swipe to delete
  - Batch delete

### ProteinEntryRow
- Displays: Amount (grams), type, timing/time
- Shows source icon
- Chevron for navigation

### ProteinEntryDetailView
- Full entry details
- Delete functionality for WellPath/HealthKit entries
- Shows entry ID for debugging

### ProteinDataManagementViewModel
- Loads protein data from `patient_data_entries`
- Groups entries by `event_instance_id` (one meal = multiple fields)
- Fetches reference data for types and timings
- Assembles complete protein entries from related fields:
  - `DEF_PROTEIN_QUANTITY` - amount in grams
  - `DEF_PROTEIN_TYPE` - protein source (chicken, tofu, etc.)
  - `DEF_PROTEIN_TIME` - when consumed
  - `DEF_PROTEIN_TIMING` - meal timing (breakfast, lunch, etc.)
- Deletes all entries with same `event_instance_id` when deleting

## Key Differences from Sleep

| Feature | Sleep | Protein |
|---------|-------|---------|
| Middle grouping page | Yes (by period type) | No |
| Entry structure | Complex (sessions/events/periods) | Simple (grouped fields) |
| Source filtering | By type AND source | By source only |
| Navigation | 3 levels (list → type → detail) | 2 levels (list → detail) |

## Data Model

### ProteinEntry
```swift
struct ProteinEntry: Identifiable {
    let id: UUID                      // entry ID
    let eventInstanceId: UUID         // groups related fields
    let patientId: UUID
    let entryDate: Date
    let createdAt: Date
    let source: String                // "wellpath" or "healthkit"
    let proteinGrams: Double
    let proteinType: UUID?            // reference to type
    let proteinTypeName: String?      // "Chicken", "Tofu", etc.
    let proteinTime: Date?            // specific time
    let timing: UUID?                 // reference to timing
    let timingName: String?           // "Breakfast", "Lunch", etc.
}
```

## UI Elements

### Toolbar
- **Leading**: list.bullet icon → Opens data management
- **Trailing**: plus icon → Opens entry form

### List Sections
- Grouped by date (newest first)
- Section headers show "MMM d, yyyy"

### Edit Mode
- Select/deselect individual entries
- "Select All" / "Delete (N)" button
- Checkmark circles for selected items
- Only deletable entries (WellPath/HealthKit) can be selected

### Filtering
- Date range filter (start/end dates)
- Filter icon changes when active (fill vs outline)

## Usage

```swift
// In ProteinPrimary.swift
@State private var showingDataManagement = false

Button {
    showingDataManagement = true
} label: {
    Image(systemName: "list.bullet")
}

.sheet(isPresented: $showingDataManagement) {
    ProteinDataManagementView(color: color)
}
```

## Future Enhancements

1. **Inline editing**: Edit protein amount, type, timing without going to detail
2. **Duplicate entries**: Copy an entry to add similar meal
3. **Bulk operations**: Move entries to different dates
4. **Export**: CSV/PDF export of protein data
5. **Statistics**: Show totals, averages in header

---

**Created**: 2025-11-20
**Pattern**: Based on generic `DataManagementView` + sleep data management concepts
