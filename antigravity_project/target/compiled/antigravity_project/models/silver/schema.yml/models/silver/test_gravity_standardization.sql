

with __dbt__cte__raw_layer__raw_telemetry as (

-- Fixture for raw_telemetry
select 
    
    cast(1 as INTEGER)
 as "id", 
    
    cast('Voyager' as character varying(256))
 as "vessel_name", 
    
    cast(9.80665 as DOUBLE)
 as "raw_force_reading", 
    
    cast('2026-03-18 20:00:00' as TIMESTAMP)
 as "event_time"
) SELECT
    id AS event_id,
    LOWER(vessel_name) AS vessel_name,
    -- Convert local force to Standard Gravity (G)
    (raw_force_reading / 9.80665) AS gravity_g,
    CAST(event_time AS TIMESTAMP) AS observed_at
FROM __dbt__cte__raw_layer__raw_telemetry