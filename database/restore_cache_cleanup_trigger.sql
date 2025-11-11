-- Restore Cache Cleanup Trigger
-- This trigger function invalidates aggregation_results_cache entries
-- when their source data from patient_data_entries is deleted
-- Created: 2025-11-05

-- =====================================================
-- Step 1: Create the trigger function
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_aggregation_cache_on_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Invalidate cache entries that depended on this specific row
  -- This handles both direct dependencies and rollup dependencies
  -- SECURITY DEFINER allows the function to bypass RLS when deleting cache entries
  
  -- 1. Delete daily cache entries for the specific date
  DELETE FROM aggregation_results_cache arc
  WHERE arc.patient_id = OLD.patient_id
    AND arc.period_type = 'daily'
    AND arc.period_start::date = OLD.entry_date::date
    AND (
      -- Direct dependency via aggregation_metrics_dependencies
      EXISTS (
        SELECT 1 FROM aggregation_metrics_dependencies amd
        WHERE amd.agg_metric_id = arc.agg_metric_id
          AND amd.data_entry_field_id = OLD.field_id
      )
      -- OR special case: bedtime/waketime read directly from patient_data_entries
      OR (
        arc.agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
        AND OLD.field_id IN ('OUTPUT_SLEEP_BEDTIME', 'OUTPUT_SLEEP_WAKETIME')
      )
    );

  -- 2. Delete weekly cache entries that include this date
  DELETE FROM aggregation_results_cache arc
  WHERE arc.patient_id = OLD.patient_id
    AND arc.period_type = 'weekly'
    AND OLD.entry_date::date >= arc.period_start::date
    AND (arc.period_end IS NULL OR OLD.entry_date::date < arc.period_end::date)
    AND (
      EXISTS (
        SELECT 1 FROM aggregation_metrics_dependencies amd
        WHERE amd.agg_metric_id = arc.agg_metric_id
          AND amd.data_entry_field_id = OLD.field_id
      )
      OR (
        arc.agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
        AND OLD.field_id IN ('OUTPUT_SLEEP_BEDTIME', 'OUTPUT_SLEEP_WAKETIME')
      )
    );

  -- 3. Delete monthly cache entries that include this date
  DELETE FROM aggregation_results_cache arc
  WHERE arc.patient_id = OLD.patient_id
    AND arc.period_type = 'monthly'
    AND OLD.entry_date::date >= arc.period_start::date
    AND (arc.period_end IS NULL OR OLD.entry_date::date < arc.period_end::date)
    AND (
      EXISTS (
        SELECT 1 FROM aggregation_metrics_dependencies amd
        WHERE amd.agg_metric_id = arc.agg_metric_id
          AND amd.data_entry_field_id = OLD.field_id
      )
      OR (
        arc.agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
        AND OLD.field_id IN ('OUTPUT_SLEEP_BEDTIME', 'OUTPUT_SLEEP_WAKETIME')
      )
    );

  -- 4. Delete 6month cache entries that include this date
  DELETE FROM aggregation_results_cache arc
  WHERE arc.patient_id = OLD.patient_id
    AND arc.period_type = '6month'
    AND OLD.entry_date::date >= arc.period_start::date
    AND (arc.period_end IS NULL OR OLD.entry_date::date < arc.period_end::date)
    AND (
      EXISTS (
        SELECT 1 FROM aggregation_metrics_dependencies amd
        WHERE amd.agg_metric_id = arc.agg_metric_id
          AND amd.data_entry_field_id = OLD.field_id
      )
      OR (
        arc.agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
        AND OLD.field_id IN ('OUTPUT_SLEEP_BEDTIME', 'OUTPUT_SLEEP_WAKETIME')
      )
    );

  -- 5. Delete yearly cache entries that include this date
  DELETE FROM aggregation_results_cache arc
  WHERE arc.patient_id = OLD.patient_id
    AND arc.period_type = 'yearly'
    AND OLD.entry_date::date >= arc.period_start::date
    AND (arc.period_end IS NULL OR OLD.entry_date::date < arc.period_end::date)
    AND (
      EXISTS (
        SELECT 1 FROM aggregation_metrics_dependencies amd
        WHERE amd.agg_metric_id = arc.agg_metric_id
          AND amd.data_entry_field_id = OLD.field_id
      )
      OR (
        arc.agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME')
        AND OLD.field_id IN ('OUTPUT_SLEEP_BEDTIME', 'OUTPUT_SLEEP_WAKETIME')
      )
    );

  RETURN OLD;
END;
$$;

-- =====================================================
-- Step 2: Create the trigger
-- =====================================================

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS trigger_cleanup_aggregation_cache_on_delete ON patient_data_entries;

-- Create the trigger
CREATE TRIGGER trigger_cleanup_aggregation_cache_on_delete
  AFTER DELETE ON patient_data_entries
  FOR EACH ROW
  EXECUTE FUNCTION cleanup_aggregation_cache_on_delete();

-- =====================================================
-- Step 3: Add comment
-- =====================================================

COMMENT ON FUNCTION cleanup_aggregation_cache_on_delete() IS
'Cleans up aggregation_results_cache entries when source data from patient_data_entries is deleted.
Handles all period types (daily, weekly, monthly, 6month, yearly) and special cases like bedtime/waketime.
Only deletes cache entries for the specific patient and metric that depend on the deleted data.';

COMMIT;

