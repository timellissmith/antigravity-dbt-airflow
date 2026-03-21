

SELECT
    vessel_id,
    vessel_name,
    vessel_type,
    CAST(commissioned_at AS TIMESTAMP) AS commissioned_at
FROM "local_antigravity"."main"."raw_vessels"