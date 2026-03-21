
    -- Build actual result given inputs
with dbt_internal_unit_test_actual as (
  select
    "researcher_id","full_name", 'actual' as "actual_or_expected"
  from (
    

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
  ) _dbt_internal_unit_test_actual
),
-- Build expected result
dbt_internal_unit_test_expected as (
  select
    "researcher_id", "full_name", 'expected' as "actual_or_expected"
  from (
    select 
    
    cast(1 as INTEGER)
 as "researcher_id", 
    
    cast('John Doe' as character varying(256))
 as "full_name"
  ) _dbt_internal_unit_test_expected
)
-- Union actual and expected results
select * from dbt_internal_unit_test_actual
union all
select * from dbt_internal_unit_test_expected