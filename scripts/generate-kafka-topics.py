#!/usr/bin/env python3
"""Generate Kafka topics ConfigMap from sentry-kafka-schemas.

Usage:
    python3 scripts/generate-kafka-topics.py \
        --source /tmp/sentry-kafka-schemas/topics \
        --output kubernetes/apps/sentry/kafka/topics-configmap.yaml
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def parse_topic(topic_file: Path) -> dict:
    """Parse topic YAML and extract config."""
    with open(topic_file) as f:
        data = yaml.safe_load(f)

    return {
        "name": topic_file.stem,
        "partitions": data.get("enforced_partition_count", 1),
        "config": data.get("topic_creation_config", {})
    }


def main():
    parser = argparse.ArgumentParser(
        description="Generate Kafka topics ConfigMap from sentry-kafka-schemas"
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
    for topic_file in sorted(topic_files):
        try:
            topic = parse_topic(topic_file)
            topics.append(topic)
        except Exception as e:
            print(f"Warning: Failed to parse {topic_file.name}: {e}", file=sys.stderr)

    print(f"Processed {len(topics)} topics")

    # Generate topic list (one per line)
    topic_names = [t["name"] for t in topics]
    topics_content = "\n".join(topic_names)

    # Ensure output directory exists
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Write ConfigMap manually to control formatting
    with open(output_path, "w") as f:
        f.write("# Auto-generated from https://github.com/getsentry/sentry-kafka-schemas\n")
        f.write("# Do not edit manually! Run: python3 scripts/generate-kafka-topics.py\n")
        f.write("---\n")
        f.write("apiVersion: v1\n")
        f.write("kind: ConfigMap\n")
        f.write("metadata:\n")
        f.write("  name: kafka-topics\n")
        f.write("  annotations:\n")
        f.write("    source: https://github.com/getsentry/sentry-kafka-schemas\n")
        f.write("data:\n")
        f.write("  topics.txt: |\n")
        for name in topic_names:
            f.write(f"    {name}\n")

    print(f"Written to {output_path}")
    print(f"Total topics: {len(topic_names)}")


if __name__ == "__main__":
    main()
