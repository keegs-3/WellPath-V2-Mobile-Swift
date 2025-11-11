-- Diagnostic: Check for duplicate daily SUM entries and weekly aggregation calculation
-- This will help identify why we're getting 4 entries instead of 3 days

-- =====================================================
-- 1. Check daily SUM entries for the week in question
-- =====================================================

SELECT 
    period_start,
    COUNT(*) as entry_count,
    STRING_AGG(DISTINCT id::text, ', ') as entry_ids,
    STRING_AGG(DISTINCT value::text, ', ') as values,
    STRING_AGG(DISTINCT last_computed_at::text, ', ') as last_computed_ats,
    SUM(value) as total_for_day
FROM aggregation_results_cache
WHERE patient_id = '8b79ce33-02b8-4f49-8268-3204130efa82' -- Replace with actual patient_id
    AND agg_metric_id = 'AGG_SLEEP_DURATION'
    AND period_type = 'daily'
    AND calculation_type_id = 'SUM'
    AND period_start >= '2025-10-27'::date
    AND period_start <= '2025-11-03'::date -- Week of 10/27-11/03
GROUP BY period_start
ORDER BY period_start;

-- =====================================================
-- 2. Check what the weekly aggregation actually shows
-- =====================================================

SELECT 
    period_start,
    period_end,
    value,
    data_points_count,
    last_computed_at
FROM aggregation_results_cache
WHERE patient_id = '8b79ce33-02b8-4f49-8268-3204130efa82'
    AND agg_metric_id = 'AGG_SLEEP_DURATION'
    AND period_type = 'weekly'
    AND calculation_type_id = 'AVG'
    AND period_start = '2025-10-27'::date;

-- =====================================================
-- 3. Simulate what the rollup function should calculate
-- =====================================================

WITH unique_daily_sums AS (
    SELECT DISTINCT ON (patient_id, agg_metric_id, period_start)
        period_start,
        value
    FROM aggregation_results_cache
    WHERE patient_id = '8b79ce33-02b8-4f49-8268-3204130efa82'
        AND agg_metric_id = 'AGG_SLEEP_DURATION'
        AND period_type = 'daily'
        AND calculation_type_id = 'SUM'
        AND value IS NOT NULL
        AND period_start >= '2025-10-27'::date
        AND period_start <= '2025-11-03'::date
    ORDER BY patient_id, agg_metric_id, period_start, last_computed_at DESC
)
SELECT
    DATE_TRUNC('week', period_start)::date as week_start,
    (DATE_TRUNC('week', period_start) + INTERVAL '6 days')::date as week_end,
    COUNT(*) as day_count,
    SUM(value) as total_sum,
    SUM(value) / NULLIF(COUNT(*), 0) as calculated_avg,
    STRING_AGG(value::text, ', ' ORDER BY period_start) as daily_values
FROM unique_daily_sums
GROUP BY DATE_TRUNC('week', period_start);

-- =====================================================
-- 4. Check if process_field_aggregations creates multiple entries per day
--    by looking at patient_data_entries for the same period
-- =====================================================

SELECT 
    entry_date,
    COUNT(*) as session_count,
    SUM(value_quantity) as total_minutes,  -- value_quantity is stored in minutes
    STRING_AGG(id::text, ', ') as entry_ids,
    STRING_AGG(value_quantity::text, ', ') as individual_values
FROM patient_data_entries
WHERE patient_id = '8b79ce33-02b8-4f49-8268-3204130efa82'
    AND field_id = 'OUTPUT_SLEEP_DURATION'
    AND entry_date >= '2025-10-27'::date
    AND entry_date <= '2025-11-03'::date
GROUP BY entry_date
ORDER BY entry_date;

