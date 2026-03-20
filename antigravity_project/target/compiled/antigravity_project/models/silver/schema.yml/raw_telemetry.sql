
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