-- Check for duplicate daily SUM entries
-- This will help identify if there are multiple daily SUM entries per day
-- Created: 2025-11-05

-- Check for duplicate daily SUM entries for AGG_SLEEP_DURATION
SELECT 
    period_start,
    COUNT(*) as entry_count,
    STRING_AGG(DISTINCT id::text, ', ') as entry_ids,
    STRING_AGG(DISTINCT value::text, ', ') as values,
    STRING_AGG(DISTINCT last_computed_at::text, ', ') as computed_times
FROM aggregation_results_cache
WHERE agg_metric_id = 'AGG_SLEEP_DURATION'
    AND period_type = 'daily'
    AND calculation_type_id = 'SUM'
    AND period_start >= '2025-10-27'::date
    AND period_start <= '2025-11-03'::date
GROUP BY period_start
HAVING COUNT(*) > 1
ORDER BY period_start;

-- Show all daily SUM entries for the week in question
SELECT 
    period_start,
    value,
    data_points_count,
    last_computed_at,
    id
FROM aggregation_results_cache
WHERE agg_metric_id = 'AGG_SLEEP_DURATION'
    AND period_type = 'daily'
    AND calculation_type_id = 'SUM'
    AND period_start >= '2025-10-27'::date
    AND period_start <= '2025-11-03'::date
ORDER BY period_start, last_computed_at DESC;

-- Show what the weekly aggregation should be:
-- Sum of daily totals / number of unique days
WITH daily_sums AS (
    SELECT DISTINCT ON (period_start)
        period_start,
        value
    FROM aggregation_results_cache
    WHERE agg_metric_id = 'AGG_SLEEP_DURATION'
        AND period_type = 'daily'
        AND calculation_type_id = 'SUM'
        AND period_start >= '2025-10-27'::date
        AND period_start <= '2025-11-03'::date
    ORDER BY period_start, last_computed_at DESC
)
SELECT 
    '2025-10-27'::date as week_start,
    '2025-11-03'::date as week_end,
    SUM(value) as total_sum,
    COUNT(*) as day_count,
    SUM(value) / NULLIF(COUNT(*), 0) as correct_avg
FROM daily_sums
WHERE DATE_TRUNC('week', period_start)::date = '2025-10-27'::date;


