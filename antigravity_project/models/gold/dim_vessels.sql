{{ config(materialized='table', tags=["deploy"]) }}

SELECT
    vessel_id,
    vessel_name,
    vessel_type,
    commissioned_at,
    -- Calculate vessel age
    {% if target.type == 'bigquery' %}
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), commissioned_at, DAY) AS age_days
    {% else %}
    date_diff('day', commissioned_at, now()) AS age_days
    {% endif %}
FROM {{ ref('stg_vessels') }}
