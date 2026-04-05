"""
Telemetry event schema for the Antigravity streaming pipeline.

This Pydantic model is the single source of truth for the event shape.
It must remain in sync with:
  - terraform/streaming.tf     (raw_telemetry_stream BQ table schema)
  - terraform/workflows/cq_manager.yaml  (CQ INSERT SQL)
  - antigravity_project/models/silver/stg_telemetry_stream.sql
"""

from __future__ import annotations

import random
from datetime import datetime, timezone
from typing import Sequence

from pydantic import BaseModel, Field


class TelemetryEvent(BaseModel):
    """One telemetry reading from an antigravity vessel.

    Field types exactly match the Pub/Sub Avro schema (JSON encoding)
    and the raw_telemetry_stream BigQuery table schema.
    """

    id: int = Field(description="Unique monotonic event identifier")
    vessel_id: str = Field(description="Vessel identifier — must match raw_vessels seed data")
    raw_force_reading: float = Field(
        description="Unscaled antigravity force reading in m/s²"
    )
    location_id: str = Field(
        description="Location identifier — must match raw_locations seed data"
    )
    event_time: str = Field(
        description="ISO 8601 UTC timestamp of the reading (e.g. 2026-04-03T15:00:00Z)"
    )

    @classmethod
    def generate(
        cls,
        event_id: int,
        vessel_ids: Sequence[str],
        location_ids: Sequence[str],
    ) -> "TelemetryEvent":
        """Generate a random telemetry event using valid reference IDs from seed data.

        Args:
            event_id: Monotonic event counter.
            vessel_ids: Valid vessel IDs loaded from raw_vessels.csv seed.
            location_ids: Valid location IDs loaded from raw_locations.csv seed.
        """
        return cls(
            id=event_id,
            vessel_id=random.choice(list(vessel_ids)),
            raw_force_reading=round(random.uniform(0.5, 15.0), 4),
            location_id=random.choice(list(location_ids)),
            event_time=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        )

    def to_pubsub_data(self) -> bytes:
        """Serialise to UTF-8 JSON bytes for Pub/Sub publishing.

        The output must match the Pub/Sub topic's Avro schema with JSON encoding.
        Field names and types are validated by Pub/Sub before writing to BigQuery.
        """
        return self.model_dump_json().encode("utf-8")
