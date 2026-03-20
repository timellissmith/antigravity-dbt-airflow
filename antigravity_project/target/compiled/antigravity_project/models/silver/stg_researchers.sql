

SELECT
    researcher_id,
    INITCAP(first_name) AS first_name,
    INITCAP(last_name) AS last_name,
    LOWER(email) AS email,
    specialization,
    CAST(joined_at AS TIMESTAMP) AS joined_at
FROM `modelling-demo`.`antigravity_prod`.`raw_researchers`