
  
    
    

    create  table
      "local_antigravity"."main"."dim_researchers__dbt_tmp"
  
    as (
      

SELECT
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
    
FROM "local_antigravity"."main"."stg_researchers"
    );
  
  