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
    date_diff('day', joined_at, current_timestamp) AS tenure_days
FROM {{ ref('stg_researchers') }}
