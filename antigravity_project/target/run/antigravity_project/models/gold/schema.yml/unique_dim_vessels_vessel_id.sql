
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    vessel_id as unique_field,
    count(*) as n_records

from "local_antigravity"."main"."dim_vessels"
where vessel_id is not null
group by vessel_id
having count(*) > 1



  
  
      
    ) dbt_internal_test