
-- Fixture for dim_locations
select 
    
    cast('L_TEST' as character varying(256))
 as "location_id", 
    
    cast('Test Lab' as character varying(256))
 as "location_name", 
    
    cast('Test Region' as character varying(256))
 as "region", cast(null as character varying(256)) as "facility_type"