{{ config(materialized='table', tags=["deploy"]) }}

SELECT
    location_id,
    location_name,
    region,
    facility_type
FROM {{ ref('stg_locations') }}
