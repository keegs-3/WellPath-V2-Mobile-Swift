-- Fix Daily Aggregations: Ensure SUM entries exist instead of AVG
-- This script fixes the issue where daily aggregations were created as AVG
-- instead of SUM for sleep duration metrics
-- Created: 2025-11-05

-- =====================================================
-- 1. Identify and report daily AVG entries that should be SUM
-- =====================================================

SELECT 
    'Daily AVG entries that should be SUM:' as issue,
    agg_metric_id,
    COUNT(*) as count,
    MIN(period_start) as earliest_date,
    MAX(period_start) as latest_date
FROM aggregation_results_cache
WHERE period_type = 'daily'
    AND calculation_type_id = 'AVG'
    AND agg_metric_id IN (
        'AGG_SLEEP_DURATION',
        'AGG_AWAKE_DURATION',
        'AGG_REM_SLEEP_DURATION',
        'AGG_CORE_SLEEP_DURATION',
        'AGG_DEEP_SLEEP_DURATION',
        'AGG_TIME_IN_BED'
    )
GROUP BY agg_metric_id;

-- =====================================================
-- 2. Delete daily AVG entries for sleep duration metrics
--    (These should not exist - only SUM should exist)
-- =====================================================

DELETE FROM aggregation_results_cache
WHERE period_type = 'daily'
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
-- 3. Note: Daily SUM entries should be created by process_field_aggregations
--    If they don't exist, you'll need to re-run process_all_sleep_aggregations
--    for the affected date ranges
-- =====================================================

-- Verify that daily SUM entries exist for each patient and metric
SELECT 
    'Daily SUM entries (should exist):' as status,
    patient_id,
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
GROUP BY patient_id, agg_metric_id
ORDER BY patient_id, agg_metric_id;


