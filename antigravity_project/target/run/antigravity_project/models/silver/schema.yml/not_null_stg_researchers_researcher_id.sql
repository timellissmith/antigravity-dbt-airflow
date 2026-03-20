
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select researcher_id
from `modelling-demo`.`antigravity_prod`.`stg_researchers`
where researcher_id is null



  
  
      
    ) dbt_internal_test