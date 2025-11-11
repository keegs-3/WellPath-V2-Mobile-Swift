-- Steps Metric Configuration
-- Complete database setup for Steps tracking
-- Created: 2025-11-05

-- ============================================================
-- 1. DATA ENTRY FIELD REFERENCE
-- ============================================================

INSERT INTO data_entry_fields_reference (
    field_id, field_name, data_type, unit_id, category, display_order
) VALUES (
    'DEF_STEP_COUNT', 'Step Count', 'integer', 'count', 'activity', 1
) ON CONFLICT (field_id) DO NOTHING;

-- ============================================================
-- 2. DISPLAY METRICS
-- ============================================================

INSERT INTO display_metrics (
    metric_id, metric_name, description, pillar,
    chart_type_id, unit_id, is_primary, is_active,
    about_content, longevity_impact, quick_tips
) VALUES (
    'DISP_STEPS',
    'Daily Steps',
    'Track your daily step count to monitor movement and activity levels',
    'Movement',
    'bar_vertical',
    'count',
    true,
    true,
    'Walking is one of the simplest and most effective forms of physical activity. Daily step counts provide insight into your overall movement patterns and can help identify opportunities to increase activity throughout the day.',
    'Regular walking and achieving daily step goals has been associated with reduced cardiovascular risk, improved metabolic health, better mood, and increased longevity. Studies suggest that even modest increases in daily steps can provide significant health benefits.',
    ARRAY[
        'Aim for 8,000-10,000 steps per day for optimal health benefits',
        'Break up long periods of sitting with short walking breaks',
        'Take the stairs instead of the elevator when possible',
        'Park farther away to add extra steps to your day',
        'Walk during phone calls or meetings when appropriate',
        'Use a fitness tracker or smartphone to monitor progress'
    ]
) ON CONFLICT (metric_id) DO NOTHING;

-- ============================================================
-- 3. AGGREGATION METRICS
-- ============================================================

INSERT INTO aggregation_metrics (
    agg_metric_id, metric_name, source_type, source_reference, unit_id
) VALUES
    ('AGG_STEPS_HOURLY', 'Hourly Steps', 'data_entry_field', 'DEF_STEP_COUNT', 'count'),
    ('AGG_STEPS_DAILY', 'Daily Steps', 'data_entry_field', 'DEF_STEP_COUNT', 'count'),
    ('AGG_STEPS_WEEKLY', 'Weekly Steps', 'data_entry_field', 'DEF_STEP_COUNT', 'count'),
    ('AGG_STEPS_MONTHLY', 'Monthly Steps', 'data_entry_field', 'DEF_STEP_COUNT', 'count')
ON CONFLICT (agg_metric_id) DO NOTHING;

-- ============================================================
-- 4. LINK AGGREGATION METRICS TO DATA ENTRY FIELDS
-- ============================================================

INSERT INTO aggregation_metrics_data_entry_fields (
    aggregation_metric_id, data_entry_field_id
) VALUES
    ('AGG_STEPS_HOURLY', 'DEF_STEP_COUNT'),
    ('AGG_STEPS_DAILY', 'DEF_STEP_COUNT'),
    ('AGG_STEPS_WEEKLY', 'DEF_STEP_COUNT'),
    ('AGG_STEPS_MONTHLY', 'DEF_STEP_COUNT')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. DISPLAY METRICS AGGREGATIONS (Links display → agg metrics)
-- ============================================================

INSERT INTO display_metrics_aggregations (
    metric_id, agg_metric_id, period_type, calculation_type_id, display_order
) VALUES
    -- Daily view: Show hourly sums
    ('DISP_STEPS', 'AGG_STEPS_HOURLY', 'daily', 'SUM', 1),
    -- Weekly view: Show daily averages
    ('DISP_STEPS', 'AGG_STEPS_DAILY', 'weekly', 'AVG', 1),
    -- Monthly view: Show daily averages
    ('DISP_STEPS', 'AGG_STEPS_DAILY', 'monthly', 'AVG', 1),
    -- 6-Month view: Show weekly averages
    ('DISP_STEPS', 'AGG_STEPS_WEEKLY', 'sixMonth', 'AVG', 1),
    -- Yearly view: Show monthly averages
    ('DISP_STEPS', 'AGG_STEPS_MONTHLY', 'yearly', 'AVG', 1)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. DISPLAY SCREENS
-- ============================================================

INSERT INTO display_screens (
    screen_id, screen_name, pillar_id, display_order, is_active
) VALUES (
    'SCREEN_STEPS',
    'Steps',
    (SELECT pillar_id FROM pillars WHERE pillar_name = 'Movement'),
    1,
    true
) ON CONFLICT (screen_id) DO NOTHING;

-- ============================================================
-- 7. LINK SCREEN TO METRICS
-- ============================================================

INSERT INTO display_screens_primary_display_metrics (
    screen_id, metric_id, display_order
) VALUES (
    'SCREEN_STEPS', 'DISP_STEPS', 1
) ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. VERIFICATION QUERIES
-- ============================================================

-- Verify display metric
SELECT metric_id, metric_name, pillar, chart_type_id
FROM display_metrics
WHERE metric_id = 'DISP_STEPS';

-- Verify aggregation metrics
SELECT agg_metric_id, metric_name, source_reference
FROM aggregation_metrics
WHERE agg_metric_id LIKE 'AGG_STEPS%';

-- Verify display → aggregation linkages
SELECT dma.metric_id, dma.agg_metric_id, dma.period_type, dma.calculation_type_id
FROM display_metrics_aggregations dma
WHERE dma.metric_id = 'DISP_STEPS'
ORDER BY dma.period_type, dma.display_order;

-- Verify screen configuration
SELECT ds.screen_id, ds.screen_name, dspdm.metric_id, dm.metric_name
FROM display_screens ds
JOIN display_screens_primary_display_metrics dspdm ON ds.screen_id = dspdm.screen_id
JOIN display_metrics dm ON dspdm.metric_id = dm.metric_id
WHERE ds.screen_id = 'SCREEN_STEPS';
