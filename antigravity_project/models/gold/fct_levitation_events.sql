{{ config(
    materialized='table',
    tags=["deploy"],
    -- OPTIMIZATION: Partitioning by a timestamp is excellent for time-series data,
    -- allowing for efficient pruning in queries that filter by date ranges.
    partition_by={
      "field": "observed_at",
      "data_type": "timestamp",
      "granularity": "day"
    },
    -- OPTIMIZATION: Clustering is updated to use the high-cardinality join keys
    -- (`location_id`, `vessel_id`) first. This significantly improves join performance
    -- by co-locating related records. `vessel_type` is included as a common
    -- low-cardinality filter column.
    cluster_by=["location_id", "vessel_id", "vessel_type"]
) }}

/*
  Unified levitation events fact table.
  Sources:
    - batch (always):   stg_telemetry        (dbt seeds → BigQuery, run by Airflow/Cosmos)
    - stream (opt-in):  stg_telemetry_stream (Pub/Sub → BQ bronze → CQ → BQ silver)

  Set STREAMING_ENABLED=true to include streaming events.
  The ingestion_mode column distinguishes the two paths for monitoring.
*/

{% set streaming_enabled = env_var('STREAMING_ENABLED', 'false') == 'true' %}

WITH telemetry AS (
    SELECT
        event_id,
        vessel_id,
        location_id,
        gravity_g,
        observed_at,
        'batch' AS ingestion_mode
    FROM {{ ref('stg_telemetry') }}

    {% if streaming_enabled %}
    UNION ALL
    SELECT
        event_id,
        vessel_id,
        location_id,
        gravity_g,
        observed_at,
        'stream' AS ingestion_mode
    FROM {{ ref('stg_telemetry_stream') }}
    {% endif %}
),

-- OPTIMIZATION: Select only the columns needed from the dimension tables.
-- This reduces the amount of data that BigQuery needs to scan and shuffle during joins.
researchers AS (
    SELECT
        researcher_id,
        full_name,
        specialization,
        assigned_vessel_id,
        tenure_days
    FROM {{ ref('dim_researchers') }}
),

vessels AS (
    SELECT
        vessel_id,
        vessel_name,
        vessel_type,
        age_days
    FROM {{ ref('dim_vessels') }}
),

locations AS (
    SELECT
        location_id,
        location_name,
        region
    FROM {{ ref('dim_locations') }}
)

SELECT
    t.event_id,
    t.gravity_g,
    t.observed_at,
    t.ingestion_mode,
    -- Vessel attributes
    v.vessel_name,
    v.vessel_type,
    v.age_days AS vessel_age_days,
    -- Location attributes
    l.location_name,
    l.region,
    -- Researcher attribution (by assigned vessel)
    r.researcher_id,
    r.full_name AS lead_researcher,
    r.specialization,
    -- Business logic flag
    CASE WHEN t.gravity_g <= 0.1 THEN TRUE ELSE FALSE END AS is_levitation_event
FROM telemetry t
LEFT JOIN vessels v ON t.vessel_id = v.vessel_id
LEFT JOIN locations l ON t.location_id = l.location_id
LEFT JOIN researchers r ON t.vessel_id = r.assigned_vessel_id
-- Pick the most-tenured researcher per vessel if multiple assignments exist.
-- The QUALIFY clause is a highly efficient BigQuery-native way to filter window function results.
QUALIFY ROW_NUMBER() OVER (PARTITION BY t.event_id, t.ingestion_mode ORDER BY r.tenure_days DESC) = 1