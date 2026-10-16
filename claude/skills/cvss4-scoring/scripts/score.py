#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["cvss>=3.6"]
# ///
"""Score a CVSS 4.0 vector and print it with full metric and value names.

    uv run score.py 'CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:L/VI:N/VA:N/SC:N/SI:N/SA:N'
    uv run score.py VECTOR --vary PR --vary UI     # scores for each other value of PR and UI
    uv run score.py VECTOR --vary all              # every base metric

Only the eleven base metrics are shown and varied; threat, environmental and
supplemental metrics pass through unchanged.
"""

import argparse
import sys

from cvss import CVSS4
from cvss.constants4 import METRICS_ABBREVIATIONS, METRICS_MANDATORY, METRICS_VALUE_NAMES


def describe(metric: str, value: str) -> tuple[str, str]:
    """Return ("Attack Vector (AV)", "Network (N)") for ("AV", "N")."""
    return (
        f"{METRICS_ABBREVIATIONS[metric]} ({metric})",
        f"{METRICS_VALUE_NAMES[metric][value]} ({value})",
    )


def rebuild(vector: str, metric: str, value: str) -> str:
    """Return the vector with one base metric swapped."""
    parts = vector.split("/")
    out = []
    for part in parts:
        key, _, _ = part.partition(":")
        out.append(f"{metric}:{value}" if key == metric else part)
    return "/".join(out)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("vector", help="a CVSS:4.0/... vector string")
    parser.add_argument(
        "--vary",
        action="append",
        default=[],
        metavar="METRIC",
        help="also score each alternative value of this base metric; repeatable; 'all' for every base metric",
    )
    args = parser.parse_args(argv)

    try:
        scored = CVSS4(args.vector)
    except Exception as exc:  # the library raises its own CVSS4Error subclasses
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(f"`{scored.clean_vector()}`\n")
    print("| Metric | Value |")
    print("|---|---|")
    for metric in METRICS_MANDATORY:
        name, value = describe(metric, scored.metrics[metric])
        print(f"| {name} | {value} |")
    print(f"\n**{scored.base_score} {scored.severity}** (CVSS-B)")

    vary = METRICS_MANDATORY if "all" in args.vary else args.vary
    unknown = [m for m in vary if m not in METRICS_MANDATORY]
    if unknown:
        print(f"error: not a base metric: {', '.join(unknown)}", file=sys.stderr)
        return 2
    if vary:
        print("\n| Metric | Alternative | Score |")
        print("|---|---|---|")
        for metric in vary:
            current = scored.metrics[metric]
            for value in METRICS_VALUE_NAMES[metric]:
                if value == current:
                    continue
                alt = CVSS4(rebuild(args.vector, metric, value))
                name, value_name = describe(metric, value)
                print(f"| {name} | {value_name} | {alt.base_score} {alt.severity} |")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
