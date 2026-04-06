from airflow.models import BaseOperator
from include.hooks.telemetry_auth_hook import TelemetryAuthHook
import requests
import json
import logging
import os


class PaginatedApiToLocalNdjsonOperator(BaseOperator):
    """
    Custom Operator that pulls paginated telemetry data from an API and streams it
    directly to local NDJSON files in memory-safe chunks.
    """

    template_fields = ("stream_name", "api_url", "state_value")

    def __init__(
        self,
        *,
        stream_name: str,
        api_url: str,
        auth_conn_id: str = "telemetry_api_auth",
        api_batch_size: int = 1000,
        file_chunk_size: int = 50000,
        state_value: str = None,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.stream_name = stream_name
        self.api_url = api_url
        self.auth_conn_id = auth_conn_id
        self.api_batch_size = api_batch_size
        self.file_chunk_size = file_chunk_size
        self.state_value = state_value

    def execute(self, context):
        dag_id = context["dag"].dag_id
        run_id = context["run_id"]
        map_index = context.get("map_index", 0)

        hook = TelemetryAuthHook(telemetry_conn_id=self.auth_conn_id)
        current_cursor = self.state_value
        file_idx = 1
        records_in_current_file = 0
        total_records = 0

        # Nomenclature: /tmp/api_extract_{dag_id}_{run_id}_{stream_name}_{map_index}_part_{file_idx}.jsonl
        def get_file_path(idx):
            return f"/tmp/api_extract_{dag_id}_{run_id}_{self.stream_name}_{map_index}_part_{idx}.jsonl"

        file_path = get_file_path(file_idx)
        logging.info(
            f"Starting extraction for stream {self.stream_name} to {file_path}"
        )

        try:
            f = open(file_path, "w")

            while True:
                payload = {
                    "batch_size": self.api_batch_size,
                    "stream_type": self.stream_name,
                    "cursor": current_cursor,
                }

                response = requests.post(
                    self.api_url, json=payload, headers=hook.get_headers(), timeout=30
                )

                # Check for 401 and refresh token if needed
                if response.status_code == 401:
                    hook.refresh_token_if_needed(401)
                    # Retry once immediately
                    response = requests.post(
                        self.api_url,
                        json=payload,
                        headers=hook.get_headers(),
                        timeout=30,
                    )

                response.raise_for_status()
                data = response.json()
                events = data.get("events", [])

                if not events:
                    logging.info(f"No more events for stream: {self.stream_name}")
                    break

                for event in events:
                    f.write(json.dumps(event) + "\n")
                    records_in_current_file += 1
                    total_records += 1

                    if records_in_current_file >= self.file_chunk_size:
                        f.close()
                        logging.info(
                            f"Chunk size limit reached. Saved {records_in_current_file} records. Starting new chunk."
                        )
                        file_idx += 1
                        file_path = get_file_path(file_idx)
                        f = open(file_path, "w")
                        records_in_current_file = 0

                if data.get("next_cursor"):
                    current_cursor = data.get("next_cursor")
                else:
                    logging.info(f"Pagination complete for {self.stream_name}")
                    break

            f.close()
            logging.info(f"Finished extraction. Total records: {total_records}")
            return current_cursor  # Returns the last valid cursor

        except Exception as e:
            if "f" in locals() and not f.closed:
                f.close()
            logging.error(f"Extraction failed: {str(e)}")
            raise
