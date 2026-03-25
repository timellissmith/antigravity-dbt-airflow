-- created_at: 2026-03-25T16:57:22.915562209+00:00
-- finished_at: 2026-03-25T16:57:22.916990501+00:00
-- elapsed: 1ms
-- outcome: success
-- dialect: duckdb
-- node_id: not available
-- query_id: not available
-- desc: execute adapter call
/* {"app": "dbt", "connection_name": "", "dbt_version": "2.0.0", "profile_name": "antigravity", "target_name": "dev"} */

    
    select schema_name
    from system.information_schema.schemata
    
    where lower(catalog_name) = '"local_antigravity"'
    
  
  ;
-- created_at: 2026-03-25T16:57:22.917291709+00:00
-- finished_at: 2026-03-25T16:57:22.917560251+00:00
-- elapsed: 268us
-- outcome: success
-- dialect: duckdb
-- node_id: not available
-- query_id: not available
-- desc: execute adapter call
/* {"app": "dbt", "connection_name": "", "dbt_version": "2.0.0", "profile_name": "antigravity", "target_name": "dev"} */

    
        select type from duckdb_databases()
        where lower(database_name)='local_antigravity'
        and type='sqlite'
    
  ;
-- created_at: 2026-03-25T16:57:22.917690626+00:00
-- finished_at: 2026-03-25T16:57:22.917852626+00:00
-- elapsed: 162us
-- outcome: success
-- dialect: duckdb
-- node_id: not available
-- query_id: not available
-- desc: execute adapter call
/* {"app": "dbt", "connection_name": "", "dbt_version": "2.0.0", "profile_name": "antigravity", "target_name": "dev"} */

    
    
        create schema if not exists "local_antigravity"."main"
    ;
-- created_at: 2026-03-25T16:57:22.928080626+00:00
-- finished_at: 2026-03-25T16:57:22.936019418+00:00
-- elapsed: 7ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_locations
-- query_id: not available
-- desc: get_relation > list_relations call
SELECT table_catalog, table_schema, table_name, table_type FROM information_schema.tables WHERE table_schema = 'main';
-- created_at: 2026-03-25T16:57:22.928275292+00:00
-- finished_at: 2026-03-25T16:57:22.936285751+00:00
-- elapsed: 8ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_researchers
-- query_id: not available
-- desc: get_relation > list_relations call
SELECT table_catalog, table_schema, table_name, table_type FROM information_schema.tables WHERE table_schema = 'main';
-- created_at: 2026-03-25T16:57:22.928039626+00:00
-- finished_at: 2026-03-25T16:57:22.936387668+00:00
-- elapsed: 8ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_telemetry
-- query_id: not available
-- desc: get_relation > list_relations call
SELECT table_catalog, table_schema, table_name, table_type FROM information_schema.tables WHERE table_schema = 'main';
-- created_at: 2026-03-25T16:57:22.928133876+00:00
-- finished_at: 2026-03-25T16:57:22.936565209+00:00
-- elapsed: 8ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_vessels
-- query_id: not available
-- desc: get_relation > list_relations call
SELECT table_catalog, table_schema, table_name, table_type FROM information_schema.tables WHERE table_schema = 'main';
-- created_at: 2026-03-25T16:57:22.937458834+00:00
-- finished_at: 2026-03-25T16:57:22.939825376+00:00
-- elapsed: 2ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_locations
-- query_id: not available
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "seed.antigravity_project.raw_locations", "profile_name": "antigravity", "target_name": "dev"} */

    create table "local_antigravity"."main"."raw_locations" ("location_id" varchar,"location_name" varchar,"region" varchar,"facility_type" varchar)
  ;
-- created_at: 2026-03-25T16:57:22.937779709+00:00
-- finished_at: 2026-03-25T16:57:22.940079876+00:00
-- elapsed: 2ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_researchers
-- query_id: not available
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "seed.antigravity_project.raw_researchers", "profile_name": "antigravity", "target_name": "dev"} */

    create table "local_antigravity"."main"."raw_researchers" ("researcher_id" integer,"first_name" varchar,"last_name" varchar,"email" varchar,"specialization" varchar,"assigned_vessel_id" varchar,"joined_at" timestamp)
  ;
-- created_at: 2026-03-25T16:57:22.937775251+00:00
-- finished_at: 2026-03-25T16:57:22.940326626+00:00
-- elapsed: 2ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_telemetry
-- query_id: not available
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "seed.antigravity_project.raw_telemetry", "profile_name": "antigravity", "target_name": "dev"} */

    create table "local_antigravity"."main"."raw_telemetry" ("id" integer,"vessel_id" varchar,"raw_force_reading" float,"location_id" varchar,"event_time" timestamp)
  ;
-- created_at: 2026-03-25T16:57:22.938520293+00:00
-- finished_at: 2026-03-25T16:57:22.941562459+00:00
-- elapsed: 3ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_vessels
-- query_id: not available
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "seed.antigravity_project.raw_vessels", "profile_name": "antigravity", "target_name": "dev"} */

    create table "local_antigravity"."main"."raw_vessels" ("vessel_id" varchar,"vessel_name" varchar,"vessel_type" varchar,"commissioned_at" timestamp)
  ;
-- created_at: 2026-03-25T16:57:22.940769418+00:00
-- finished_at: 2026-03-25T16:57:22.948988209+00:00
-- elapsed: 8ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_locations
-- query_id: not available
-- desc: add_query adapter call

          COPY "local_antigravity"."main"."raw_locations" FROM '/home/vscode/workspace/antigravity_project/seeds/raw_locations.csv' (FORMAT CSV, HEADER TRUE, DELIMITER ',')
        ;
-- created_at: 2026-03-25T16:57:22.940758209+00:00
-- finished_at: 2026-03-25T16:57:22.949294584+00:00
-- elapsed: 8ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_researchers
-- query_id: not available
-- desc: add_query adapter call

          COPY "local_antigravity"."main"."raw_researchers" FROM '/home/vscode/workspace/antigravity_project/seeds/raw_researchers.csv' (FORMAT CSV, HEADER TRUE, DELIMITER ',')
        ;
-- created_at: 2026-03-25T16:57:22.942240459+00:00
-- finished_at: 2026-03-25T16:57:22.950396584+00:00
-- elapsed: 8ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_vessels
-- query_id: not available
-- desc: add_query adapter call

          COPY "local_antigravity"."main"."raw_vessels" FROM '/home/vscode/workspace/antigravity_project/seeds/raw_vessels.csv' (FORMAT CSV, HEADER TRUE, DELIMITER ',')
        ;
-- created_at: 2026-03-25T16:57:22.941263709+00:00
-- finished_at: 2026-03-25T16:57:22.951722001+00:00
-- elapsed: 10ms
-- outcome: success
-- dialect: duckdb
-- node_id: seed.antigravity_project.raw_telemetry
-- query_id: not available
-- desc: add_query adapter call

          COPY "local_antigravity"."main"."raw_telemetry" FROM '/home/vscode/workspace/antigravity_project/seeds/raw_telemetry.csv' (FORMAT CSV, HEADER TRUE, DELIMITER ',')
        ;
