-- Complete fix: Delete and recalculate weekly/monthly aggregations
-- Run this AFTER updating the process_rollup_aggregations function
-- Created: 2025-11-05

-- Step 1: Delete existing incorrect weekly/monthly/6month/yearly aggregations
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

-- Step 2: For each patient and metric, recalculate aggregations
-- This will use the updated process_rollup_aggregations function
-- Replace 'YOUR_PATIENT_ID' with your actual patient UUID

DO $$
DECLARE
    v_patient_id uuid;
    v_agg_metric_id text;
    v_date date;
    v_start_date date;
    v_end_date date;
BEGIN
    -- Get date range from existing daily SUM entries
    SELECT 
        MIN(period_start)::date,
        MAX(period_start)::date
    INTO v_start_date, v_end_date
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
        );

    -- Process each patient
    FOR v_patient_id IN
        SELECT DISTINCT patient_id
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
    LOOP
        -- Process each metric
        FOR v_agg_metric_id IN 
            SELECT DISTINCT agg_metric_id
            FROM aggregation_results_cache
            WHERE patient_id = v_patient_id
                AND period_type = 'daily'
                AND calculation_type_id = 'SUM'
                AND agg_metric_id IN (
                    'AGG_SLEEP_DURATION',
                    'AGG_AWAKE_DURATION',
                    'AGG_REM_SLEEP_DURATION',
                    'AGG_CORE_SLEEP_DURATION',
                    'AGG_DEEP_SLEEP_DURATION',
                    'AGG_TIME_IN_BED'
                )
        LOOP
            -- Process each date in range to trigger recalculation
            v_date := v_start_date;
            WHILE v_date <= v_end_date LOOP
                PERFORM process_rollup_aggregations(
                    v_patient_id,
                    v_agg_metric_id,
                    v_date
                );
                v_date := v_date + INTERVAL '1 day';
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- Step 3: Verify the results
SELECT 
    period_type,
    period_start,
    period_end,
    value,
    data_points_count,
    CASE 
        WHEN period_type = 'weekly' AND period_start = '2025-10-27'::date 
        THEN 'Should be 550 (1650/3), not 412.5 (1650/4)' 
        ELSE '' 
    END as note
FROM aggregation_results_cache
WHERE period_type IN ('weekly', 'monthly')
    AND calculation_type_id = 'AVG'
    AND agg_metric_id = 'AGG_SLEEP_DURATION'
    AND period_start >= '2025-10-27'::date
    AND period_start <= '2025-11-10'::date
ORDER BY period_type, period_start;


