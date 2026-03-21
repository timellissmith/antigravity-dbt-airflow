

SELECT
    vessel_id,
    vessel_name,
    vessel_type,
    commissioned_at,
    -- Calculate vessel age
    
    date_diff('day', commissioned_at, now()) AS age_days
    
FROM "local_antigravity"."main"."stg_vessels"