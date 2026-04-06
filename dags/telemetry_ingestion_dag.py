from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.providers.google.cloud.transfers.local_to_gcs import (
    LocalFilesystemToGCSOperator,
)
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import (
    GCSToBigQueryOperator,
)
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta
import polars as pl
import os
import glob
import logging

# Import custom operator and hook
from include.operators.paginated_api_extractor import PaginatedApiToLocalNdjsonOperator
from cosmos import ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.operators.local import DbtRunLocalOperator

# Configuration
STREAMS = ["fraud", "audit", "access"]
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "modelling-demo")
BUCKET_NAME = f"antigravity-telemetry-{PROJECT_ID}"
DATASET_ID = "raw"
CONTROL_TABLE = f"{PROJECT_ID}.raw.etl_watermarks"

# DBT Configuration (Aligned with antigravity_pipeline)
DBT_PROJECT_PATH = os.path.join(os.path.dirname(__file__), "../antigravity_project")
DBT_EXECUTABLE = "dbt"  # Or "dbtf" if available

profile_config = ProfileConfig(
    profile_name="antigravity",
    target_name="dev",  # Or pull from env
    profiles_yml_filepath=os.path.join(DBT_PROJECT_PATH, "profiles.yml"),
)

execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE,
)

default_args = {
    "owner": "antigravity",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    "telemetry_ingestion_parallel",
    default_args=default_args,
    description="Memory-safe parallel API ingestion using Dynamic Task Mapping",
    schedule=timedelta(hours=1),
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["ingestion", "telemetry"],
) as dag:

    def generate_configs():
        """Returns the base configuration for each stream."""
        return [
            {"stream_name": s, "api_url": "http://localhost:8000/v1/telemetry/events"}
            for s in STREAMS
        ]

    def get_watermarks(configs):
        """Queries BQ to get the current cursor for each stream."""
        hook = BigQueryHook()
        enriched_configs = []

        for config in configs:
            stream_name = config["stream_name"]
            sql = f"SELECT current_cursor FROM {CONTROL_TABLE} WHERE stream_name = '{stream_name}'"
            print(sql)

            try:
                df = hook.get_pandas_df(sql)
                state_value = df["current_cursor"].iloc[0] if not df.empty else None
            except Exception as e:
                logging.warning(
                    f"Could not fetch watermark for {stream_name}: {str(e)}"
                )
                state_value = None

            enriched_configs.append({**config, "state_value": state_value})

        return enriched_configs

    def sanitize_files(**kwargs):
        """Lazily sanitizes the extracted local NDJSON files using Polars."""
        stream_name = kwargs["stream_name"]
        dag_id = kwargs["dag"].dag_id
        run_id = kwargs["run_id"]
        map_index = kwargs.get("map_index", 0)

        # Match files extracted by the upstream task
        pattern = (
            f"/tmp/api_extract_{dag_id}_{run_id}_{stream_name}_{map_index}_part_*.jsonl"
        )
        source_files = glob.glob(pattern)
        sanitized_files = []

        for src in source_files:
            dst = src.replace(".jsonl", "_sanitized.jsonl")
            logging.info(f"Sanitizing {src} -> {dst}")

            # Polars Lazy Processing
            (
                pl.scan_ndjson(src)
                .with_columns(
                    [
                        pl.lit(datetime.now().isoformat()).alias(
                            "_airflow_ingested_at"
                        ),
                        pl.lit(stream_name).alias("_stream_source"),
                    ]
                )
                .sink_ndjson(dst)
            )
            sanitized_files.append(dst)

        return sanitized_files

    # 1. Generate configs
    gen_configs = PythonOperator(
        task_id="generate_stream_configs", python_callable=generate_configs
    )

    # 2. Get states from BQ
    get_states = PythonOperator(
        task_id="get_states_for_streams",
        python_callable=get_watermarks,
        op_kwargs={"configs": gen_configs.output},
    )

    # 3. Mapped Extraction (Parallel)
    extract_api = PaginatedApiToLocalNdjsonOperator.partial(
        task_id="extract_api_to_local_ndjson",
        auth_conn_id="telemetry_api_auth",
        api_batch_size=1000,
        pool="telemetry_api",
    ).expand_kwargs(get_states.output)

    # 4. Mapped Sanitization (Parallel)
    sanitize = PythonOperator.partial(
        task_id="lazy_sanitize_data", python_callable=sanitize_files
    ).expand(
        op_kwargs=get_states.output
    )  # Map matching configs

    # 5. Mapped Upload to GCS
    # This is tricky because sanitize returns a list of files per map index.
    # We'll use a BashOperator to wildcard upload for each stream to keep it simple.
    upload_gcs = BashOperator.partial(
        task_id="upload_to_gcs",
        bash_command="""
            for f in /tmp/api_extract_{{ dag.dag_id }}_{{ run_id }}_{{ params.stream_name }}_*_sanitized.jsonl; do
                [ -e "$f" ] || continue
                gsutil cp "$f" gs://{{ params.bucket }}/telemetry/{{ params.stream_name }}/dt={{ ds }}/$(basename $f)
            done
        """,
    ).expand(params=[{"stream_name": s, "bucket": BUCKET_NAME} for s in STREAMS])

    load_bq = GCSToBigQueryOperator.partial(
        task_id="load_gcs_to_bq_raw",
        bucket=BUCKET_NAME,
        source_format="NEWLINE_DELIMITED_JSON",
        write_disposition="WRITE_APPEND",
        schema_fields=[
            {"name": "_airflow_ingested_at", "type": "TIMESTAMP", "mode": "NULLABLE"},
            {"name": "_stream_source", "type": "STRING", "mode": "NULLABLE"},
            {"name": "event_id", "type": "STRING", "mode": "NULLABLE"},
            {"name": "stream_type", "type": "STRING", "mode": "NULLABLE"},
            {"name": "data", "type": "JSON", "mode": "NULLABLE"},
            {"name": "timestamp", "type": "FLOAT", "mode": "NULLABLE"},
        ],
    ).expand(
        source_objects=[
            f"telemetry/{s}/dt=" + "{{ ds }}" + "/*.jsonl" for s in STREAMS
        ],
        destination_project_dataset_table=[
            f"{PROJECT_ID}.{DATASET_ID}.telemetry_{s}" for s in STREAMS
        ],
    )

    def prepare_update_configs(configs, latest_cursors):
        """Pairs each stream config with its corresponding latest cursor from the extractor."""
        logging.info(
            f"Preparing updates for {len(configs)} configs. Results received: {len(latest_cursors)}"
        )
        updates = []
        for i, config in enumerate(configs):
            # Safe access to avoid IndexError if mapping/expansion is incomplete
            cursor = latest_cursors[i] if i < len(latest_cursors) else None
            if cursor:
                updates.append(
                    {
                        "control_table": CONTROL_TABLE,
                        "stream_name": config["stream_name"],
                        "cursor": cursor,
                    }
                )
        return updates

    prep_updates = PythonOperator(
        task_id="prepare_update_configs",
        python_callable=prepare_update_configs,
        op_kwargs={"configs": get_states.output, "latest_cursors": extract_api.output},
    )

    # 7. Update Watermarks in BQ
    update_watermarks = BigQueryInsertJobOperator.partial(
        task_id="update_state_cursors",
        configuration={
            "query": {
                "query": "MERGE INTO {{ params.control_table }} T "
                "USING (SELECT '{{ params.stream_name }}' as stream_name, '{{ params.cursor }}' as current_cursor) S "
                "ON T.stream_name = S.stream_name "
                "WHEN MATCHED THEN UPDATE SET current_cursor = S.current_cursor, updated_at = CURRENT_TIMESTAMP() "
                "WHEN NOT MATCHED THEN INSERT (stream_name, current_cursor, updated_at) VALUES (S.stream_name, S.current_cursor, CURRENT_TIMESTAMP())",
                "useLegacySql": False,
            }
        },
    ).expand(params=prep_updates.output)

    # 8. DBT Silver Unnesting (Sequentially after all streams load)
    dbt_silver = DbtRunLocalOperator(
        task_id="dbt_silver_unnest",
        project_dir=DBT_PROJECT_PATH,
        profile_config=profile_config,
        execution_config=execution_config,
        select=["stg_api_telemetry"],
        env={
            "GCP_PROJECT_ID": PROJECT_ID,
            "GCP_SCHEMA": "raw",
            "STREAMING_ENABLED": "true",
        },
    )

    # 9. Cleanup
    cleanup = BashOperator(
        task_id="cleanup_local_files",
        bash_command=f"rm -f /tmp/api_extract_{{ dag.dag_id }}_{{ run_id }}*.jsonl",
        trigger_rule="all_done",
    )

    # Dependencies
    (
        gen_configs
        >> get_states
        >> extract_api
        >> sanitize
        >> upload_gcs
        >> load_bq
        >> prep_updates
        >> update_watermarks
    )
    load_bq >> dbt_silver >> cleanup
