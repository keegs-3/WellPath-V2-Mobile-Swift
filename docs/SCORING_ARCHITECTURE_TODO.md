# WellPath Scoring Architecture - Major TODO

## Overview

This document outlines the unified scoring architecture needed for WellPath. The `sample_scoring_ranges` table should become the single source of truth for ALL scoring, but currently only handles biomarkers/biometrics cleanly.

## Current State

### What Works Well (Biomarkers/Biometrics)
```
patient_clinical_samples → sample_scoring_ranges → score
patient_quantity_samples → sample_scoring_ranges → score
```
- Entry values directly match ranges
- Scoring updates flow immediately
- No threshold considerations needed
- `get_scoring_ranges()` function handles demographic stratification

### What's Complex (Surveys + Behavioral)

**Survey Response → Score Pipeline:**
```
survey_questions
    ↓
patient_survey_responses
    ↓
survey_response_options_aggregations (groups of responses → value)
survey_response_numeric_values (response → numeric value)
    ↓
wellpath_scoring_question_pillar_weights (response/band → score)
    ↓
patient_baseline_samples (stores converted value, e.g., 3750 steps)
```

**Behavioral Threshold Pipeline:**
```
patient_baseline_samples (survey-derived baseline, e.g., 3750 steps)
    ↓
behavioral_threshold_config (rules for overwriting baseline)
    ↓
aggregation_results_cache (actual tracked data)
    ↓
Threshold logic: "Need X days of data to override baseline score"
```

**Example: Steps**
1. Patient survey: "I take 2500-5000 steps/day"
2. Convert to midpoint: 3,750 steps
3. Store in `patient_baseline_samples`
4. Score based on this baseline
5. Threshold rule: "Need 7 days of step data to override"
6. If patient logs 1 day of 20k steps → DON'T update score yet
7. If patient has 7+ days averaging 20k → Update score

## Tables Needing Consolidation

| Current Table | Purpose | Target |
|--------------|---------|--------|
| `survey_response_options_aggregations` | Group responses → value | Consolidate |
| `survey_response_numeric_values` | Response → numeric | Consolidate |
| `wellpath_scoring_question_pillar_weights` | Response → pillar scores | Keep but simplify |
| `behavioral_threshold_config` | Override rules | Keep |
| `scoring_method_*` tables | Various scoring methods | Review for consolidation |

## Proposed Unified Architecture

### Phase 1: Current (Biomarkers/Biometrics)
```
sample_scoring_ranges
├── clinical_type → patient_clinical_samples
├── quantity_type → patient_quantity_samples
└── Demographic stratification via patient_characteristics
```

### Phase 2: TODO (Surveys)
```
sample_scoring_ranges (or survey_scoring_ranges?)
├── survey_question_id or response_group_id
├── Converted numeric value from survey response
└── Maps to pillar weights
```

### Phase 3: TODO (Behavioral Thresholds)
```
behavioral_threshold_config
├── Links baseline (from survey) to tracked metric
├── Defines data requirements for override
└── Scoring uses: tracked_data if sufficient, else baseline
```

## Key Design Questions

1. **Should survey scoring use `sample_scoring_ranges`?**
   - Pro: Single table for all scoring
   - Con: Survey responses aren't "samples" in the traditional sense

2. **How to unify the value conversion?**
   - Currently: Multiple tables with overlapping purposes
   - Goal: Clear pipeline from response → value → score

3. **Threshold logic location?**
   - Database function vs Edge function vs iOS
   - Needs to be consistent across all access points

## Priority

This is the most complex component of WellPath. Clean up displays first to validate the simpler biomarker/biometric flow works correctly, then tackle survey/behavioral scoring.

## Related Tables

### Scoring
- `sample_scoring_ranges` - Main ranges table (biomarkers/biometrics)
- `wellpath_scoring_marker_pillar_weights` - Marker → pillar contribution
- `wellpath_scoring_question_pillar_weights` - Survey → pillar contribution
- `behavioral_threshold_config` - Override rules

### Data Sources
- `patient_clinical_samples` - Lab results
- `patient_quantity_samples` - Tracked quantities
- `patient_baseline_samples` - Survey-derived baselines
- `patient_survey_responses` - Raw survey answers
- `aggregation_results_cache` - Aggregated tracked data

### Display
- `display_views` - View configuration
- `display_views_dependencies` - What data a view needs

---
*Created: 2025-12-05*
*Status: Planning*
