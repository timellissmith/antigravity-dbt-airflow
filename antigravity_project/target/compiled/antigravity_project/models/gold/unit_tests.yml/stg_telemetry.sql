
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