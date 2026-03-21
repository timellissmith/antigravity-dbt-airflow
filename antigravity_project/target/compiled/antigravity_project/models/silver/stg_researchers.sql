

SELECT
    researcher_id,
    
    first_name,
    last_name,
    
    LOWER(email) AS email,
    specialization,
    assigned_vessel_id,
    CAST(joined_at AS TIMESTAMP) AS joined_at
FROM "local_antigravity"."main"."raw_researchers"