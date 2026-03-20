

SELECT
    researcher_id,
    first_name,
    last_name,
    email,
    specialization,
    joined_at,
    -- Add a full name for reporting
    CONCAT(first_name, ' ', last_name) AS full_name,
    -- Calculate researcher tenure
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), joined_at, DAY) AS tenure_days
FROM `modelling-demo`.`antigravity_dev`.`stg_researchers`