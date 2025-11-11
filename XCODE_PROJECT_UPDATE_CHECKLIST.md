# Xcode Project Update Checklist

## Files to REMOVE from Xcode (Remove Reference, don't delete from disk)

### Already deleted from disk (safe to remove reference):
- [ ] Views/Sleep/SleepPrimaryView.swift
- [ ] Views/Sleep/SleepAnalysisChart.swift
- [ ] Views/Sleep/SleepDetailView.swift
- [ ] Views/Sleep/SleepStageChartView.swift
- [ ] Views/Nutrition/ProteinPrimaryView.swift
- [ ] Views/Nutrition/ProteinDetailView.swift
- [ ] Views/Nutrition/ProteinEntryView.swift
- [ ] ViewModels/SleepViewModel.swift (moved to TrackedMetrics/Sleep/SleepAnalysis/)

### Moved to WellPathScore (remove old reference):
- [ ] Views/Score/BehaviorsDetailView.swift → Views/WellPathScore/
- [ ] Views/Score/ComponentDetailView.swift → Views/WellPathScore/
- [ ] Views/Score/EducationDetailView.swift → Views/WellPathScore/
- [ ] Views/Score/MarkersDetailView.swift → Views/WellPathScore/
- [ ] Views/Score/WellPathOverviewView.swift → Views/WellPathScore/
- [ ] ViewModels/WellPathScoreViewModel.swift → ViewModels/WellPathScore/
- [ ] ViewModels/MetricsViewModel.swift → ViewModels/Metrics/

## Folders to ADD to Xcode Project

### Views
1. [ ] Right-click "Views" folder → Add Files to WellPath...
   - Navigate to: WellPath/Views/TrackedMetrics/
   - Select folders: **Sleep**, **Nutrition**, **Shared**
   - Options: ✓ Create groups, ✓ Add to targets: WellPath
   - Click Add

2. [ ] Right-click "Views" folder → Add Files to WellPath...
   - Navigate to: WellPath/Views/
   - Select folder: **WellPathScore**
   - Options: ✓ Create groups, ✓ Add to targets: WellPath
   - Click Add

### ViewModels
3. [ ] Right-click "ViewModels" folder → Add Files to WellPath...
   - Navigate to: WellPath/ViewModels/
   - Select folders: **TrackedMetrics**, **WellPathScore**, **Metrics**
   - Options: ✓ Create groups, ✓ Add to targets: WellPath
   - Click Add

## After Adding Files

4. [ ] Product → Clean Build Folder (Cmd+Shift+K)
5. [ ] Product → Build (Cmd+B)
6. [ ] Check for any remaining red files
7. [ ] If build succeeds, test app navigation

## New File Structure
```
Views/
  TrackedMetrics/
    Sleep/
      SleepAnalysis/
        SleepAnalysisPrimary.swift ✅
        SleepAnalysisDetail.swift ✅
      SleepDuration/
        SleepDurationPrimary.swift ✅
        SleepDurationDetail.swift ✅
    Nutrition/
      Protein/
        ProteinPrimary.swift ✅
        ProteinDetail.swift ✅
    Shared/
      SleepEntryView.swift ✅
  WellPathScore/
    (4 detail views) ✅

ViewModels/
  TrackedMetrics/
    Sleep/
      SleepAnalysis/SleepAnalysisViewModel.swift ✅
      SleepDuration/SleepDurationViewModel.swift ✅
    Nutrition/
      Protein/ProteinViewModel.swift ✅
  WellPathScore/
    WellPathScoreViewModel.swift ✅
  Metrics/
    MetricsViewModel.swift ✅
```
