-- =====================================================
-- Fix 6month and Yearly AVG Calculations (CORRECTED)
-- =====================================================
-- Problem: App is calculating 6month/yearly by averaging
--          weekly/monthly averages, causing incorrect results
--
-- Solution: Add 6month and yearly to database aggregations
--           so they calculate from daily SUMs (like weekly/monthly do)
--
-- IMPORTANT: Exclude bedtime/waketime from generic rollups
--            They use value_time (TIME type) and need special handling
-- =====================================================

BEGIN;

-- =====================================================
-- Step 1: Add missing period configurations
-- =====================================================

-- Add 6month and yearly to all aggregation metrics that have weekly/monthly
-- EXCEPT bedtime/waketime (they're handled separately)
INSERT INTO aggregation_metrics_periods (agg_metric_id, period_id)
SELECT DISTINCT agg_metric_id, '6month'
FROM aggregation_metrics_periods
WHERE period_id = 'monthly'
  AND agg_metric_id NOT IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
  AND NOT EXISTS (
    SELECT 1 FROM aggregation_metrics_periods amp2
    WHERE amp2.agg_metric_id = aggregation_metrics_periods.agg_metric_id
    AND amp2.period_id = '6month'
  );

INSERT INTO aggregation_metrics_periods (agg_metric_id, period_id)
SELECT DISTINCT agg_metric_id, 'yearly'
FROM aggregation_metrics_periods
WHERE period_id = 'monthly'
  AND agg_metric_id NOT IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
  AND NOT EXISTS (
    SELECT 1 FROM aggregation_metrics_periods amp2
    WHERE amp2.agg_metric_id = aggregation_metrics_periods.agg_metric_id
    AND amp2.period_id = 'yearly'
  );

-- Add 6month and yearly for bedtime/waketime separately
INSERT INTO aggregation_metrics_periods (agg_metric_id, period_id)
SELECT DISTINCT agg_metric_id, '6month'
FROM aggregation_metrics_periods
WHERE agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
  AND period_id = 'monthly'
  AND NOT EXISTS (
    SELECT 1 FROM aggregation_metrics_periods amp2
    WHERE amp2.agg_metric_id = aggregation_metrics_periods.agg_metric_id
    AND amp2.period_id = '6month'
  );

INSERT INTO aggregation_metrics_periods (agg_metric_id, period_id)
SELECT DISTINCT agg_metric_id, 'yearly'
FROM aggregation_metrics_periods
WHERE agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
  AND period_id = 'monthly'
  AND NOT EXISTS (
    SELECT 1 FROM aggregation_metrics_periods amp2
    WHERE amp2.agg_metric_id = aggregation_metrics_periods.agg_metric_id
    AND amp2.period_id = 'yearly'
  );

-- =====================================================
-- Step 2: Update process_rollup_aggregations
-- =====================================================

CREATE OR REPLACE FUNCTION process_rollup_aggregations(
  p_patient_id uuid,
  p_agg_metric_id text,
  p_entry_date date
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_period record;
BEGIN
  -- Handle bedtime/waketime rollups (TIME-based)
  -- These read directly from patient_data_entries and average the TIME portion
  -- Timestamps are stored in UTC, so we convert to local timezone first, then extract time
  IF p_agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME') THEN
    DECLARE
      v_output_field text;
      v_period record;
    BEGIN
      -- Determine which OUTPUT field to use
      v_output_field := CASE
        WHEN p_agg_metric_id = 'AGG_SLEEP_BEDTIME' THEN 'OUTPUT_SLEEP_BEDTIME'
        WHEN p_agg_metric_id = 'AGG_SLEEP_WAKETIME' THEN 'OUTPUT_SLEEP_WAKETIME'
      END;

      -- Weekly rollup: Average TIME from OUTPUT timestamps
      -- Convert UTC timestamp to local time, then extract time portion
      -- Process ALL weeks for this patient, not just one
      FOR v_period IN
        WITH daily_times AS (
          SELECT
            entry_date,
            value_timestamp AT TIME ZONE 'America/Los_Angeles' as local_timestamp
          FROM patient_data_entries
          WHERE patient_id = p_patient_id
            AND field_id = v_output_field
            AND value_timestamp IS NOT NULL
        )
        SELECT
          DATE_TRUNC('week', entry_date::timestamp)::date as week_start,
          (DATE_TRUNC('week', entry_date::timestamp) + INTERVAL '6 days')::date as week_end,
          (INTERVAL '1 second' * AVG(EXTRACT(EPOCH FROM local_timestamp::time)))::time as avg_time,
          COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) as day_count
        FROM daily_times
        GROUP BY DATE_TRUNC('week', entry_date::timestamp)
        HAVING COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) > 0
      LOOP
        INSERT INTO aggregation_results_cache (
          patient_id, agg_metric_id, period_type, calculation_type_id,
          period_start, period_end, value_time, data_points_count, last_computed_at
        )
        VALUES (
          p_patient_id, p_agg_metric_id, 'weekly', 'AVG',
          v_period.week_start, v_period.week_end,
          v_period.avg_time, v_period.day_count, NOW()
        )
        ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
        DO UPDATE SET
          value_time = EXCLUDED.value_time,
          data_points_count = EXCLUDED.data_points_count,
          last_computed_at = NOW();
      END LOOP;

      -- Monthly rollup: Average TIME from OUTPUT timestamps
      -- Convert UTC timestamp to local time, then extract time portion
      -- Process ALL months for this patient, not just one
      FOR v_period IN
        WITH daily_times AS (
          SELECT
            entry_date,
            value_timestamp AT TIME ZONE 'America/Los_Angeles' as local_timestamp
          FROM patient_data_entries
          WHERE patient_id = p_patient_id
            AND field_id = v_output_field
            AND value_timestamp IS NOT NULL
        )
        SELECT
          DATE_TRUNC('month', entry_date::timestamp)::date as month_start,
          (DATE_TRUNC('month', entry_date::timestamp) + INTERVAL '1 month - 1 day')::date as month_end,
          (INTERVAL '1 second' * AVG(EXTRACT(EPOCH FROM local_timestamp::time)))::time as avg_time,
          COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) as day_count
        FROM daily_times
        GROUP BY DATE_TRUNC('month', entry_date::timestamp)
        HAVING COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) > 0
      LOOP
        INSERT INTO aggregation_results_cache (
          patient_id, agg_metric_id, period_type, calculation_type_id,
          period_start, period_end, value_time, data_points_count, last_computed_at
        )
        VALUES (
          p_patient_id, p_agg_metric_id, 'monthly', 'AVG',
          v_period.month_start, v_period.month_end,
          v_period.avg_time, v_period.day_count, NOW()
        )
        ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
        DO UPDATE SET
          value_time = EXCLUDED.value_time,
          data_points_count = EXCLUDED.data_points_count,
          last_computed_at = NOW();
      END LOOP;

      -- 6month rollup: Average TIME from OUTPUT timestamps
      -- Convert UTC timestamp to local time, then extract time portion
      FOR v_period IN
        WITH daily_times AS (
          SELECT
            entry_date,
            value_timestamp AT TIME ZONE 'America/Los_Angeles' as local_timestamp
          FROM patient_data_entries
          WHERE patient_id = p_patient_id
            AND field_id = v_output_field
            AND value_timestamp IS NOT NULL
            AND entry_date >= (p_entry_date - INTERVAL '5 months')::date
            AND entry_date <= p_entry_date
        )
        SELECT
          (p_entry_date - INTERVAL '5 months')::date as period_start,
          p_entry_date as period_end,
          (INTERVAL '1 second' * AVG(EXTRACT(EPOCH FROM local_timestamp::time)))::time as avg_time,
          COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) as day_count
        FROM daily_times
        HAVING COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) > 0
      LOOP
        INSERT INTO aggregation_results_cache (
          patient_id, agg_metric_id, period_type, calculation_type_id,
          period_start, period_end, value_time, data_points_count, last_computed_at
        )
        VALUES (
          p_patient_id, p_agg_metric_id, '6month', 'AVG',
          v_period.period_start, v_period.period_end,
          v_period.avg_time, v_period.day_count, NOW()
        )
        ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
        DO UPDATE SET
          value_time = EXCLUDED.value_time,
          data_points_count = EXCLUDED.data_points_count,
          last_computed_at = NOW();
      END LOOP;

      -- Yearly rollup: Average TIME from OUTPUT timestamps
      -- Convert UTC timestamp to local time, then extract time portion
      -- Process ALL years for this patient, not just one
      FOR v_period IN
        WITH daily_times AS (
          SELECT
            entry_date,
            value_timestamp AT TIME ZONE 'America/Los_Angeles' as local_timestamp
          FROM patient_data_entries
          WHERE patient_id = p_patient_id
            AND field_id = v_output_field
            AND value_timestamp IS NOT NULL
        )
        SELECT
          DATE_TRUNC('year', entry_date::timestamp)::date as year_start,
          (DATE_TRUNC('year', entry_date::timestamp) + INTERVAL '1 year - 1 day')::date as year_end,
          (INTERVAL '1 second' * AVG(EXTRACT(EPOCH FROM local_timestamp::time)))::time as avg_time,
          COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) as day_count
        FROM daily_times
        GROUP BY DATE_TRUNC('year', entry_date::timestamp)
        HAVING COUNT(*) FILTER (WHERE local_timestamp IS NOT NULL) > 0
      LOOP
        INSERT INTO aggregation_results_cache (
          patient_id, agg_metric_id, period_type, calculation_type_id,
          period_start, period_end, value_time, data_points_count, last_computed_at
        )
        VALUES (
          p_patient_id, p_agg_metric_id, 'yearly', 'AVG',
          v_period.year_start, v_period.year_end,
          v_period.avg_time, v_period.day_count, NOW()
        )
        ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
        DO UPDATE SET
          value_time = EXCLUDED.value_time,
          data_points_count = EXCLUDED.data_points_count,
          last_computed_at = NOW();
      END LOOP;
    END;
    
    RETURN; -- Exit early after handling bedtime/waketime
  END IF;

  -- =====================================================
  -- Generic numeric rollups (EXCLUDES bedtime/waketime)
  -- =====================================================
  
  -- Calculate weekly rollup from daily SUM
  -- Process ALL weeks for this patient (not just one week)
  -- Use SUM(value) / COUNT(DISTINCT period_start) to ensure we divide by days, not entries
  -- First, get unique daily sums (take most recent if duplicates exist)
  FOR v_period IN
    WITH unique_daily_sums AS (
      SELECT DISTINCT ON (patient_id, agg_metric_id, period_start)
        period_start,
        value
      FROM aggregation_results_cache
      WHERE patient_id = p_patient_id
        AND agg_metric_id = p_agg_metric_id
        AND period_type = 'daily'
        AND calculation_type_id = 'SUM'
        AND value IS NOT NULL
      ORDER BY patient_id, agg_metric_id, period_start, last_computed_at DESC
    )
    SELECT
      DATE_TRUNC('week', period_start)::date as week_start,
      (DATE_TRUNC('week', period_start) + INTERVAL '6 days')::date as week_end,
      SUM(value) as total_sum,
      COUNT(*) as day_count,
      SUM(value) / NULLIF(COUNT(*), 0) as avg_value
    FROM unique_daily_sums
    GROUP BY DATE_TRUNC('week', period_start)
    HAVING COUNT(*) > 0
  LOOP
    INSERT INTO aggregation_results_cache (
      patient_id, agg_metric_id, period_type, calculation_type_id,
      period_start, period_end, value, data_points_count, last_computed_at
    )
    VALUES (
      p_patient_id, p_agg_metric_id, 'weekly', 'AVG',
      v_period.week_start, v_period.week_end,
      v_period.avg_value, v_period.day_count, NOW()
    )
    ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
    DO UPDATE SET
      value = EXCLUDED.value,
      data_points_count = EXCLUDED.data_points_count,
      last_computed_at = NOW();
  END LOOP;

  -- Calculate monthly rollup from daily SUM
  -- Process ALL months for this patient (not just one month)
  -- Use SUM(value) / COUNT(*) to ensure we divide by days, not entries
  FOR v_period IN
    WITH unique_daily_sums AS (
      SELECT DISTINCT ON (patient_id, agg_metric_id, period_start)
        period_start,
        value
      FROM aggregation_results_cache
      WHERE patient_id = p_patient_id
        AND agg_metric_id = p_agg_metric_id
        AND period_type = 'daily'
        AND calculation_type_id = 'SUM'
        AND value IS NOT NULL
      ORDER BY patient_id, agg_metric_id, period_start, last_computed_at DESC
    )
    SELECT
      DATE_TRUNC('month', period_start)::date as month_start,
      (DATE_TRUNC('month', period_start) + INTERVAL '1 month - 1 day')::date as month_end,
      SUM(value) as total_sum,
      COUNT(*) as day_count,
      SUM(value) / NULLIF(COUNT(*), 0) as avg_value
    FROM unique_daily_sums
    GROUP BY DATE_TRUNC('month', period_start)
    HAVING COUNT(*) > 0
  LOOP
    INSERT INTO aggregation_results_cache (
      patient_id, agg_metric_id, period_type, calculation_type_id,
      period_start, period_end, value, data_points_count, last_computed_at
    )
    VALUES (
      p_patient_id, p_agg_metric_id, 'monthly', 'AVG',
      v_period.month_start, v_period.month_end,
      v_period.avg_value, v_period.day_count, NOW()
    )
    ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
    DO UPDATE SET
      value = EXCLUDED.value,
      data_points_count = EXCLUDED.data_points_count,
      last_computed_at = NOW();
  END LOOP;

  -- Calculate 6month rollup from daily SUM
  -- Use SUM(value) / COUNT(*) to ensure we divide by days, not entries
  FOR v_period IN
    WITH unique_daily_sums AS (
      SELECT DISTINCT ON (patient_id, agg_metric_id, period_start)
        period_start,
        value
      FROM aggregation_results_cache
      WHERE patient_id = p_patient_id
        AND agg_metric_id = p_agg_metric_id
        AND period_type = 'daily'
        AND calculation_type_id = 'SUM'
        AND value IS NOT NULL
        AND period_start >= (p_entry_date - INTERVAL '5 months')::date
        AND period_start <= p_entry_date
      ORDER BY patient_id, agg_metric_id, period_start, last_computed_at DESC
    )
    SELECT
      (p_entry_date - INTERVAL '5 months')::date as period_start,
      p_entry_date as period_end,
      SUM(value) as total_sum,
      COUNT(*) as day_count,
      SUM(value) / NULLIF(COUNT(*), 0) as avg_value
    FROM unique_daily_sums
    HAVING COUNT(*) > 0
  LOOP
    INSERT INTO aggregation_results_cache (
      patient_id, agg_metric_id, period_type, calculation_type_id,
      period_start, period_end, value, data_points_count, last_computed_at
    )
    VALUES (
      p_patient_id, p_agg_metric_id, '6month', 'AVG',
      v_period.period_start, v_period.period_end,
      v_period.avg_value, v_period.day_count, NOW()
    )
    ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
    DO UPDATE SET
      value = EXCLUDED.value,
      data_points_count = EXCLUDED.data_points_count,
      last_computed_at = NOW();
  END LOOP;

  -- Calculate yearly rollup from daily SUM
  -- Process ALL years for this patient (not just one year)
  -- Use SUM(value) / COUNT(*) to ensure we divide by days, not entries
  FOR v_period IN
    WITH unique_daily_sums AS (
      SELECT DISTINCT ON (patient_id, agg_metric_id, period_start)
        period_start,
        value
      FROM aggregation_results_cache
      WHERE patient_id = p_patient_id
        AND agg_metric_id = p_agg_metric_id
        AND period_type = 'daily'
        AND calculation_type_id = 'SUM'
        AND value IS NOT NULL
      ORDER BY patient_id, agg_metric_id, period_start, last_computed_at DESC
    )
    SELECT
      DATE_TRUNC('year', period_start)::date as year_start,
      (DATE_TRUNC('year', period_start) + INTERVAL '1 year - 1 day')::date as year_end,
      SUM(value) as total_sum,
      COUNT(*) as day_count,
      SUM(value) / NULLIF(COUNT(*), 0) as avg_value
    FROM unique_daily_sums
    GROUP BY DATE_TRUNC('year', period_start)
    HAVING COUNT(*) > 0
  LOOP
    INSERT INTO aggregation_results_cache (
      patient_id, agg_metric_id, period_type, calculation_type_id,
      period_start, period_end, value, data_points_count, last_computed_at
    )
    VALUES (
      p_patient_id, p_agg_metric_id, 'yearly', 'AVG',
      v_period.year_start, v_period.year_end,
      v_period.avg_value, v_period.day_count, NOW()
    )
    ON CONFLICT (patient_id, agg_metric_id, period_type, calculation_type_id, period_start)
    DO UPDATE SET
      value = EXCLUDED.value,
      data_points_count = EXCLUDED.data_points_count,
      last_computed_at = NOW();
  END LOOP;

END;
$$;

COMMENT ON FUNCTION process_rollup_aggregations IS
'Aggregates weekly/monthly/6month/yearly from daily cache values or OUTPUT timestamps.
- Numeric metrics: Uses daily SUM from cache, averages for rollups.
- Bedtime/Waketime: Reads directly from patient_data_entries, extracts TIME portion, averages TIME values.
  This avoids dependency on daily aggregations and works with absolute time values (no timezone conversion).';

-- =====================================================
-- Step 3: Update process_all_sleep_aggregations
-- =====================================================
-- This function processes all sleep aggregations including bedtime/waketime.
-- Bedtime/waketime rollups read directly from OUTPUT timestamps (no daily cache needed).
--

CREATE OR REPLACE FUNCTION process_all_sleep_aggregations(
  p_patient_id uuid,
  p_start_date date,
  p_end_date date
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_date date;
  v_processed_count int := 0;
BEGIN
  -- Process each date in range
  FOR v_date IN 
    SELECT generate_series(p_start_date, p_end_date, '1 day'::interval)::date
  LOOP
    -- Process all sleep-related fields for this date
    PERFORM process_field_aggregations(p_patient_id, 'OUTPUT_SLEEP_DURATION', v_date);
    PERFORM process_field_aggregations(p_patient_id, 'OUTPUT_TIME_IN_BED', v_date);
    PERFORM process_field_aggregations(p_patient_id, 'OUTPUT_SLEEP_PERIOD_DURATION', v_date);
    
    -- Process rollups for bedtime/waketime (creates weekly/monthly/6month/yearly directly from OUTPUT timestamps)
    PERFORM process_rollup_aggregations(p_patient_id, 'AGG_SLEEP_BEDTIME', v_date);
    PERFORM process_rollup_aggregations(p_patient_id, 'AGG_SLEEP_WAKETIME', v_date);
    
    v_processed_count := v_processed_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'dates_processed', v_processed_count,
    'start_date', p_start_date,
    'end_date', p_end_date
  );
END;
$$;

COMMENT ON FUNCTION process_all_sleep_aggregations IS
'Processes sleep aggregations for a date range.
Called by edge function webhook when sleep data is inserted.
- Creates daily aggregations for numeric sleep fields (duration, time_in_bed)
- Creates weekly/monthly/6month/yearly rollups for all sleep metrics
- Bedtime/waketime rollups read directly from OUTPUT timestamps (no daily cache dependency)
- Returns JSON with processed dates count';

COMMIT;

