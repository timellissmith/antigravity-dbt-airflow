

SELECT
    id AS event_id,
    LOWER(vessel_name) AS vessel_name,
    -- Convert local force to Standard Gravity (G)
    (raw_force_reading / 9.80665) AS gravity_g,
    CAST(event_time AS TIMESTAMP) AS observed_at
FROM `your-project-id`.`raw`.`telemetry`