






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and gravity_g >= -1 and gravity_g <= 2
)
 as expression


    from `modelling-demo`.`antigravity_dev`.`fct_levitation_events`
    

),
validation_errors as (

    select
        *
    from
        grouped_expression
    where
        not(expression = true)

)

select *
from validation_errors







