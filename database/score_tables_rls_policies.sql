-- Permissions for WellPath Score Views and Tables (New Schema)
-- Views don't support RLS - we grant SELECT and rely on underlying table RLS
-- The underlying tables filter data by patient_id

-- ============================================================
-- VIEWS - Grant SELECT permissions
-- ============================================================
GRANT SELECT ON patient_wellpath_scores_current TO authenticated;
GRANT SELECT ON patient_wellpath_scores_history TO authenticated;
GRANT SELECT ON patient_pillar_scores_current TO authenticated;
GRANT SELECT ON patient_pillar_scores_history TO authenticated;
GRANT SELECT ON patient_component_scores_current TO authenticated;
GRANT SELECT ON patient_component_scores_history TO authenticated;

-- ============================================================
-- About Content Tables (Public Read Access)
-- ============================================================
GRANT SELECT ON wellpath_score_about TO authenticated;
GRANT SELECT ON wellpath_pillars_about TO authenticated;
GRANT SELECT ON wellpath_pillars_markers_about TO authenticated;
GRANT SELECT ON wellpath_pillars_behaviors_about TO authenticated;
GRANT SELECT ON wellpath_pillars_education_about TO authenticated;
GRANT SELECT ON pillars_base TO authenticated;
