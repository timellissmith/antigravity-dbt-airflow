SELECT
    id AS event_id,
    vessel_id,
    location_id,
    -- Convert local force to Standard Gravity (G)
    (raw_force_reading / 9.80665) AS gravity_g,
    CAST(event_time AS TIMESTAMP) AS observed_at
FROM "local_antigravity"."main"."raw_telemetry"