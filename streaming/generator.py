"""
Antigravity Telemetry Data Generator
=====================================
Publishes synthetic telemetry events to Google Cloud Pub/Sub.
The events are ingested into BigQuery via a Pub/Sub subscription and then
standardized in real-time by a BigQuery Continuous Query.

Usage:
    # Publish 10 events at 1 per second (default)
    python -m streaming.generator --project modelling-demo

    # Publish 100 events at 5 per second
    python -m streaming.generator --project modelling-demo --count 100 --rate 5

    # Publish a single burst (CI health check)
    python -m streaming.generator --project modelling-demo --count 1 --rate 0
"""

from __future__ import annotations

import argparse
import csv
import logging
import pathlib
import time
from typing import Iterator

from google.cloud import pubsub_v1

from .schema import TelemetryEvent

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger(__name__)

# ── Seed data helpers ─────────────────────────────────────────────────────────

_SEEDS_DIR = pathlib.Path(__file__).parent.parent / "antigravity_project" / "seeds"

# Fallback IDs match the seed CSVs so CI without filesystem access still runs
_FALLBACK_VESSEL_IDS = ["V001", "V002", "V003", "V004", "V005"]
_FALLBACK_LOCATION_IDS = ["L001", "L002", "L003", "L004"]


def _load_seed_ids(filename: str, id_column: str) -> list[str]:
    """Load reference IDs from a dbt seed CSV so streaming events join in gold."""
    path = _SEEDS_DIR / filename
    if not path.exists():
        logger.warning("Seed file %s not found — using fallback IDs", path)
        return []
    with open(path, newline="") as f:
        return [row[id_column] for row in csv.DictReader(f) if row.get(id_column)]


def _get_vessel_ids() -> list[str]:
    return _load_seed_ids("raw_vessels.csv", "vessel_id") or _FALLBACK_VESSEL_IDS


def _get_location_ids() -> list[str]:
    return _load_seed_ids("raw_locations.csv", "location_id") or _FALLBACK_LOCATION_IDS


# ── Infinite event stream ─────────────────────────────────────────────────────


def event_stream(start_id: int = 1) -> Iterator[TelemetryEvent]:
    """Yield an infinite sequence of random telemetry events.

    IDs are monotonically increasing from start_id.
    Vessel and location IDs are loaded once from seed CSVs.
    """
    vessel_ids = _get_vessel_ids()
    location_ids = _get_location_ids()
    logger.info(
        "Generator loaded %d vessel IDs and %d location IDs from seeds",
        len(vessel_ids),
        len(location_ids),
    )
    i = start_id
    while True:
        yield TelemetryEvent.generate(i, vessel_ids, location_ids)
        i += 1


# ── Publisher ─────────────────────────────────────────────────────────────────


def publish_events(
    project_id: str,
    topic_id: str,
    count: int,
    rate_per_second: float,
) -> int:
    """Publish `count` telemetry events to Pub/Sub at `rate_per_second`.

    Args:
        project_id: GCP project ID.
        topic_id: Pub/Sub topic name (e.g. 'antigravity-telemetry').
        count: Number of events to publish.
        rate_per_second: Publishing rate. Set to 0 for maximum throughput.

    Returns:
        Number of events successfully published.
    """
    client_options = {"quota_project_id": project_id}
    publisher = pubsub_v1.PublisherClient(client_options=client_options)
    topic_path = publisher.topic_path(project_id, topic_id)
    logger.info("Publishing %d events to %s (quota project: %s) @ %.1f msg/s", count, topic_path, project_id, rate_per_second)

    interval = (1.0 / rate_per_second) if rate_per_second > 0 else 0.0
    published = 0
    futures = []

    for event in event_stream():
        if published >= count:
            break

        future = publisher.publish(topic_path, event.to_pubsub_data())
        futures.append((event.id, future))
        published += 1

        if interval > 0 and published < count:
            time.sleep(interval)

    # Resolve all futures (raises on any publish failure)
    errors = 0
    for event_id, future in futures:
        try:
            msg_id = future.result(timeout=30)
            logger.debug("Event %s → Pub/Sub msg_id=%s", event_id, msg_id)
        except Exception as exc:
            logger.error("Failed to publish event %s: %s", event_id, exc)
            errors += 1

    logger.info(
        "Done. Published: %d  Errors: %d  Total attempted: %d",
        published - errors,
        errors,
        published,
    )
    return published - errors


# ── CLI ───────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Antigravity telemetry stream generator — publishes events to Pub/Sub"
    )
    parser.add_argument(
        "--project",
        required=True,
        help="GCP project ID (e.g. modelling-demo)",
    )
    parser.add_argument(
        "--topic",
        default="antigravity-telemetry",
        help="Pub/Sub topic name [default: antigravity-telemetry]",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=10,
        help="Number of events to publish [default: 10]",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=1.0,
        help="Events per second. Set to 0 for max throughput [default: 1.0]",
    )
    args = parser.parse_args()

    published = publish_events(
        project_id=args.project,
        topic_id=args.topic,
        count=args.count,
        rate_per_second=args.rate,
    )
    raise SystemExit(0 if published > 0 else 1)


if __name__ == "__main__":
    main()
