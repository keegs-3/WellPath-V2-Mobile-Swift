-- Sleep Metrics Aggregation Linkages
-- Links display metrics to their aggregation metrics for querying aggregation_results_cache
-- Created: 2025-11-05

-- ============================================================
-- 1. DISP_SLEEP_ANALYSIS (Primary Screen)
-- ============================================================

-- Sleep Duration (Total)
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order)
VALUES
    ('DISP_SLEEP_ANALYSIS', 'AGG_SLEEP_DURATION', 'daily', 'SUM', 1),
    ('DISP_SLEEP_ANALYSIS', 'AGG_SLEEP_DURATION', 'weekly', 'AVG', 1),
    ('DISP_SLEEP_ANALYSIS', 'AGG_SLEEP_DURATION', 'monthly', 'AVG', 1);

-- Awake Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order)
VALUES
    ('DISP_SLEEP_ANALYSIS', 'AGG_AWAKE_DURATION', 'daily', 'SUM', 2),
    ('DISP_SLEEP_ANALYSIS', 'AGG_AWAKE_DURATION', 'weekly', 'AVG', 2),
    ('DISP_SLEEP_ANALYSIS', 'AGG_AWAKE_DURATION', 'monthly', 'AVG', 2);

-- REM Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order)
VALUES
    ('DISP_SLEEP_ANALYSIS', 'AGG_REM_SLEEP_DURATION', 'daily', 'SUM', 3),
    ('DISP_SLEEP_ANALYSIS', 'AGG_REM_SLEEP_DURATION', 'weekly', 'AVG', 3),
    ('DISP_SLEEP_ANALYSIS', 'AGG_REM_SLEEP_DURATION', 'monthly', 'AVG', 3);

-- Core Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order)
VALUES
    ('DISP_SLEEP_ANALYSIS', 'AGG_CORE_SLEEP_DURATION', 'daily', 'SUM', 4),
    ('DISP_SLEEP_ANALYSIS', 'AGG_CORE_SLEEP_DURATION', 'weekly', 'AVG', 4),
    ('DISP_SLEEP_ANALYSIS', 'AGG_CORE_SLEEP_DURATION', 'monthly', 'AVG', 4);

-- Deep Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order)
VALUES
    ('DISP_SLEEP_ANALYSIS', 'AGG_DEEP_SLEEP_DURATION', 'daily', 'SUM', 5),
    ('DISP_SLEEP_ANALYSIS', 'AGG_DEEP_SLEEP_DURATION', 'weekly', 'AVG', 5),
    ('DISP_SLEEP_ANALYSIS', 'AGG_DEEP_SLEEP_DURATION', 'monthly', 'AVG', 5);

-- ============================================================
-- 2. DISP_SLEEP_ANALYSIS_AMOUNTS (Detail Screen - Amounts Tab)
-- ============================================================

-- Awake Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_AWAKE_DURATION', 'daily', 'SUM', 1, 'Awake', '#FF6B6B'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_AWAKE_DURATION', 'weekly', 'AVG', 1, 'Awake', '#FF6B6B'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_AWAKE_DURATION', 'monthly', 'AVG', 1, 'Awake', '#FF6B6B');

-- REM Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_REM_SLEEP_DURATION', 'daily', 'SUM', 2, 'REM', '#4ECDC4'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_REM_SLEEP_DURATION', 'weekly', 'AVG', 2, 'REM', '#4ECDC4'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_REM_SLEEP_DURATION', 'monthly', 'AVG', 2, 'REM', '#4ECDC4');

-- Core Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_CORE_SLEEP_DURATION', 'daily', 'SUM', 3, 'Core', '#5B7FDB'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_CORE_SLEEP_DURATION', 'weekly', 'AVG', 3, 'Core', '#5B7FDB'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_CORE_SLEEP_DURATION', 'monthly', 'AVG', 3, 'Core', '#5B7FDB');

-- Deep Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_DEEP_SLEEP_DURATION', 'daily', 'SUM', 4, 'Deep', '#1E3A8A'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_DEEP_SLEEP_DURATION', 'weekly', 'AVG', 4, 'Deep', '#1E3A8A'),
    ('DISP_SLEEP_ANALYSIS_AMOUNTS', 'AGG_DEEP_SLEEP_DURATION', 'monthly', 'AVG', 4, 'Deep', '#1E3A8A');

-- ============================================================
-- 3. DISP_SLEEP_ANALYSIS_PERCENTAGES (Detail Screen - Percentages Tab)
-- ============================================================

-- Awake Duration (for percentage calculation)
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_AWAKE_DURATION', 'daily', 'SUM', 1, 'Awake', '#FF6B6B'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_AWAKE_DURATION', 'weekly', 'AVG', 1, 'Awake', '#FF6B6B'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_AWAKE_DURATION', 'monthly', 'AVG', 1, 'Awake', '#FF6B6B');

-- REM Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_REM_SLEEP_DURATION', 'daily', 'SUM', 2, 'REM', '#4ECDC4'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_REM_SLEEP_DURATION', 'weekly', 'AVG', 2, 'REM', '#4ECDC4'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_REM_SLEEP_DURATION', 'monthly', 'AVG', 2, 'REM', '#4ECDC4');

-- Core Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_CORE_SLEEP_DURATION', 'daily', 'SUM', 3, 'Core', '#5B7FDB'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_CORE_SLEEP_DURATION', 'weekly', 'AVG', 3, 'Core', '#5B7FDB'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_CORE_SLEEP_DURATION', 'monthly', 'AVG', 3, 'Core', '#5B7FDB');

-- Deep Sleep Duration
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order, series_label, series_color)
VALUES
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_DEEP_SLEEP_DURATION', 'daily', 'SUM', 4, 'Deep', '#1E3A8A'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_DEEP_SLEEP_DURATION', 'weekly', 'AVG', 4, 'Deep', '#1E3A8A'),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_DEEP_SLEEP_DURATION', 'monthly', 'AVG', 4, 'Deep', '#1E3A8A');

-- Pre-calculated percentages (optional, for efficiency)
INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order)
VALUES
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_REM_PERCENTAGE', 'daily', 'AVG', 5),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_REM_PERCENTAGE', 'weekly', 'AVG', 5),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_REM_PERCENTAGE', 'monthly', 'AVG', 5),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_CORE_PERCENTAGE', 'daily', 'AVG', 6),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_CORE_PERCENTAGE', 'weekly', 'AVG', 6),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_CORE_PERCENTAGE', 'monthly', 'AVG', 6),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_DEEP_PERCENTAGE', 'daily', 'AVG', 7),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_DEEP_PERCENTAGE', 'weekly', 'AVG', 7),
    ('DISP_SLEEP_ANALYSIS_PERCENTAGES', 'AGG_DEEP_PERCENTAGE', 'monthly', 'AVG', 7);

-- ============================================================
-- 4. DISP_SLEEP_DURATION (Add daily AVG)
-- ============================================================

-- Check what already exists
-- We'll add daily AVG if not present

INSERT INTO display_metrics_aggregations (metric_id, agg_metric_id, period_type, calculation_type_id, display_order)
VALUES
    ('DISP_SLEEP_DURATION', 'AGG_SLEEP_DURATION', 'daily', 'AVG', 1)
ON CONFLICT DO NOTHING;

-- Verify results
SELECT
    metric_id,
    agg_metric_id,
    period_type,
    calculation_type_id,
    series_label,
    display_order
FROM display_metrics_aggregations
WHERE metric_id IN (
    'DISP_SLEEP_ANALYSIS',
    'DISP_SLEEP_ANALYSIS_AMOUNTS',
    'DISP_SLEEP_ANALYSIS_PERCENTAGES',
    'DISP_SLEEP_DURATION'
)
ORDER BY metric_id, display_order, period_type;
