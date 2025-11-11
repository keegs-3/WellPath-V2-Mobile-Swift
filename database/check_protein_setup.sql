-- Check why protein aggregations aren't working while sleep is
-- This will help identify the configuration or function issue

-- =====================================================
-- 1. Check if DEF_PROTEIN_GRAMS has aggregation dependencies
-- =====================================================
SELECT 
    amd.agg_metric_id,
    amd.data_entry_field_id,
    am.metric_name,
    am.display_name
FROM aggregation_metrics_dependencies amd
JOIN aggregation_metrics am ON am.agg_metric_id = amd.agg_metric_id
WHERE amd.data_entry_field_id = 'DEF_PROTEIN_GRAMS'
ORDER BY amd.agg_metric_id;

-- =====================================================
-- 2. Compare with sleep dependencies (which work)
-- =====================================================
SELECT 
    amd.agg_metric_id,
    amd.data_entry_field_id,
    am.metric_name,
    am.display_name
FROM aggregation_metrics_dependencies amd
JOIN aggregation_metrics am ON am.agg_metric_id = amd.agg_metric_id
WHERE amd.data_entry_field_id LIKE '%SLEEP%'
ORDER BY amd.data_entry_field_id, amd.agg_metric_id
LIMIT 10;

-- =====================================================
-- 3. Check if process_field_aggregations function exists and works
-- =====================================================
SELECT 
    proname,
    pronargs,
    proargtypes::regtype[]
FROM pg_proc
WHERE proname = 'process_field_aggregations';

-- =====================================================
-- 4. Check recent protein entries in patient_data_entries
-- =====================================================
SELECT 
    id,
    patient_id,
    entry_date,
    field_id,
    value_quantity,
    created_at
FROM patient_data_entries
WHERE field_id = 'DEF_PROTEIN_GRAMS'
ORDER BY created_at DESC
LIMIT 5;

-- =====================================================
-- 5. Check if trigger_auto_process_aggregations handles all fields
-- =====================================================
SELECT 
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'trigger_auto_process_aggregations';

-- =====================================================
-- 6. Test manual call to process_field_aggregations for protein
-- Replace patient_id and date with actual values from query #4
-- =====================================================
-- Example (uncomment and replace values):
-- SELECT process_field_aggregations(
--     (SELECT DISTINCT patient_id FROM patient_data_entries WHERE field_id = 'DEF_PROTEIN_GRAMS' LIMIT 1)::uuid,
--     'DEF_PROTEIN_GRAMS',
--     (SELECT MAX(entry_date) FROM patient_data_entries WHERE field_id = 'DEF_PROTEIN_GRAMS')::date
-- );


