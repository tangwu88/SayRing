#!/usr/bin/env python3
"""Validate protected JPush/vendor configuration for a production CI build.

Values are consumed by the vendored Android plugin directly from the process
environment. This script never writes credentials to tracked source files.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
from pathlib import Path
from typing import Any


SUPPORTED_VENDORS = {"huawei", "xiaomi", "meizu", "vivo", "oppo", "honor"}
PLACEHOLDER_WORDS = ("changeme", "example", "placeholder", "your_", "your-", "xxx")


class PushConfigError(ValueError):
    pass


def require_value(name: str, *, minimum: int = 4) -> str:
    value = os.environ.get(name, "").strip()
    lowered = value.lower()
    if len(value) < minimum or any(word in lowered for word in PLACEHOLDER_WORDS):
        raise PushConfigError(f"Missing or placeholder production credential: {name}.")
    if "\n" in value or "\r" in value or "\x00" in value:
        raise PushConfigError(f"Invalid control character in {name}.")
    return value


def parse_vendors(raw: str) -> list[str]:
    values = [item.strip().lower() for item in raw.split(",") if item.strip()]
    if not values:
        raise PushConfigError(
            "JPUSH_VENDOR_CHANNELS must explicitly be 'none' or a comma-separated vendor list."
        )
    if values == ["none"]:
        return []
    if "none" in values:
        raise PushConfigError("JPUSH_VENDOR_CHANNELS cannot combine 'none' with vendors.")
    unknown = set(values) - SUPPORTED_VENDORS
    if unknown:
        raise PushConfigError("Unsupported push vendors: " + ", ".join(sorted(unknown)))
    if len(values) != len(set(values)):
        raise PushConfigError("JPUSH_VENDOR_CHANNELS contains duplicates.")
    return sorted(values)


def find_package_names(value: Any) -> set[str]:
    result: set[str] = set()
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "package_name" and isinstance(item, str):
                result.add(item)
            result.update(find_package_names(item))
    elif isinstance(value, list):
        for item in value:
            result.update(find_package_names(item))
    return result


def install_huawei_config(output: Path, expected_package: str) -> None:
    encoded = require_value("HUAWEI_AGCONNECT_SERVICES_JSON_BASE64", minimum=16)
    try:
        content = base64.b64decode(encoded, validate=True)
        parsed = json.loads(content.decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise PushConfigError("Huawei agconnect-services.json is not valid base64 JSON.") from error
    packages = find_package_names(parsed)
    if expected_package not in packages:
        raise PushConfigError(
            "Huawei agconnect-services.json does not contain the production package name."
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(content)
    output.chmod(0o600)


def prepare(
    pubspec: Path,
    vendors: list[str],
    huawei_output: Path,
    expected_package: str,
) -> None:
    original = pubspec.read_text(encoding="utf-8")
    if re.search(r"(?m)^\s*jpush_android\s*:", original):
        raise PushConfigError(
            "Tracked pubspec.yaml must not contain a jpush_android credential block."
        )
    require_value("JPUSH_APP_KEY", minimum=8)
    channel = require_value("JPUSH_CHANNEL", minimum=1)
    if channel != "production":
        raise PushConfigError("JPUSH_CHANNEL must be exactly 'production' for a release build.")
    field_map = {
        "xiaomi": [
            ("app_key", "JPUSH_XIAOMI_APP_KEY"),
            ("app_id", "JPUSH_XIAOMI_APP_ID"),
        ],
        "meizu": [
            ("app_key", "JPUSH_MEIZU_APP_KEY"),
            ("app_id", "JPUSH_MEIZU_APP_ID"),
        ],
        "vivo": [
            ("app_key", "JPUSH_VIVO_APP_KEY"),
            ("app_id", "JPUSH_VIVO_APP_ID"),
        ],
        "oppo": [
            ("app_key", "JPUSH_OPPO_APP_KEY"),
            ("app_id", "JPUSH_OPPO_APP_ID"),
            ("app_secret", "JPUSH_OPPO_APP_SECRET"),
        ],
        "honor": [("app_id", "JPUSH_HONOR_APP_ID")],
    }
    for vendor in vendors:
        if vendor == "huawei":
            install_huawei_config(huawei_output, expected_package)
        else:
            for _, environment_name in field_map[vendor]:
                require_value(environment_name)
    print(
        "Validated protected JPush configuration; enabled vendor channels: "
        + (", ".join(vendors) if vendors else "none")
        + "."
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pubspec", default="pubspec.yaml")
    parser.add_argument("--vendors", required=True)
    parser.add_argument(
        "--huawei-output",
        default="android/app/agconnect-services.json",
    )
    parser.add_argument("--expected-package", default="cc.saidian.app")
    return parser


def main(argv: list[str] | None = None) -> int:
    try:
        args = build_parser().parse_args(argv)
        vendors = parse_vendors(args.vendors)
        prepare(
            Path(args.pubspec),
            vendors,
            Path(args.huawei_output),
            args.expected_package,
        )
        return 0
    except (PushConfigError, OSError) as error:
        print(f"push configuration failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
