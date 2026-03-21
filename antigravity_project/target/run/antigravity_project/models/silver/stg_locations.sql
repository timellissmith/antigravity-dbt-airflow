
  
  create view "local_antigravity"."main"."stg_locations__dbt_tmp" as (
    

SELECT
    location_id,
    location_name,
    region,
    facility_type
FROM "local_antigravity"."main"."raw_locations"
  );
