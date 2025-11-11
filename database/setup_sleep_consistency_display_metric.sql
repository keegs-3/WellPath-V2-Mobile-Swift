-- Sleep Consistency Display Metric Configuration
-- Setup display metric for Sleep Consistency (primary screen)
-- Created: 2025-11-05

-- ============================================================
-- 1. DISPLAY METRIC
-- ============================================================

INSERT INTO display_metrics (
    metric_id, metric_name, description, pillar,
    chart_type_id, is_primary, is_active,
    about_content, longevity_impact, quick_tips
) VALUES (
    'DISP_SLEEP_CONSISTENCY',
    'Sleep Consistency',
    'Track the consistency of your sleep and wake times to optimize your circadian rhythm',
    'Restorative Sleep',
    NULL,  -- Custom chart implementation in SleepConsistencyPrimary
    true,
    true,
    'Sleep consistency refers to the regularity of your bedtime and wake time across days and weeks. Your body operates on a circadian rhythm—an internal 24-hour clock that regulates sleep-wake cycles, hormone release, body temperature, and metabolism. Consistent sleep timing strengthens this rhythm, making it easier to fall asleep, stay asleep, and wake feeling refreshed. The Sleep Consistency view visualizes your bedtime and waketime patterns over time, highlighting the ±30 minute consistency bands that represent optimal circadian alignment.

When you go to bed and wake up at consistent times, your body anticipates these transitions and optimizes its processes accordingly. Melatonin production begins ramping up before your typical bedtime, core body temperature drops, and adenosine (the sleep pressure molecule) accumulates on schedule. Upon waking, cortisol rises sharply to promote alertness. This synchronization enhances sleep quality, reduces sleep onset latency (time to fall asleep), and improves daytime function.

The consistency bands shown in the charts represent a ±30 minute window around your average sleep and wake times during the visible period. Sleep times that fall within these bands indicate strong circadian consistency. Times outside the bands suggest variability that may be disrupting your rhythm. By monitoring these patterns across daily (W/M views) and aggregated (6M/Y views) timeframes, you can identify inconsistencies and work toward more regular sleep schedules.',

    'Sleep consistency is one of the most powerful predictors of health outcomes, independent of sleep duration. Research from multiple large-scale studies demonstrates that irregular sleep-wake timing increases risk for cardiovascular disease, metabolic dysfunction, obesity, mood disorders, and all-cause mortality.

**Cardiovascular Health**: The UK Biobank study (n=88,026) found that irregular sleep patterns increased cardiovascular disease risk by 30% and all-cause mortality by 15%, even among those sleeping 7-9 hours nightly. Sleep variability of just 60-90 minutes between weekdays and weekends (social jet lag) correlates with hypertension, elevated inflammation markers (CRP, IL-6), and endothelial dysfunction—precursors to atherosclerosis.

**Metabolic Health**: Irregular sleep disrupts glucose metabolism and insulin sensitivity. A 2019 study in Diabetes Care showed that sleep timing variability increased diabetes risk by 44%, independent of sleep duration. Each hour of sleep variability was associated with higher fasting glucose, HbA1c, and HOMA-IR (insulin resistance). The mechanism involves circadian misalignment of pancreatic beta cells, which produce insulin according to anticipated meal timing.

**Cognitive Function**: Sleep consistency supports memory consolidation and cognitive performance. Variable sleep schedules fragment the ultradian cycles (90-minute sleep cycles containing deep and REM sleep), reducing time spent in restorative stages. A 2020 study in SLEEP found that students with irregular sleep patterns performed worse academically than peers with consistent schedules, even when total sleep time was identical.

**Mental Health**: Circadian disruption strongly correlates with depression, anxiety, and bipolar disorder. The NHANES study revealed that sleep variability greater than 2 hours predicted mood disorders independent of sleep duration, quality, or insomnia symptoms. Consistent sleep timing stabilizes mood-regulating neurotransmitters (serotonin, dopamine) and reduces HPA axis dysregulation (chronic stress response).

**Cellular Aging**: Recent research links sleep irregularity to accelerated biological aging. Telomere length (a marker of cellular age) is shorter in individuals with variable sleep patterns. Additionally, irregular sleep impairs autophagy—the cellular "housekeeping" process that removes damaged proteins and organelles, potentially accelerating neurodegenerative diseases like Alzheimer''s.

**The Social Jet Lag Effect**: Even modest inconsistency matters. Social jet lag—the difference between weekday and weekend sleep timing—affects 87% of adults to some degree. Just 1-2 hours of weekend "sleep catch-up" chronically disrupts circadian alignment, creating a perpetual state of jet lag without leaving your time zone. This drives metabolic syndrome, weight gain (especially visceral fat), and reduced insulin sensitivity.

**Optimal Consistency Targets**: Research suggests aiming for bedtime and wake time variability of <30 minutes across all days of the week. This means if your typical bedtime is 10:30 PM, staying within 10:00-11:00 PM consistently. For wake time, similar consistency is critical—sleeping in on weekends undermines the entire week''s rhythm. Studies show that maintaining 7-day consistency reduces cardiovascular risk by 23%, improves HRV (heart rate variability—a marker of autonomic nervous system health), and enhances deep sleep percentage.

Sleep consistency isn''t about rigid perfection—occasional variations are normal. But chronic variability >60 minutes, especially across weekday/weekend, measurably accelerates healthspan decline. Tracking and optimizing consistency may be the single most impactful sleep intervention for longevity.',

    '["Aim for ±30 minutes consistency in both bedtime and wake time across all 7 days", "Weekend sleep-ins create social jet lag—maintain weekday wake time on Sat/Sun", "If you must sleep in, limit it to +60 minutes max to minimize circadian disruption", "Set a consistent bedtime alarm, not just a wake alarm—consistency starts at night", "Prioritize consistent wake time first (harder to control bedtime with life demands)", "Track patterns over 2-4 weeks before making changes—short-term variability is normal", "Gradually shift sleep schedule by 15-30 min every few days, not abruptly", "Use the W/M views to spot daily patterns; 6M/Y views reveal long-term trends", "Bars within the consistency bands = good circadian alignment", "Bars outside bands = identify causes (stress, travel, social events) and address", "Morning light exposure (10-30 min within 1 hour of waking) reinforces consistency", "Avoid bright light and screens 2-3 hours before consistent bedtime", "If you travel across time zones, shift schedule gradually before trip", "Social commitments that disrupt sleep are OK occasionally—aim for 80% consistency", "Consider splitting the difference: if weekday wake = 6 AM, weekend = 7 AM, compromise at 6:30 AM daily"]'::jsonb
) ON CONFLICT (metric_id) DO UPDATE SET
    metric_name = EXCLUDED.metric_name,
    description = EXCLUDED.description,
    pillar = EXCLUDED.pillar,
    chart_type_id = EXCLUDED.chart_type_id,
    is_primary = EXCLUDED.is_primary,
    is_active = EXCLUDED.is_active,
    about_content = EXCLUDED.about_content,
    longevity_impact = EXCLUDED.longevity_impact,
    quick_tips = EXCLUDED.quick_tips,
    updated_at = NOW();

-- ============================================================
-- 2. DISPLAY METRICS AGGREGATIONS (Links display → agg metrics)
-- ============================================================

-- Link to bedtime and waketime aggregations
-- These metrics are used to calculate consistency bands and display sleep patterns

-- Bedtime - Daily (for W/M views)
INSERT INTO display_metrics_aggregations (
    metric_id, agg_metric_id, period_type, calculation_type_id, display_order
) VALUES
    ('DISP_SLEEP_CONSISTENCY', 'AGG_SLEEP_BEDTIME', 'daily', 'AVG', 1)
ON CONFLICT DO NOTHING;

-- Waketime - Daily (for W/M views)
INSERT INTO display_metrics_aggregations (
    metric_id, agg_metric_id, period_type, calculation_type_id, display_order
) VALUES
    ('DISP_SLEEP_CONSISTENCY', 'AGG_SLEEP_WAKETIME', 'daily', 'AVG', 2)
ON CONFLICT DO NOTHING;

-- Bedtime - Weekly (for 6M view)
INSERT INTO display_metrics_aggregations (
    metric_id, agg_metric_id, period_type, calculation_type_id, display_order
) VALUES
    ('DISP_SLEEP_CONSISTENCY', 'AGG_SLEEP_BEDTIME', 'weekly', 'AVG', 1)
ON CONFLICT DO NOTHING;

-- Waketime - Weekly (for 6M view)
INSERT INTO display_metrics_aggregations (
    metric_id, agg_metric_id, period_type, calculation_type_id, display_order
) VALUES
    ('DISP_SLEEP_CONSISTENCY', 'AGG_SLEEP_WAKETIME', 'weekly', 'AVG', 2)
ON CONFLICT DO NOTHING;

-- Bedtime - Monthly (for Y view)
INSERT INTO display_metrics_aggregations (
    metric_id, agg_metric_id, period_type, calculation_type_id, display_order
) VALUES
    ('DISP_SLEEP_CONSISTENCY', 'AGG_SLEEP_BEDTIME', 'monthly', 'AVG', 1)
ON CONFLICT DO NOTHING;

-- Waketime - Monthly (for Y view)
INSERT INTO display_metrics_aggregations (
    metric_id, agg_metric_id, period_type, calculation_type_id, display_order
) VALUES
    ('DISP_SLEEP_CONSISTENCY', 'AGG_SLEEP_WAKETIME', 'monthly', 'AVG', 2)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. DISPLAY SCREEN
-- ============================================================

INSERT INTO display_screens (
    screen_id, name, pillar, display_order, is_active
) VALUES (
    'SCREEN_SLEEP_CONSISTENCY',
    'Sleep Consistency',
    'Restorative Sleep',
    3,  -- After Sleep and Sleep Analysis
    true
) ON CONFLICT (screen_id) DO UPDATE SET
    name = EXCLUDED.name,
    pillar = EXCLUDED.pillar,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- ============================================================
-- 4. LINK SCREEN TO METRICS
-- ============================================================

INSERT INTO display_screens_primary_display_metrics (
    primary_screen_id, metric_id, display_order
) VALUES (
    'SCREEN_SLEEP_CONSISTENCY', 'DISP_SLEEP_CONSISTENCY', 1
) ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. VERIFICATION QUERIES
-- ============================================================

-- Verify display metric
SELECT metric_id, metric_name, pillar, chart_type_id, is_primary
FROM display_metrics
WHERE metric_id = 'DISP_SLEEP_CONSISTENCY';

-- Verify display → aggregation linkages
SELECT dma.metric_id, dma.agg_metric_id, dma.period_type, dma.calculation_type_id, dma.display_order
FROM display_metrics_aggregations dma
WHERE dma.metric_id = 'DISP_SLEEP_CONSISTENCY'
ORDER BY dma.period_type, dma.display_order;

-- Verify screen configuration
SELECT ds.screen_id, ds.name, dspdm.metric_id, dm.metric_name
FROM display_screens ds
JOIN display_screens_primary_display_metrics dspdm ON ds.screen_id = dspdm.primary_screen_id
JOIN display_metrics dm ON dspdm.metric_id = dm.metric_id
WHERE ds.screen_id = 'SCREEN_SLEEP_CONSISTENCY';

-- Verify that aggregation metrics exist
SELECT agg_metric_id, name, description
FROM aggregation_metrics
WHERE agg_metric_id IN ('AGG_SLEEP_BEDTIME', 'AGG_SLEEP_WAKETIME');
