-- Test if aggregation functions are working
-- This will help identify if the issue is with the functions themselves

-- =====================================================
-- 1. Check for syntax errors in process_rollup_aggregations
-- =====================================================
SELECT 
    proname,
    prosrc
FROM pg_proc
WHERE proname = 'process_rollup_aggregations'
LIMIT 1;

-- =====================================================
-- 2. Test if we can manually call process_field_aggregations for protein
-- Replace with actual patient_id and date
-- =====================================================
-- First, check what patient_id to use
SELECT DISTINCT patient_id 
FROM patient_data_entries 
WHERE field_id = 'DEF_PROTEIN_GRAMS' 
ORDER BY created_at DESC 
LIMIT 1;

-- Then manually test the function (uncomment and replace values):
-- SELECT process_field_aggregations(
--     'YOUR_PATIENT_ID_HERE'::uuid,
--     'DEF_PROTEIN_GRAMS',
--     CURRENT_DATE
-- );

-- =====================================================
-- 3. Check if aggregation_metrics_dependencies has DEF_PROTEIN_GRAMS
-- =====================================================
SELECT 
    amd.agg_metric_id,
    amd.data_entry_field_id,
    am.metric_name
FROM aggregation_metrics_dependencies amd
JOIN aggregation_metrics am ON am.agg_metric_id = amd.agg_metric_id
WHERE amd.data_entry_field_id = 'DEF_PROTEIN_GRAMS';

-- =====================================================
-- 4. Check the trigger_auto_process_aggregations function definition
-- =====================================================
SELECT 
    proname,
    pg_get_functiondef(oid) as function_def
FROM pg_proc
WHERE proname IN ('trigger_auto_process_aggregations', 'process_field_aggregations')
ORDER BY proname;

-- =====================================================
-- 5. Check for any error logs or recent failed function calls
-- =====================================================
-- This query checks PostgreSQL logs (if accessible)
-- Note: May require superuser access
SELECT 
    log_time,
    message
FROM pg_stat_statements
WHERE query LIKE '%process_field_aggregations%'
ORDER BY log_time DESC
LIMIT 10;


