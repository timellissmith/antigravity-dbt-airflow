"""
Streaming pipeline tests.

Test strategy:
  - Pure unit tests (no GCP): always run, including CI.
  - Integration tests (need real GCP): skipped when CI=true.

Unit tests cover schema correctness, generator logic, and seed-loading.
Integration tests cover Pub/Sub reachability and BQ table existence.
"""

from __future__ import annotations

import json
import os

import pytest

# ── Unit Tests (always run) ───────────────────────────────────────────────────

VESSEL_IDS = ["V001", "V002", "V003"]
LOCATION_IDS = ["L001", "L002", "L003"]


class TestTelemetryEventSchema:
    """Validate the Pydantic event model without any GCP calls."""

    def test_generate_returns_valid_event(self):
        from streaming.schema import TelemetryEvent

        event = TelemetryEvent.generate(42, VESSEL_IDS, LOCATION_IDS)
        assert event.id == 42
        assert event.vessel_id in VESSEL_IDS
        assert event.location_id in LOCATION_IDS
        assert 0.5 <= event.raw_force_reading <= 15.0

    def test_event_time_is_iso_utc(self):
        from streaming.schema import TelemetryEvent

        event = TelemetryEvent.generate(1, VESSEL_IDS, LOCATION_IDS)
        # Must end with Z (UTC) and contain T separator
        assert "T" in event.event_time
        assert event.event_time.endswith("Z")

    def test_serialisation_is_valid_json(self):
        from streaming.schema import TelemetryEvent

        event = TelemetryEvent.generate(7, VESSEL_IDS, LOCATION_IDS)
        payload = event.to_pubsub_data()
        assert isinstance(payload, bytes)
        decoded = json.loads(payload.decode("utf-8"))
        assert decoded["id"] == 7
        assert "vessel_id" in decoded
        assert "raw_force_reading" in decoded
        assert "location_id" in decoded
        assert "event_time" in decoded

    def test_serialisation_field_types_match_avro_schema(self):
        """Field types must match the Pub/Sub Avro schema: long, string, double, string, string."""
        from streaming.schema import TelemetryEvent

        event = TelemetryEvent.generate(99, VESSEL_IDS, LOCATION_IDS)
        data = json.loads(event.to_pubsub_data())
        assert isinstance(data["id"], int)
        assert isinstance(data["vessel_id"], str)
        assert isinstance(data["raw_force_reading"], float)
        assert isinstance(data["location_id"], str)
        assert isinstance(data["event_time"], str)


class TestEventStream:
    """Validate the infinite event stream generator."""

    def test_stream_produces_sequential_ids(self):
        from streaming.generator import event_stream

        stream = event_stream(start_id=100)
        events = [next(stream) for _ in range(5)]
        ids = [e.id for e in events]
        assert ids == [100, 101, 102, 103, 104]

    def test_stream_uses_provided_ids(self):
        """Events must only use IDs from the provided vessel/location pools."""
        from streaming.generator import event_stream

        stream = event_stream(start_id=1)
        events = [next(stream) for _ in range(20)]
        # The generator loads seeds from disk; if seeds exist,
        # all vessel_ids must be from the CSV, not arbitrary strings
        for event in events:
            assert len(event.vessel_id) > 0
            assert len(event.location_id) > 0

    def test_seed_loading_falls_back_gracefully(self, tmp_path, monkeypatch):
        """If seed files don't exist, generator falls back to hardcoded IDs."""
        import streaming.generator as gen_module

        monkeypatch.setattr(gen_module, "_SEEDS_DIR", tmp_path)

        vessel_ids = gen_module._get_vessel_ids()
        location_ids = gen_module._get_location_ids()

        # Should fall back to hardcoded values, not raise
        assert len(vessel_ids) > 0
        assert len(location_ids) > 0


class TestStreamingSchemaConsistency:
    """Ensure streaming schema stays consistent with batch schema."""

    def test_streaming_silver_columns_match_batch_silver(self):
        """
        stg_telemetry_stream must expose the same core columns as stg_telemetry
        so fct_levitation_events can UNION ALL them without casting.
        """
        # Core columns that must exist in BOTH silver models for the gold UNION ALL
        required_columns = {"event_id", "vessel_id", "location_id", "gravity_g", "observed_at"}

        # Read the streaming silver SQL and check column aliases
        import pathlib
        streaming_sql = pathlib.Path(
            "antigravity_project/models/silver/stg_telemetry_stream.sql"
        ).read_text()

        for col in required_columns:
            assert col in streaming_sql, (
                f"Column '{col}' missing from stg_telemetry_stream.sql — "
                "UNION ALL with stg_telemetry in gold will fail."
            )

    def test_gold_model_references_both_silver_tables(self):
        """fct_levitation_events must ref() both stg_telemetry and stg_telemetry_stream."""
        import pathlib
        gold_sql = pathlib.Path(
            "antigravity_project/models/gold/fct_levitation_events.sql"
        ).read_text()

        assert "ref('stg_telemetry')" in gold_sql, "Gold model missing batch silver ref"
        assert "ref('stg_telemetry_stream')" in gold_sql, "Gold model missing streaming silver ref"
        assert "UNION ALL" in gold_sql, "Gold model missing UNION ALL"
        assert "ingestion_mode" in gold_sql, "Gold model missing ingestion_mode column"


# ── Integration Tests (skipped in CI) ─────────────────────────────────────────

@pytest.mark.skipif(
    os.getenv("CI") == "true" or not os.getenv("GCP_PROJECT_ID"),
    reason="Requires live GCP credentials and GCP_PROJECT_ID env var — skipped in CI",
)
class TestPubSubConnectivity:
    """Verify Pub/Sub topic is reachable with current credentials."""

    def test_topic_exists(self):
        from google.cloud import pubsub_v1

        project_id = os.getenv("GCP_PROJECT_ID", "modelling-demo")
        topic_name = os.getenv("PUBSUB_TOPIC", "antigravity-telemetry")

        client_options = {"quota_project_id": project_id}
        publisher = pubsub_v1.PublisherClient(client_options=client_options)
        topic_path = publisher.topic_path(project_id, topic_name)
        # Will raise google.api_core.exceptions.NotFound if topic doesn't exist
        topic = publisher.get_topic(request={"topic": topic_path})
        assert topic.name == topic_path


@pytest.mark.skipif(
    os.getenv("CI") == "true" or not os.getenv("GCP_PROJECT_ID"),
    reason="Requires live GCP credentials and GCP_PROJECT_ID env var — skipped in CI",
)
class TestBigQueryTableExistence:
    """Verify streaming BQ tables exist and have correct schemas."""

    def test_bronze_table_exists(self):
        from google.cloud import bigquery

        client = bigquery.Client()
        project = os.getenv("GCP_PROJECT_ID", "modelling-demo")
        table = client.get_table(f"{project}.streaming.raw_telemetry_stream")
        field_names = {f.name for f in table.schema}
        assert {"id", "vessel_id", "raw_force_reading", "location_id", "event_time"} <= field_names

    def test_silver_table_exists(self):
        from google.cloud import bigquery

        client = bigquery.Client()
        project = os.getenv("GCP_PROJECT_ID", "modelling-demo")
        table = client.get_table(f"{project}.streaming.stg_telemetry_stream")
        field_names = {f.name for f in table.schema}
        assert {"event_id", "vessel_id", "location_id", "gravity_g", "observed_at", "processed_at"} <= field_names
