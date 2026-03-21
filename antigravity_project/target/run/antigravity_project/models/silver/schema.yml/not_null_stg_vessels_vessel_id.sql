
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select vessel_id
from "local_antigravity"."main"."stg_vessels"
where vessel_id is null



  
  
      
    ) dbt_internal_test