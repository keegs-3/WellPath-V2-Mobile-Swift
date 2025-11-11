-- =====================================================
-- RLS Policies for WellPath
-- Run this in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. CONFIGURATION TABLES (Read-only for authenticated users)
-- =====================================================

-- Pillars Base
ALTER TABLE pillars_base ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read pillars" ON pillars_base;
CREATE POLICY "Allow authenticated users to read pillars"
ON pillars_base FOR SELECT
TO authenticated
USING (true);

-- Display Screens
ALTER TABLE display_screens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read display screens" ON display_screens;
CREATE POLICY "Allow authenticated users to read display screens"
ON display_screens FOR SELECT
TO authenticated
USING (true);

-- Display Screens Primary
ALTER TABLE display_screens_primary ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read primary screens" ON display_screens_primary;
CREATE POLICY "Allow authenticated users to read primary screens"
ON display_screens_primary FOR SELECT
TO authenticated
USING (true);

-- Display Screens Detail
ALTER TABLE display_screens_detail ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read detail screens" ON display_screens_detail;
CREATE POLICY "Allow authenticated users to read detail screens"
ON display_screens_detail FOR SELECT
TO authenticated
USING (true);

-- Display Metrics
ALTER TABLE display_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read display metrics" ON display_metrics;
CREATE POLICY "Allow authenticated users to read display metrics"
ON display_metrics FOR SELECT
TO authenticated
USING (true);

-- Primary Metrics Junction Table
ALTER TABLE display_screens_primary_display_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read primary metrics junction" ON display_screens_primary_display_metrics;
CREATE POLICY "Allow authenticated users to read primary metrics junction"
ON display_screens_primary_display_metrics FOR SELECT
TO authenticated
USING (true);

-- Detail Metrics Junction Table
ALTER TABLE display_screens_detail_display_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read detail metrics junction" ON display_screens_detail_display_metrics;
CREATE POLICY "Allow authenticated users to read detail metrics junction"
ON display_screens_detail_display_metrics FOR SELECT
TO authenticated
USING (true);

-- Chart Types
ALTER TABLE chart_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read chart types" ON chart_types;
CREATE POLICY "Allow authenticated users to read chart types"
ON chart_types FOR SELECT
TO authenticated
USING (true);

-- =====================================================
-- 2. USER DATA TABLES (Scoped to patient_id)
-- =====================================================

-- Patient Data Entries
ALTER TABLE patient_data_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own data entries" ON patient_data_entries;
CREATE POLICY "Users can read their own data entries"
ON patient_data_entries FOR SELECT
TO authenticated
USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Users can insert their own data entries" ON patient_data_entries;
CREATE POLICY "Users can insert their own data entries"
ON patient_data_entries FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Users can update their own data entries" ON patient_data_entries;
CREATE POLICY "Users can update their own data entries"
ON patient_data_entries FOR UPDATE
TO authenticated
USING (auth.uid() = patient_id)
WITH CHECK (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Users can delete their own data entries" ON patient_data_entries;
CREATE POLICY "Users can delete their own data entries"
ON patient_data_entries FOR DELETE
TO authenticated
USING (auth.uid() = patient_id);

-- Aggregation Results Cache
ALTER TABLE aggregation_results_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own aggregation results" ON aggregation_results_cache;
CREATE POLICY "Users can read their own aggregation results"
ON aggregation_results_cache FOR SELECT
TO authenticated
USING (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Users can insert their own aggregation results" ON aggregation_results_cache;
CREATE POLICY "Users can insert their own aggregation results"
ON aggregation_results_cache FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Users can update their own aggregation results" ON aggregation_results_cache;
CREATE POLICY "Users can update their own aggregation results"
ON aggregation_results_cache FOR UPDATE
TO authenticated
USING (auth.uid() = patient_id)
WITH CHECK (auth.uid() = patient_id);

DROP POLICY IF EXISTS "Users can delete their own aggregation results" ON aggregation_results_cache;
CREATE POLICY "Users can delete their own aggregation results"
ON aggregation_results_cache FOR DELETE
TO authenticated
USING (auth.uid() = patient_id);

-- =====================================================
-- 3. OPTIONAL: Add policies for other tables as needed
-- =====================================================

-- If you have other tables like parent_display_metrics, child_display_metrics,
-- parent_detail_sections, etc., add similar read-only policies:

-- Example for other configuration tables:
-- ALTER TABLE your_config_table ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow authenticated users to read config"
-- ON your_config_table FOR SELECT TO authenticated USING (true);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Run these to verify policies are set up correctly:
-- SELECT tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;
