{{ config(tags=["deploy"]) }}

SELECT
    researcher_id,
    {% if target.type == 'bigquery' %}
    INITCAP(first_name) AS first_name,
    INITCAP(last_name) AS last_name,
    {% else %}
    first_name,
    last_name,
    {% endif %}
    LOWER(email) AS email,
    specialization,
    assigned_vessel_id,
    CAST(joined_at AS TIMESTAMP) AS joined_at
FROM {{ source('raw_layer', 'raw_researchers') }}
