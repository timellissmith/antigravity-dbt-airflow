
  
    
    

    create  table
      "local_antigravity"."main"."fct_levitation_events"
  
    as (
      

WITH telemetry AS (
    SELECT * FROM "local_antigravity"."main"."stg_telemetry"
    
),

researchers AS (
    SELECT * FROM "local_antigravity"."main"."dim_researchers"
),

vessels AS (
    SELECT * FROM "local_antigravity"."main"."dim_vessels"
),

locations AS (
    SELECT * FROM "local_antigravity"."main"."dim_locations"
)

SELECT
    t.event_id,
    t.gravity_g,
    t.observed_at,
    -- Join on vessel_id
    v.vessel_name,
    v.vessel_type,
    v.age_days AS vessel_age_days,
    -- Join on location_id
    l.location_name,
    l.region,
    -- Attribute event to researcher based on assigned vessel
    r.researcher_id,
    r.full_name AS lead_researcher,
    r.specialization,
    -- Flag "True Levitation" events
    CASE WHEN t.gravity_g <= 0.1 THEN TRUE ELSE FALSE END AS is_levitation_event
FROM telemetry t
LEFT JOIN vessels v ON t.vessel_id = v.vessel_id
LEFT JOIN locations l ON t.location_id = l.location_id
LEFT JOIN researchers r ON t.vessel_id = r.assigned_vessel_id
-- Use QUALIFY to pick only one matching researcher if there are multiple assignments (unlikely but safe)
QUALIFY ROW_NUMBER() OVER (PARTITION BY t.event_id ORDER BY r.tenure_days DESC) = 1
    );
  
  
  