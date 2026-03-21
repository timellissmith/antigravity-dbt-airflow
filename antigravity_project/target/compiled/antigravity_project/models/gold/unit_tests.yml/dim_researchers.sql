
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