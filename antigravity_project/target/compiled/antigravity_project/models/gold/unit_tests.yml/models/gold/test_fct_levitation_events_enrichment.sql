

WITH  __dbt__cte__stg_telemetry as (

-- Fixture for stg_telemetry
select 
    
    cast(101 as INTEGER)
 as "event_id", 
    
    cast('V_TEST' as character varying(256))
 as "vessel_id", 
    
    cast('L_TEST' as character varying(256))
 as "location_id", 
    
    cast(0.05 as DOUBLE)
 as "gravity_g", 
    
    cast('2026-03-20 12:00:00' as TIMESTAMP)
 as "observed_at"
),  __dbt__cte__dim_researchers as (

-- Fixture for dim_researchers
select 
    
    cast(99 as INTEGER)
 as "researcher_id", cast(null as character varying(256)) as "first_name", cast(null as character varying(256)) as "last_name", cast(null as character varying(256)) as "email", cast(null as character varying(256)) as "specialization", 
    
    cast('V_TEST' as character varying(256))
 as "assigned_vessel_id", cast(null as TIMESTAMP) as "joined_at", 
    
    cast('Test Scientist' as character varying(256))
 as "full_name", 
    
    cast(50 as BIGINT)
 as "tenure_days"
),  __dbt__cte__dim_vessels as (

-- Fixture for dim_vessels
select 
    
    cast('V_TEST' as character varying(256))
 as "vessel_id", 
    
    cast('Test Vessel' as character varying(256))
 as "vessel_name", 
    
    cast('Probe' as character varying(256))
 as "vessel_type", cast(null as TIMESTAMP) as "commissioned_at", 
    
    cast(100 as BIGINT)
 as "age_days"
),  __dbt__cte__dim_locations as (

-- Fixture for dim_locations
select 
    
    cast('L_TEST' as character varying(256))
 as "location_id", 
    
    cast('Test Lab' as character varying(256))
 as "location_name", 
    
    cast('Test Region' as character varying(256))
 as "region", cast(null as character varying(256)) as "facility_type"
), telemetry AS (
    SELECT * FROM __dbt__cte__stg_telemetry
    
),

researchers AS (
    SELECT * FROM __dbt__cte__dim_researchers
),

vessels AS (
    SELECT * FROM __dbt__cte__dim_vessels
),

locations AS (
    SELECT * FROM __dbt__cte__dim_locations
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