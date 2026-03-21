
-- Fixture for raw_telemetry
select 
    
    cast(1 as INTEGER)
 as "id", 
    
    cast('V001' as character varying(256))
 as "vessel_id", 
    
    cast(9.80665 as DOUBLE)
 as "raw_force_reading", 
    
    cast('L001' as character varying(256))
 as "location_id", 
    
    cast('2026-03-18 20:00:00' as TIMESTAMP)
 as "event_time"