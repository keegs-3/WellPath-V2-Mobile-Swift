# Remaining Build Fixes for TrackedMetrics Reorganization

## Current Status
- Folder structure: ✅ Complete
- Files moved: ✅ Complete
- Build errors: ⚠️ Type ambiguity issues

## Remaining Errors to Fix

### 1. Type Name Conflicts
**Problem:** SleepDurationDetail was copied from SleepAnalysisDetail, so they have duplicate type names.

**Already Fixed:**
- ✅ `SleepDetailViewModel` → `SleepDurationViewModel`
- ✅ `PeriodType` → `SleepDurationPeriod`

**Still Need to Fix:**
- Rename all supporting types in SleepDurationDetail to avoid conflicts:
  - `SleepDataPoint` → `SleepDurationDataPoint` (conflicts with SleepAnalysis)
  - `DailySleepData` → `DailySleepDurationData`
  - Any other shared type names

### 2. Missing Imports
Some files may need explicit imports after reorganization:
- Check if SleepAnalysisPrimary imports SleepAnalysisViewModel
- Check if files can find SleepStage enum
- Check if shared types are accessible

### 3. Enum References
- ProteinViewModel references `ProteinPrimary.ProteinPeriod` but that enum doesn't exist
  - **Fix:** Delete ProteinViewModel.swift (already done) ✅

### 4. TabSelector Reference
Line 189 in SleepDurationDetail:
```swift
@Binding var selectedTab: SleepDetailView.DetailTab
```
Should be:
```swift
@Binding var selectedTab: SleepDurationDetail.DetailTab
```

## Quick Fix Strategy

1. **Search and replace in SleepDurationDetail.swift:**
   - `SleepDetailView` → `SleepDurationDetail`
   - `SleepDataPoint` → `SleepDurationDataPoint`
   - `DailySleepData` → `DailySleepDurationData`

2. **Remove stub ViewModels that aren't being used:**
   - ProteinViewModel.swift ✅ (already deleted)
   - SleepDurationViewModel.swift (being used, keep it)

3. **Clean Build:**
   - Remove Info.plist from Copy Bundle Resources ✅
   - Clean Build Folder
   - Build

## Commands to Run

```bash
# Fix SleepDurationDetail type references
cd /Users/keegs/Documents/WellPath/WellPath-V2-Mobile-Swift/WellPath/Views/TrackedMetrics/Sleep/SleepDuration

sed -i '' 's/SleepDetailView\./SleepDurationDetail./g' SleepDurationDetail.swift
sed -i '' 's/struct SleepDataPoint/struct SleepDurationDataPoint/g' SleepDurationDetail.swift
sed -i '' 's/: \[SleepDataPoint\]/: [SleepDurationDataPoint]/g' SleepDurationDetail.swift
sed -i '' 's/<SleepDataPoint>/<SleepDurationDataPoint>/g' SleepDurationDetail.swift
sed -i '' 's/(SleepDataPoint)/(SleepDurationDataPoint)/g' SleepDurationDetail.swift
sed -i '' 's/struct DailySleepData/struct DailySleepDurationData/g' SleepDurationDetail.swift
sed -i '' 's/: \[DailySleepData\]/: [DailySleepDurationData]/g' SleepDurationDetail.swift
sed -i '' 's/<DailySleepData>/<DailySleepDurationData>/g' SleepDurationDetail.swift
sed -i '' 's/DailySleepData(/DailySleepDurationData(/g' SleepDurationDetail.swift
```

Then rebuild in Xcode.
