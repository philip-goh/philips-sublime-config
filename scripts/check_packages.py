#!/usr/bin/env python3
"""Audit `Package Control.sublime-settings` against Package Control's channel.

The manifest makes Package Control install any missing package automatically,
but nothing tells you when a package stops being maintained. This script
downloads Package Control's channel index, finds the newest release of every
package in the manifest and flags:

    OK       released within WARN_AGE_DAYS
    WARN     older than WARN_AGE_DAYS — revisit eventually
    STALE    older than MAX_AGE_DAYS — exit 1
    MISSING  not in any channel repository — exit 1

Run locally with `python3 scripts/check_packages.py`; the weekly
`package-audit` GitHub workflow runs the same check.
"""

import argparse
import datetime as dt
import json
import sys
import urllib.request
from pathlib import Path

from check_settings import strip_jsonc

CHANNEL_URL = "https://packagecontrol.io/channel_v3.json"
MANIFEST_NAME = "Package Control.sublime-settings"
WARN_AGE_DAYS = 730
MAX_AGE_DAYS = 1095
RELEASE_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


def load_channel(channel_file: Path | None) -> dict:
    if channel_file:
        return json.loads(channel_file.read_text(encoding="utf-8"))
    request = urllib.request.Request(
        CHANNEL_URL, headers={"User-Agent": "philips-sublime-config/check_packages"}
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.load(response)


def newest_release_dates(channel: dict) -> dict[str, dt.datetime]:
    """Map package name -> newest release date across all channel repositories."""
    newest: dict[str, dt.datetime] = {}
    for packages in channel.get("packages_cache", {}).values():
        for package in packages:
            dates = [
                dt.datetime.strptime(release["date"], RELEASE_DATE_FORMAT).replace(
                    tzinfo=dt.timezone.utc
                )
                for release in package.get("releases", [])
                if release.get("date")
            ]
            if not dates:
                continue
            name = package["name"]
            if name not in newest or max(dates) > newest[name]:
                newest[name] = max(dates)
    return newest


def installed_packages(root: Path) -> list[str]:
    manifest = root / MANIFEST_NAME
    data = json.loads(strip_jsonc(manifest.read_text(encoding="utf-8")))
    return data["installed_packages"]


def audit(root: Path, channel: dict) -> list[str]:
    """Print the audit table; return the list of hard failures."""
    newest = newest_release_dates(channel)
    now = dt.datetime.now(dt.timezone.utc)
    names = installed_packages(root)
    failures: list[str] = []

    print(f"Auditing {len(names)} packages from '{MANIFEST_NAME}'\n")
    print(f"{'STATUS':<8} {'PACKAGE':<34} {'LATEST RELEASE':<14} {'AGE':>6}")
    for name in names:
        released = newest.get(name)
        if released is None:
            print(f"{'MISSING':<8} {name:<34} {'n/a':<14} {'n/a':>6}")
            failures.append(f"{name}: not found in any Package Control repository")
            continue
        age_days = (now - released).days
        if age_days > MAX_AGE_DAYS:
            status = "STALE"
            failures.append(
                f"{name}: newest release is {age_days} days old "
                f"({released.date().isoformat()})"
            )
        elif age_days > WARN_AGE_DAYS:
            status = "WARN"
        else:
            status = "OK"
        print(f"{status:<8} {name:<34} {released.date().isoformat():<14} {age_days:>5}d")

    print()
    if not failures:
        print(
            f"All packages resolve and none are older than {MAX_AGE_DAYS} days "
            f"(warnings start at {WARN_AGE_DAYS})."
        )
        return []
    for failure in failures:
        print(f"FAIL  {failure}")
    print(
        "\nFind a maintained replacement (or drop the package), then re-run. "
        "Update the age\nthresholds in this script only with a comment "
        "explaining why a stale package is kept."
    )
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--channel-file",
        type=Path,
        help="use a local channel_v3.json instead of downloading it",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    failures = audit(root, load_channel(args.channel_file))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
