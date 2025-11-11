-- Sleep Analysis Detail Screen Metrics
-- These metrics are used for the Sleep Analysis detail view tabs
-- Created: 2025-11-05

-- ============================================================
-- 1. AMOUNTS TAB
-- Shows sleep stage amounts (duration) with selectable highlighting
-- User can select Awake, REM, Core, or Deep to highlight that stage
-- ============================================================

INSERT INTO display_metrics (
    metric_id,
    metric_name,
    description,
    pillar,
    is_active,
    chart_type_id,
    is_primary,
    about_content,
    longevity_impact,
    quick_tips
) VALUES (
    'DISP_SLEEP_ANALYSIS_AMOUNTS',
    'Sleep Stage Amounts',
    'Detailed breakdown of time spent in each sleep stage',
    'Restorative Sleep',
    true,
    NULL,  -- Custom implementation in SleepAnalysisDetail, not factory-generated
    false,  -- This is a detail view, not primary
    'Sleep stage amounts show how long you spend in each phase of sleep throughout the night. The four key stages are Awake (brief awakenings), REM (Rapid Eye Movement for memory and emotional processing), Core (light sleep for transitioning), and Deep (slow-wave sleep for physical restoration). A healthy sleep architecture includes balanced time across all stages, with deep sleep concentrated in the first half of the night and REM sleep increasing in later cycles.',
    'The distribution and duration of sleep stages directly impacts healthspan. Deep sleep (15-25% of total sleep) drives physical recovery, immune function, and glymphatic clearance of brain waste products including amyloid-beta. REM sleep (20-25% of total sleep) supports emotional regulation, creativity, and memory consolidation. Core sleep facilitates transitions between stages. Even brief awakenings are normal, but excessive fragmentation impairs sleep quality and accelerates cognitive decline.',
    '["Aim for 1.5-2 hours of deep sleep per night (15-25% of total)", "Target 1.5-2 hours of REM sleep per night (20-25% of total)", "Deep sleep decreases with age—prioritize it by keeping bedroom cool (65-68°F)", "Alcohol reduces REM sleep—avoid within 3 hours of bedtime", "Core sleep is transitional and should flow naturally between stages", "Brief awakenings (<5 min) are normal; focus on minimizing longer disruptions", "Track patterns over weeks, not individual nights—consistency matters most"]'::jsonb
)
ON CONFLICT (metric_id) DO UPDATE SET
    metric_name = EXCLUDED.metric_name,
    description = EXCLUDED.description,
    pillar = EXCLUDED.pillar,
    is_active = EXCLUDED.is_active,
    chart_type_id = EXCLUDED.chart_type_id,
    about_content = EXCLUDED.about_content,
    longevity_impact = EXCLUDED.longevity_impact,
    quick_tips = EXCLUDED.quick_tips,
    updated_at = NOW();

-- ============================================================
-- 2. PERCENTAGES TAB
-- Shows sleep stage percentages relative to total sleep time
-- ============================================================

INSERT INTO display_metrics (
    metric_id,
    metric_name,
    description,
    pillar,
    is_active,
    chart_type_id,
    is_primary,
    about_content,
    longevity_impact,
    quick_tips
) VALUES (
    'DISP_SLEEP_ANALYSIS_PERCENTAGES',
    'Sleep Stage Percentages',
    'Percentage breakdown of sleep stages relative to total sleep time',
    'Restorative Sleep',
    true,
    'bar_vertical',  -- Percentage bars for each stage
    false,
    'Sleep stage percentages show the proportion of your total sleep spent in each stage. Rather than focusing solely on duration, percentages help you understand your sleep architecture—the balance and distribution of stages. Optimal sleep isn''t just about hitting 8 hours; it''s about achieving the right proportions: Deep sleep (15-25%), REM sleep (20-25%), Core sleep (45-55%), and minimal Awake time (<5%). These proportions indicate whether your sleep is truly restorative.',
    'Sleep stage proportions are powerful predictors of health outcomes independent of total duration. Research shows that reduced slow-wave (deep) sleep percentage increases risk of hypertension, type 2 diabetes, and cognitive decline. Low REM percentage correlates with mood disorders, reduced creativity, and impaired emotional regulation. The Whitehall II study found that sleep fragmentation (high awake percentage) predicted cardiovascular disease risk even when controlling for duration. Optimizing stage proportions is critical for maximizing healthspan.',
    '["Target ranges: Deep 15-25%, REM 20-25%, Core 45-55%, Awake <5%", "Don''t panic over single nights—look for patterns over 7-14 days", "Low deep sleep? Keep bedroom cool, avoid alcohol, exercise regularly", "Low REM? Manage stress, maintain consistent sleep schedule, avoid sleep disruption", "High awake %? Address sleep apnea, reduce caffeine, improve sleep hygiene", "Percentages matter more than absolute hours—8h with poor architecture < 7h with optimal stages", "Use trends to test interventions: change bedtime, temperature, or pre-sleep routine"]'::jsonb
)
ON CONFLICT (metric_id) DO UPDATE SET
    metric_name = EXCLUDED.metric_name,
    description = EXCLUDED.description,
    pillar = EXCLUDED.pillar,
    is_active = EXCLUDED.is_active,
    chart_type_id = EXCLUDED.chart_type_id,
    about_content = EXCLUDED.about_content,
    longevity_impact = EXCLUDED.longevity_impact,
    quick_tips = EXCLUDED.quick_tips,
    updated_at = NOW();

-- ============================================================
-- 3. COMPARISONS TAB
-- Placeholder for future comparison features
-- ============================================================

INSERT INTO display_metrics (
    metric_id,
    metric_name,
    description,
    pillar,
    is_active,
    chart_type_id,
    is_primary,
    about_content,
    longevity_impact,
    quick_tips
) VALUES (
    'DISP_SLEEP_ANALYSIS_COMPARISONS',
    'Sleep Comparisons',
    'Compare sleep metrics across different time periods or conditions',
    'Restorative Sleep',
    true,
    NULL,  -- Placeholder for future implementation
    false,
    'Sleep comparisons allow you to analyze patterns across time periods, compare weekday vs. weekend sleep, or evaluate the impact of lifestyle changes. By comparing metrics like stage distribution, efficiency, and consistency across different contexts, you can identify what factors most influence your sleep quality. This view will enable you to test hypotheses about your sleep and make data-driven decisions about interventions.',
    'Comparative analysis of sleep data enables personalized optimization. Research in chronobiology shows that individual sleep phenotypes vary dramatically—what works for one person may not work for another. By comparing your own sleep under different conditions (exercise vs. no exercise, different bedtimes, alcohol vs. none, etc.), you become your own sleep scientist. This N-of-1 approach is often more valuable than population averages for optimizing your personal sleep architecture and maximizing your healthspan.',
    '["Compare weekday vs. weekend sleep to identify social jet lag", "Track sleep before/after lifestyle changes (exercise, diet, supplements)", "Identify patterns: Does exercise timing affect deep sleep? Does screen time reduce REM?", "Compare sleep during different seasons—many people need more sleep in winter", "Use comparisons to find your optimal bedtime and wake time", "Test interventions systematically: change one variable at a time for 1-2 weeks", "Coming soon: Advanced comparison features with statistical analysis"]'::jsonb
)
ON CONFLICT (metric_id) DO UPDATE SET
    metric_name = EXCLUDED.metric_name,
    description = EXCLUDED.description,
    pillar = EXCLUDED.pillar,
    is_active = EXCLUDED.is_active,
    chart_type_id = EXCLUDED.chart_type_id,
    about_content = EXCLUDED.about_content,
    longevity_impact = EXCLUDED.longevity_impact,
    quick_tips = EXCLUDED.quick_tips,
    updated_at = NOW();

-- Verify the inserts
SELECT metric_id, metric_name, chart_type_id, is_primary
FROM display_metrics
WHERE metric_id LIKE 'DISP_SLEEP_ANALYSIS_%'
ORDER BY metric_id;
