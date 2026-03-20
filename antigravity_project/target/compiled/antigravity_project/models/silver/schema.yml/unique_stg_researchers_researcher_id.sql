
    
    

with dbt_test__target as (

  select researcher_id as unique_field
  from `modelling-demo`.`antigravity_prod`.`stg_researchers`
  where researcher_id is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


