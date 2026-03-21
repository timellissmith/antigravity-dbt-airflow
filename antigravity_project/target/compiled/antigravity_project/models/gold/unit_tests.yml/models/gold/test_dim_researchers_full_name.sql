

with __dbt__cte__stg_researchers as (

-- Fixture for stg_researchers
select 
    
    cast(1 as INTEGER)
 as "researcher_id", 
    
    cast('John' as character varying(256))
 as "first_name", 
    
    cast('Doe' as character varying(256))
 as "last_name", 
    
    cast('john@test.com' as character varying(256))
 as "email", 
    
    cast('Levitation' as character varying(256))
 as "specialization", 
    
    cast('V1' as character varying(256))
 as "assigned_vessel_id", 
    
    cast('2025-01-01 00:00:00' as TIMESTAMP)
 as "joined_at"
) SELECT
    researcher_id,
    first_name,
    last_name,
    email,
    specialization,
    assigned_vessel_id,
    joined_at,
    -- Add a full name for reporting
    CONCAT(first_name, ' ', last_name) AS full_name,
    -- Calculate researcher tenure
    
    date_diff('day', joined_at, now()) AS tenure_days
    
FROM __dbt__cte__stg_researchers