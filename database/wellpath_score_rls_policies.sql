-- Row Level Security Policies for WellPath Score Tables
-- Allows patients to read their own WellPath Score data

-- ============================================================
-- VIEWS - Grant SELECT permissions
-- Views don't support RLS, so we grant SELECT to authenticated role
-- The underlying tables have RLS that restricts to patient's own data
-- ============================================================

GRANT SELECT ON patient_wellpath_score_overall TO authenticated;
GRANT SELECT ON patient_wellpath_score_by_pillar TO authenticated;
GRANT SELECT ON patient_wellpath_score_by_pillar_section TO authenticated;
GRANT SELECT ON patient_wellpath_score_by_section TO authenticated;
GRANT SELECT ON patient_wellpath_score_detail TO authenticated;

-- ============================================================
-- TABLES - Enable RLS and create policies
-- ============================================================

-- ============================================================
-- patient_wellpath_score_overall
-- ============================================================
ALTER TABLE patient_wellpath_score_overall ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own overall WellPath score" ON patient_wellpath_score_overall;
CREATE POLICY "Users can view their own overall WellPath score"
ON patient_wellpath_score_overall
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());

-- ============================================================
-- patient_wellpath_score_by_pillar
-- ============================================================
ALTER TABLE patient_wellpath_score_by_pillar ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own pillar scores" ON patient_wellpath_score_by_pillar;
CREATE POLICY "Users can view their own pillar scores"
ON patient_wellpath_score_by_pillar
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());

-- ============================================================
-- patient_wellpath_score_by_pillar_section
-- ============================================================
ALTER TABLE patient_wellpath_score_by_pillar_section ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own pillar section scores" ON patient_wellpath_score_by_pillar_section;
CREATE POLICY "Users can view their own pillar section scores"
ON patient_wellpath_score_by_pillar_section
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());

-- ============================================================
-- patient_wellpath_score_by_section
-- ============================================================
ALTER TABLE patient_wellpath_score_by_section ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own section scores" ON patient_wellpath_score_by_section;
CREATE POLICY "Users can view their own section scores"
ON patient_wellpath_score_by_section
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());

-- ============================================================
-- patient_wellpath_score_detail
-- ============================================================
ALTER TABLE patient_wellpath_score_detail ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own score details" ON patient_wellpath_score_detail;
CREATE POLICY "Users can view their own score details"
ON patient_wellpath_score_detail
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());

-- ============================================================
-- patient_wellpath_score_items
-- ============================================================
ALTER TABLE patient_wellpath_score_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own score items" ON patient_wellpath_score_items;
CREATE POLICY "Users can view their own score items"
ON patient_wellpath_score_items
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());
