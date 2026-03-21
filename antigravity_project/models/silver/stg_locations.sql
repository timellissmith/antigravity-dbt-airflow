{{ config(tags=["deploy"]) }}

SELECT
    location_id,
    location_name,
    region,
    facility_type
FROM {{ source('raw_layer', 'raw_locations') }}
