{{ config(
    materialized='incremental',
    unique_key='event_id',
    tags=["api_ingestion"]
) }}

WITH unioned AS (
    SELECT *, 'fraud' as source_stream FROM {{ source('api_ingestion', 'telemetry_fraud') }}
    UNION ALL
    SELECT *, 'audit' as source_stream FROM {{ source('api_ingestion', 'telemetry_audit') }}
    UNION ALL
    SELECT *, 'access' as source_stream FROM {{ source('api_ingestion', 'telemetry_access') }}
)

SELECT
    event_id,
    stream_type,
    source_stream,
    -- Unnesting the JSON data field
    JSON_VALUE(data.value) as measure_value,
    JSON_VALUE(data.message) as event_message,
    TIMESTAMP_SECONDS(CAST(timestamp AS INT64)) as observed_at,
    _airflow_ingested_at as ingested_at
FROM unioned
{% if is_incremental() %}
WHERE _airflow_ingested_at > (SELECT COALESCE(MAX(ingested_at), '1900-01-01') FROM {{ this }})
{% endif %}
