-- Antigravity Continuous Query: Bronze → Silver
-- This SQL is managed by Terraform (terraform/sql/stg_telemetry_stream.sql).
-- It is rendered via templatefile() and embedded into the Cloud Workflow.
-- Logic mirrors antigravity_project/models/silver/stg_telemetry.sql.
--
-- MAX_STALENESS hint: processing lag up to 5 minutes reduces slot consumption
-- significantly vs. near-real-time processing. Adjust via the CQ job options.

INSERT INTO `${project_id}.${streaming_dataset}.stg_telemetry_stream`
SELECT
    id                                  AS event_id,
    vessel_id,
    location_id,
    (raw_force_reading / 9.80665)       AS gravity_g,
    TIMESTAMP(event_time)               AS observed_at,
    CURRENT_TIMESTAMP()                 AS processed_at
FROM APPENDS(TABLE `${project_id}.${streaming_dataset}.raw_telemetry_stream`, NULL)
