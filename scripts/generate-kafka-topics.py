#!/usr/bin/env python3
"""Generate Strimzi KafkaTopic CRs from sentry-kafka-schemas.

Usage:
    python3 scripts/generate-kafka-topics.py \
        --source /tmp/sentry-kafka-schemas/topics \
        --output kubernetes/apps/sentry/kafka/kafka-topics.yaml \
        --cluster sentry-kafka
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def parse_topic(topic_file: Path, cluster_name: str) -> dict:
    """Parse topic YAML and extract config for Strimzi KafkaTopic CR."""
    with open(topic_file) as f:
        data = yaml.safe_load(f)

    topic_name = topic_file.stem
    config = data.get("topic_creation_config", {})

    # Convert all config values to strings (Strimzi requirement)
    kafka_config = {k: str(v) for k, v in config.items()}

    return {
        "apiVersion": "kafka.strimzi.io/v1beta2",
        "kind": "KafkaTopic",
        "metadata": {
            "name": topic_name,
            "labels": {
                "strimzi.io/cluster": cluster_name,
                "app.kubernetes.io/managed-by": "sentry-kafka-schemas"
            }
        },
        "spec": {
            "partitions": data.get("enforced_partition_count", 1),
            "replicas": 1,
            "config": kafka_config
        }
    }


def main():
    parser = argparse.ArgumentParser(
        description="Generate Strimzi KafkaTopic CRs from sentry-kafka-schemas"
    )
    parser.add_argument(
        "--source",
        required=True,
        help="Path to sentry-kafka-schemas/topics directory"
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output YAML file path"
    )
    parser.add_argument(
        "--cluster",
        default="sentry-kafka",
        help="Kafka cluster name (default: sentry-kafka)"
    )
    args = parser.parse_args()

    source_path = Path(args.source)
    if not source_path.exists():
        print(f"Error: Source directory does not exist: {source_path}", file=sys.stderr)
        sys.exit(1)

    topic_files = list(source_path.glob("*.yaml"))
    if not topic_files:
        print(f"Error: No YAML files found in {source_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(topic_files)} topic definitions")

    topics = []
    for topic_file in topic_files:
        try:
            topic = parse_topic(topic_file, args.cluster)
            topics.append(topic)
        except Exception as e:
            print(f"Warning: Failed to parse {topic_file.name}: {e}", file=sys.stderr)

    # Sort by name for consistent diffs
    topics.sort(key=lambda t: t["metadata"]["name"])

    print(f"Generated {len(topics)} KafkaTopic resources")

    # Ensure output directory exists
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        # Header comments (above all documents)
        f.write("# Auto-generated from https://github.com/getsentry/sentry-kafka-schemas\n")
        f.write("# Do not edit manually! Run: python3 scripts/generate-kafka-topics.py\n")

        # Write each topic as separate document with schema
        for topic in topics:
            f.write("---\n")
            f.write("# yaml-language-server: $schema=https://schemas.vzkn.eu/kafka.strimzi.io/kafkatopic_v1beta2.json\n")
            yaml.dump(topic, f, default_flow_style=False, sort_keys=False)

    print(f"Written to {output_path}")


if __name__ == "__main__":
    main()
