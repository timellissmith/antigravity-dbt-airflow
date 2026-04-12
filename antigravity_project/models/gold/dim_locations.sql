{{ config(
    materialized='table',
    tags=["deploy"],
    cluster_by=["region", "facility_type"]
) }}

SELECT
    location_id,
    location_name,
    region,
    facility_type
FROM {{ ref('stg_locations') }}
