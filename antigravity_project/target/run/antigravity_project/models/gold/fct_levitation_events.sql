
  
    

    create or replace table `modelling-demo`.`antigravity_prod`.`fct_levitation_events`
      
    
    

    
    OPTIONS()
    as (
      

WITH telemetry AS (
    SELECT * FROM `modelling-demo`.`antigravity_prod`.`stg_telemetry`
    
),

researchers AS (
    SELECT * FROM `modelling-demo`.`antigravity_prod`.`dim_researchers`
)

SELECT
    t.event_id,
    t.vessel_name,
    t.gravity_g,
    t.observed_at,
    -- Attribute event to researcher based on some logic (e.g., vessel assignment)
    -- For this example, we'll assume a mapping or join on researcher metadata
    r.researcher_id,
    r.full_name AS lead_researcher,
    r.specialization,
    -- Flag "True Levitation" events
    CASE WHEN t.gravity_g <= 0.1 THEN TRUE ELSE FALSE END AS is_levitation_event
FROM telemetry t
-- Use QUALIFY to pick only one matching researcher to avoid fan-out
LEFT JOIN researchers r ON r.specialization = 'Levitation'
QUALIFY ROW_NUMBER() OVER (PARTITION BY t.event_id ORDER BY r.tenure_days DESC) = 1
    );
  