
    
    

select
    vessel_id as unique_field,
    count(*) as n_records

from "local_antigravity"."main"."dim_vessels"
where vessel_id is not null
group by vessel_id
having count(*) > 1


