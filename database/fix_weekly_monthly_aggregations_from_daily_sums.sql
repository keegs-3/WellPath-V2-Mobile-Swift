-- Fix Weekly/Monthly Aggregations: Recalculate from Daily SUMs
-- This script deletes existing weekly/monthly aggregations that may have been
-- calculated incorrectly (dividing by entries instead of days) and forces
-- recalculation from daily SUM aggregations
-- Created: 2025-11-05

-- =====================================================
-- 1. Delete existing weekly/monthly/6month/yearly aggregations
--    that should be recalculated from daily SUMs
-- =====================================================

DELETE FROM aggregation_results_cache
WHERE period_type IN ('weekly', 'monthly', '6month', 'yearly')
    AND calculation_type_id = 'AVG'
    AND agg_metric_id IN (
        'AGG_SLEEP_DURATION',
        'AGG_AWAKE_DURATION',
        'AGG_REM_SLEEP_DURATION',
        'AGG_CORE_SLEEP_DURATION',
        'AGG_DEEP_SLEEP_DURATION',
        'AGG_TIME_IN_BED'
    );

-- =====================================================
-- 2. Note: After running this, you need to call
--    process_rollup_aggregations for each date/patient
--    to recalculate the aggregations from daily SUMs
--    
--    Example (replace with your patient_id and date range):
--    SELECT process_rollup_aggregations(
--        'your-patient-id'::uuid,
--        'AGG_SLEEP_DURATION',
--        '2025-11-01'::date
--    );
--    
--    Or use process_all_sleep_aggregations to process
--    all sleep metrics for a date range:
--    SELECT process_all_sleep_aggregations(
--        'your-patient-id'::uuid,
--        '2025-10-01'::date,
--        '2025-11-05'::date
--    );
-- =====================================================

-- Verify daily SUM entries exist (required for recalculation)
SELECT 
    'Daily SUM entries (must exist for recalculation):' as status,
    agg_metric_id,
    COUNT(*) as count,
    MIN(period_start) as earliest_date,
    MAX(period_start) as latest_date
FROM aggregation_results_cache
WHERE period_type = 'daily'
    AND calculation_type_id = 'SUM'
    AND agg_metric_id IN (
        'AGG_SLEEP_DURATION',
        'AGG_AWAKE_DURATION',
        'AGG_REM_SLEEP_DURATION',
        'AGG_CORE_SLEEP_DURATION',
        'AGG_DEEP_SLEEP_DURATION',
        'AGG_TIME_IN_BED'
    )
GROUP BY agg_metric_id
ORDER BY agg_metric_id;


