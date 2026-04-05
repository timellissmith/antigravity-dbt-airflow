{{ config(materialized='table', tags=["deploy"]) }}

SELECT
    vessel_id,
    vessel_name,
    vessel_type,
    commissioned_at,
    -- Calculate vessel age
    date_diff(current_timestamp, commissioned_at, day) AS age_days
FROM {{ ref('stg_vessels') }}
