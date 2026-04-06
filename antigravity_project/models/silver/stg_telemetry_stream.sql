{{ config(
    materialized='view',
    tags=["streaming"],
    enabled=env_var('STREAMING_ENABLED', 'false') == 'true',
    meta={"description": "View over the BigQuery Continuous Query output table. Infrastructure-managed; dbt provides documentation and testing only."}
) }}

/*
  This model is a thin view over streaming.stg_telemetry_stream, which is
  populated in real-time by a BigQuery Continuous Query (managed by Terraform).

  dbt's role here is documentation + testing only — the CQ does the transform.
  The view allows gold models to reference streaming silver via `ref('stg_telemetry_stream')`.
*/
SELECT
    event_id,
    vessel_id,
    location_id,
    gravity_g,
    observed_at,
    processed_at
FROM {{ source('streaming_layer', 'stg_telemetry_stream') }}
