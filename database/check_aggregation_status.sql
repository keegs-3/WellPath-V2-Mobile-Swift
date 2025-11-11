-- Quick diagnostic to check if aggregation functions exist and are working
-- Run this to see what's wrong with protein aggregations

-- =====================================================
-- 1. Check if process_rollup_aggregations function exists
-- =====================================================
SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'process_rollup_aggregations';

-- =====================================================
-- 2. Check if process_field_aggregations function exists
-- =====================================================
SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'process_field_aggregations';

-- =====================================================
-- 3. Check recent protein entries in patient_data_entries
-- =====================================================
SELECT 
    id,
    entry_date,
    field_id,
    value_quantity,
    created_at
FROM patient_data_entries
WHERE field_id LIKE '%PROTEIN%'
ORDER BY created_at DESC
LIMIT 10;

-- =====================================================
-- 4. Check if daily aggregations exist for protein
-- =====================================================
SELECT 
    agg_metric_id,
    period_type,
    calculation_type_id,
    period_start,
    value,
    last_computed_at
FROM aggregation_results_cache
WHERE agg_metric_id LIKE '%PROTEIN%'
ORDER BY last_computed_at DESC
LIMIT 10;

-- =====================================================
-- 5. Check triggers that call aggregation functions
-- =====================================================
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'patient_data_entries'
    AND trigger_name LIKE '%aggregation%';


