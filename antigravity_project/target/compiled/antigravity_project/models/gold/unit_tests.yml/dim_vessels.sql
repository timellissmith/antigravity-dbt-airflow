
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