{{ config(materialized='table', tags=["deploy"]) }}

SELECT
    researcher_id,
    first_name,
    last_name,
    email,
    specialization,
    assigned_vessel_id,
    joined_at,
    -- Add a full name for reporting
    CONCAT(first_name, ' ', last_name) AS full_name,
    -- Calculate researcher tenure
    {% if target.type == 'bigquery' %}
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), joined_at, DAY) AS tenure_days
    {% else %}
    date_diff('day', joined_at, now()) AS tenure_days
    {% endif %}
FROM {{ ref('stg_researchers') }}
