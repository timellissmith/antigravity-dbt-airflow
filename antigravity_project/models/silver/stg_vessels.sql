{{ config(tags=["deploy"]) }}

SELECT
    vessel_id,
    vessel_name,
    vessel_type,
    CAST(commissioned_at AS TIMESTAMP) AS commissioned_at
FROM {{ source('raw_layer', 'raw_vessels') }}
