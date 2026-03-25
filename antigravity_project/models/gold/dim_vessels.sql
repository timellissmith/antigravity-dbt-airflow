{{ config(materialized='table', tags=["deploy"]) }}

SELECT
    vessel_id,
    vessel_name,
    vessel_type,
    commissioned_at,
    -- Calculate vessel age
    date_diff('day', commissioned_at, current_timestamp) AS age_days
FROM {{ ref('stg_vessels') }}
