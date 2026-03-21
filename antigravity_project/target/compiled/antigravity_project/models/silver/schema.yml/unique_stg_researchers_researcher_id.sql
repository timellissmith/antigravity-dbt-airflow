
    
    

select
    researcher_id as unique_field,
    count(*) as n_records

from "local_antigravity"."main"."stg_researchers"
where researcher_id is not null
group by researcher_id
having count(*) > 1


