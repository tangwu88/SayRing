#!/usr/bin/env python3
"""Production release metadata and update-manifest gate.

The script deliberately uses only the Python standard library so it can run on
GitHub-hosted runners before Flutter dependencies are installed.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import quote, urlparse


VERSION_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
TAG_RE = re.compile(
    r"^android-v(?P<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))"
    r"\+(?P<build>[1-9]\d*)$"
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
APP_STORE_PRODUCT_PATH_RE = re.compile(
    r"^/(?:[a-z]{2}/)?app/(?:[^/]+/)?id[0-9]+/?$", re.IGNORECASE
)
ANDROID_NS = "http://schemas.android.com/apk/res/android"
FORBIDDEN_ANDROID_PERMISSIONS = {
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.BLUETOOTH_ADVERTISE",
    "android.permission.QUERY_ALL_PACKAGES",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.READ_PHONE_STATE",
    "android.permission.RECORD_AUDIO",
}
OPTIONAL_ANDROID_FEATURES = {
    "android.hardware.camera",
    "android.hardware.camera.any",
    "android.hardware.camera.autofocus",
}
INTERNAL_ANDROID_COMPONENTS = {
    ("service", "com.yucheng.ycbtsdk.upgrade.utils.DfuService"),
    ("service", "org.eclipse.paho.android.service.MqttService"),
    ("receiver", "no.nordicsemi.android.support.v18.scanner.PendingIntentReceiver"),
}
PRODUCTION_ANDROID_ABIS = ("armeabi-v7a", "arm64-v8a")
CONTROLLED_ARM64_ONLY_LIBRARY = "libjutils.so"
CONTROLLED_JPUSH_FLUTTER_VERSION = "3.5.1"
CONTROLLED_JPUSH_ANDROID_VERSION = "6.2.0"
CONTROLLED_JCORE_ANDROID_VERSION = "5.5.2"


class GateError(ValueError):
    pass


def fail(message: str) -> None:
    raise GateError(message)


def parse_pubspec_version(path: Path) -> tuple[str, int]:
    match = re.search(
        r"(?m)^version:\s*([^\s+#]+)\+([1-9]\d*)\s*(?:#.*)?$",
        path.read_text(encoding="utf-8"),
    )
    if not match or not VERSION_RE.fullmatch(match.group(1)):
        fail("pubspec.yaml must contain version: X.Y.Z+positive_build.")
    return match.group(1), int(match.group(2))


def version_tuple(value: str) -> tuple[int, int, int]:
    if not VERSION_RE.fullmatch(value):
        fail(f"Invalid production version: {value!r}.")
    return tuple(int(part) for part in value.split("."))  # type: ignore[return-value]


def parse_release_tags(lines: Iterable[str]) -> list[tuple[str, int, str]]:
    parsed: list[tuple[str, int, str]] = []
    for raw in lines:
        tag = raw.strip()
        if not tag:
            continue
        match = TAG_RE.fullmatch(tag)
        if not match:
            fail(f"Malformed Android release tag blocks monotonic validation: {tag}.")
        parsed.append((match.group("version"), int(match.group("build")), tag))
    return parsed


def require_https(value: str, label: str, *, allow_query: bool = True) -> Any:
    raw = value.strip()
    if not raw or any(character.isspace() or ord(character) < 32 for character in raw):
        fail(f"{label} must be a valid public HTTPS URL.")
    parsed = urlparse(raw)
    try:
        port = parsed.port
    except ValueError:
        fail(f"{label} contains an invalid port.")
    if (
        parsed.scheme.lower() != "https"
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.fragment
        or (not allow_query and parsed.query)
    ):
        fail(f"{label} must be a public HTTPS URL without credentials or fragments.")
    hostname = parsed.hostname.lower()
    reserved = (
        hostname in {"example.com", "example.net", "example.org", "localhost"}
        or hostname.endswith((".example", ".invalid", ".localhost", ".test"))
    )
    if reserved:
        fail(f"{label} uses a reserved documentation hostname.")
    if port is not None and not 1 <= port <= 65535:
        fail(f"{label} contains an invalid port.")
    return parsed


def https_origin(value: str, label: str) -> tuple[str, int]:
    parsed = require_https(value, label)
    return parsed.hostname.lower().rstrip("."), parsed.port or 443


def verify_same_https_origin(requested: str, effective: str) -> None:
    if https_origin(requested, "Requested URL") != https_origin(
        effective,
        "Effective URL",
    ):
        fail("Redirected URL must remain on the requested HTTPS origin.")


def same_origin_command(args: argparse.Namespace) -> None:
    verify_same_https_origin(args.requested, args.effective)
    print("Effective URL remained on the requested HTTPS origin.")


def parse_allowed_hosts(raw: str) -> set[str]:
    hosts = {
        value.strip().lower().rstrip(".")
        for value in raw.split(",")
        if value.strip()
    }
    if not hosts:
        fail("SAYDIAN_UPDATE_ALLOWED_HOSTS must explicitly list production hosts.")
    for host in hosts:
        if not re.fullmatch(r"[a-z0-9.-]+", host) or ".." in host:
            fail(f"Invalid allowed host: {host!r}.")
    return hosts


def write_github_output(path: Path, values: dict[str, str]) -> None:
    with path.open("a", encoding="utf-8") as stream:
        for key, value in values.items():
            if "\n" in value or "\r" in value:
                fail(f"GitHub output {key} must be a single line.")
            stream.write(f"{key}={value}\n")


def metadata_command(args: argparse.Namespace) -> None:
    version, build = parse_pubspec_version(Path(args.pubspec))
    expected_tag = f"android-v{version}+{build}"
    if args.tag != expected_tag:
        fail(f"Release tag must be {expected_tag}, got {args.tag!r}.")

    minimum_build = int(args.minimum_supported_build)
    if minimum_build <= 0 or minimum_build > build:
        fail("minimum_supported_build must be positive and no greater than this build.")

    notes = Path(args.release_notes_file).read_text(encoding="utf-8").strip()
    if not notes:
        fail("Release notes are required; use an annotated tag or manual input.")
    if len(notes) > 8_000:
        fail("Release notes exceed 8,000 characters.")

    tags = parse_release_tags(Path(args.tags_file).read_text(encoding="utf-8").splitlines())
    previous = [item for item in tags if item[2] != args.tag]
    if previous:
        previous_build_entry = max(previous, key=lambda item: item[1])
        previous_version_entry = max(previous, key=lambda item: version_tuple(item[0]))
        if build <= previous_build_entry[1]:
            fail(
                f"Build {build} must be greater than {previous_build_entry[1]} "
                f"from {previous_build_entry[2]}."
            )
        if version_tuple(version) <= version_tuple(previous_version_entry[0]):
            fail(
                f"Version {version} must be greater than {previous_version_entry[0]} "
                f"from {previous_version_entry[2]}."
            )

    manifest = require_https(
        args.manifest_url,
        "SAYDIAN_UPDATE_MANIFEST_URL",
        allow_query=False,
    )
    if Path(manifest.path).name != "app-update.json":
        fail("SAYDIAN_UPDATE_MANIFEST_URL must end with /app-update.json.")
    apk_base = require_https(
        args.apk_base_url,
        "SAYDIAN_ANDROID_APK_BASE_URL",
        allow_query=False,
    )
    api_base = require_https(
        args.api_base_url,
        "SAYDIAN_API_BASE_URL",
        allow_query=False,
    )
    if api_base.path not in {"", "/"}:
        fail("SAYDIAN_API_BASE_URL must be an HTTPS origin without a path.")
    allowed_hosts = parse_allowed_hosts(args.allowed_hosts)
    required_hosts = {manifest.hostname.lower(), apk_base.hostname.lower()}
    missing_hosts = required_hosts - allowed_hosts
    if missing_hosts:
        fail(
            "SAYDIAN_UPDATE_ALLOWED_HOSTS is missing: "
            + ", ".join(sorted(missing_hosts))
        )

    filename = f"Saydian-{version}+{build}-release.apk"
    apk_url = args.apk_base_url.rstrip("/") + "/" + quote(filename, safe="+.-_")
    require_https(apk_url, "Derived Android APK URL", allow_query=False)
    outputs = {
        "version": version,
        "build": str(build),
        "release_tag": args.tag,
        "minimum_supported_build": str(minimum_build),
        "apk_filename": filename,
        "apk_public_url": apk_url,
        "manifest_url": args.manifest_url.strip(),
        "allowed_hosts": ",".join(sorted(allowed_hosts)),
        "api_base_url": args.api_base_url.rstrip("/"),
    }
    if args.output:
        write_github_output(Path(args.output), outputs)
    print(json.dumps(outputs, ensure_ascii=False, sort_keys=True))


def parse_datetime(value: Any) -> dt.datetime:
    raw = str(value or "").strip()
    parsed = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        fail("published_at must contain a timezone.")
    return parsed


def validate_release(release: dict[str, Any]) -> None:
    platform = str(release.get("platform", "")).strip().lower()
    if release.get("schema_version") != 1 or release.get("channel") != "production":
        fail("Every manifest release must use schema_version=1 and channel=production.")
    if platform not in {"android", "ios"}:
        fail("Manifest release platform must be android or ios.")
    version_tuple(str(release.get("latest_version", "")).strip())
    latest_build = release.get("latest_build")
    minimum_build = release.get("minimum_supported_build")
    if (
        not isinstance(latest_build, int)
        or isinstance(latest_build, bool)
        or latest_build <= 0
        or not isinstance(minimum_build, int)
        or isinstance(minimum_build, bool)
        or minimum_build <= 0
        or minimum_build > latest_build
    ):
        fail("Manifest build numbers are invalid.")
    if not str(release.get("release_notes", "")).strip():
        fail("Manifest release_notes must not be empty.")
    parse_datetime(release.get("published_at"))
    destination = release.get("destination")
    if not isinstance(destination, dict):
        fail("Manifest destination is missing.")
    destination_type = str(destination.get("type", "")).strip()
    destination_url = str(destination.get("url", "")).strip()
    parsed_url = require_https(destination_url, "Manifest destination URL")
    if platform == "ios":
        if (
            destination_type != "app_store"
            or parsed_url.hostname.lower() != "apps.apple.com"
            or not APP_STORE_PRODUCT_PATH_RE.fullmatch(parsed_url.path)
        ):
            fail("iOS production releases must point to a concrete apps.apple.com product page.")
    elif destination_type == "android_apk":
        digest = str(release.get("sha256", destination.get("sha256", ""))).lower()
        if not SHA256_RE.fullmatch(digest) or digest == "0" * 64:
            fail("Android APK releases require a lowercase SHA-256 digest.")
    elif destination_type != "android_store":
        fail("Android destination type must be android_apk or android_store.")


def releases_from_root(root: dict[str, Any]) -> list[dict[str, Any]]:
    if not root:
        return []
    releases = root.get("releases")
    if isinstance(releases, list):
        result = []
        for item in releases:
            if not isinstance(item, dict):
                fail("Manifest releases must be JSON objects.")
            result.append(dict(item))
        return result
    if any(key in root for key in ("android", "ios")):
        result = []
        for platform in ("ios", "android"):
            item = root.get(platform)
            if item is None:
                continue
            if not isinstance(item, dict):
                fail(f"Manifest {platform} entry must be an object.")
            result.append(
                {
                    "schema_version": root.get("schema_version"),
                    "channel": root.get("channel"),
                    "platform": platform,
                    **item,
                }
            )
        return result
    return [dict(root)]


def load_existing_manifest(path: str | None) -> list[dict[str, Any]]:
    if not path:
        return []
    source = Path(path)
    if not source.is_file() or source.stat().st_size == 0:
        return []
    try:
        root = json.loads(source.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        fail(f"Existing production manifest is malformed: {error}.")
    if not isinstance(root, dict):
        fail("Existing production manifest root must be an object.")
    releases = releases_from_root(root)
    for release in releases:
        validate_release(release)
    platforms = [str(item["platform"]).lower() for item in releases]
    if len(platforms) != len(set(platforms)):
        fail("Existing production manifest contains duplicate platform entries.")
    return releases


def atomic_json_write(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, sort_keys=True)
        stream.write("\n")
        temporary = Path(stream.name)
    os.replace(temporary, path)


def build_android_release(args: argparse.Namespace) -> dict[str, Any]:
    digest = args.sha256.strip().lower()
    if not SHA256_RE.fullmatch(digest):
        fail("sha256 must contain exactly 64 lowercase hexadecimal characters.")
    require_https(args.apk_url, "Android APK URL")
    release = {
        "schema_version": 1,
        "platform": "android",
        "channel": "production",
        "latest_version": args.version,
        "latest_build": int(args.build),
        "minimum_supported_build": int(args.minimum_supported_build),
        "release_notes": Path(args.release_notes_file)
        .read_text(encoding="utf-8")
        .strip(),
        "published_at": args.published_at,
        "destination": {"type": "android_apk", "url": args.apk_url},
        "sha256": digest,
    }
    validate_release(release)
    return release


def manifest_command(args: argparse.Namespace) -> None:
    existing = load_existing_manifest(args.existing)
    android = build_android_release(args)
    previous_android = next(
        (
            item
            for item in existing
            if str(item.get("platform", "")).lower() == "android"
        ),
        None,
    )
    if previous_android is not None:
        if int(android["latest_build"]) <= int(previous_android["latest_build"]):
            fail("Candidate Android build must be greater than the live manifest build.")
        if version_tuple(str(android["latest_version"])) <= version_tuple(
            str(previous_android["latest_version"])
        ):
            fail("Candidate Android version must be greater than the live manifest version.")
    preserved = [item for item in existing if str(item["platform"]).lower() != "android"]
    result = {
        "schema_version": 1,
        "channel": "production",
        "releases": [*preserved, android],
    }
    atomic_json_write(Path(args.output), result)
    print(f"Prepared production manifest with {len(result['releases'])} platform release(s).")


def find_platform_release(root: dict[str, Any], platform: str) -> dict[str, Any]:
    matches = [
        item
        for item in releases_from_root(root)
        if str(item.get("platform", "")).lower() == platform
    ]
    if len(matches) != 1:
        fail(f"Manifest must contain exactly one {platform} release.")
    validate_release(matches[0])
    return matches[0]


def verify_manifest_command(args: argparse.Namespace) -> None:
    try:
        root = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        fail(f"Manifest JSON is invalid: {error}.")
    if not isinstance(root, dict):
        fail("Manifest root must be an object.")
    release = find_platform_release(root, "android")
    expected = {
        "latest_version": args.version,
        "latest_build": int(args.build),
        "minimum_supported_build": int(args.minimum_supported_build),
        "sha256": args.sha256.lower(),
    }
    for key, value in expected.items():
        if release.get(key) != value:
            fail(f"Manifest {key} does not match the release artifact.")
    destination = release["destination"]
    if destination.get("type") != "android_apk" or destination.get("url") != args.apk_url:
        fail("Manifest APK destination does not match the public release URL.")
    if args.apk_file:
        digest = hashlib.sha256(Path(args.apk_file).read_bytes()).hexdigest()
        if digest != args.sha256.lower():
            fail("Local APK bytes do not match the manifest SHA-256.")
    print("Production Android manifest verification passed.")


def apk_manifest_command(args: argparse.Namespace) -> None:
    expected_key = os.environ.get("JPUSH_APP_KEY", "").strip()
    expected_channel = os.environ.get("JPUSH_CHANNEL", "").strip()
    if not expected_key or not expected_channel:
        fail("JPUSH_APP_KEY and JPUSH_CHANNEL are required for APK inspection.")
    root = ET.parse(args.xml).getroot()
    if root.attrib.get("package") != args.expected_package:
        fail("Built APK package name is not the production applicationId.")
    if root.attrib.get(f"{{{ANDROID_NS}}}versionName") != args.expected_version:
        fail("Built APK versionName does not match the gated release version.")
    if root.attrib.get(f"{{{ANDROID_NS}}}versionCode") != str(args.expected_build):
        fail("Built APK versionCode does not match the gated release build.")
    text = Path(args.xml).read_text(encoding="utf-8")
    if "${" in text:
        fail("Built APK manifest still contains unresolved placeholders.")
    permissions = {
        item.attrib.get(f"{{{ANDROID_NS}}}name", "")
        for item in root
        if item.tag in {"uses-permission", "uses-permission-sdk-23"}
    }
    forbidden = sorted(permissions & FORBIDDEN_ANDROID_PERMISSIONS)
    if forbidden:
        fail(
            "Built APK manifest contains forbidden permission(s): "
            + ", ".join(forbidden)
        )
    application = root.find("application")
    if application is None:
        fail("Built APK manifest is missing the application element.")
    required_application_attributes = {
        "allowBackup": "false",
        "fullBackupContent": "false",
        "usesCleartextTraffic": "false",
        "networkSecurityConfig": "@xml/network_security_config",
        "dataExtractionRules": "@xml/data_extraction_rules",
    }
    for name, expected_value in required_application_attributes.items():
        actual = application.attrib.get(f"{{{ANDROID_NS}}}{name}", "")
        if actual != expected_value:
            fail(f"Built APK manifest has unsafe or missing android:{name}.")
    features = {
        item.attrib.get(f"{{{ANDROID_NS}}}name", ""): item.attrib.get(
            f"{{{ANDROID_NS}}}required", "true"
        )
        for item in root.findall("uses-feature")
    }
    for feature in sorted(OPTIONAL_ANDROID_FEATURES):
        if features.get(feature) != "false":
            fail(f"Built APK manifest must keep {feature} optional.")
    for tag, component_name in INTERNAL_ANDROID_COMPONENTS:
        for item in application.findall(tag):
            if item.attrib.get(f"{{{ANDROID_NS}}}name") != component_name:
                continue
            if item.attrib.get(f"{{{ANDROID_NS}}}exported") != "false":
                fail(f"Built APK manifest exposes internal component {component_name}.")
    values: dict[str, str] = {}
    for item in root.iter("meta-data"):
        name = item.attrib.get(f"{{{ANDROID_NS}}}name", "")
        value = item.attrib.get(f"{{{ANDROID_NS}}}value", "")
        if name:
            values[name] = value
    expected = {
        "JPUSH_APPKEY": expected_key,
        "JPUSH_CHANNEL": expected_channel,
    }
    vendor_map = {
        "xiaomi": {"XIAOMI_APPKEY": "JPUSH_XIAOMI_APP_KEY", "XIAOMI_APPID": "JPUSH_XIAOMI_APP_ID"},
        "meizu": {"MEIZU_APPKEY": "JPUSH_MEIZU_APP_KEY", "MEIZU_APPID": "JPUSH_MEIZU_APP_ID"},
        "vivo": {
            "com.vivo.push.api_key": "JPUSH_VIVO_APP_KEY",
            "com.vivo.push.app_id": "JPUSH_VIVO_APP_ID",
        },
        "oppo": {
            "OPPO_APPKEY": "JPUSH_OPPO_APP_KEY",
            "OPPO_APPID": "JPUSH_OPPO_APP_ID",
            "OPPO_APPSECRET": "JPUSH_OPPO_APP_SECRET",
        },
        "honor": {"com.hihonor.push.app_id": "JPUSH_HONOR_APP_ID"},
    }
    enabled = {
        value.strip().lower()
        for value in os.environ.get("JPUSH_VENDOR_CHANNELS", "").split(",")
        if value.strip() and value.strip().lower() != "none"
    }
    for vendor, mappings in vendor_map.items():
        if vendor not in enabled:
            continue
        for manifest_name, environment_name in mappings.items():
            value = os.environ.get(environment_name, "").strip()
            if vendor == "meizu":
                value = "MZ-" + value
            elif vendor == "oppo":
                value = "OP-" + value
            expected[manifest_name] = value
    for name, value in expected.items():
        if values.get(name) != value:
            fail(f"Built APK manifest is missing or mismatches {name}.")
    print("Production package and JPush manifest inspection passed.")


def apk_abis_command(args: argparse.Namespace) -> None:
    required = set(PRODUCTION_ANDROID_ABIS)
    libraries: dict[str, set[str]] = {}
    seen_members: set[str] = set()
    with zipfile.ZipFile(args.apk) as archive:
        for info in archive.infolist():
            name = info.filename
            if name in seen_members:
                fail(f"APK contains a duplicate ZIP member: {name}.")
            seen_members.add(name)
            match = re.fullmatch(r"lib/([^/]+)/([^/]+\.so)", name)
            if match:
                libraries.setdefault(match.group(1), set()).add(match.group(2))
    present = set(libraries)
    missing = required - present
    unexpected = present - required
    if missing:
        fail("APK is missing required ABI(s): " + ", ".join(sorted(missing)))
    if unexpected:
        fail("APK contains unexpected ABI(s): " + ", ".join(sorted(unexpected)))
    baseline_abi = PRODUCTION_ANDROID_ABIS[0]
    baseline = libraries[baseline_abi]
    if not baseline:
        fail(f"APK contains no native libraries for {baseline_abi}.")
    for abi in PRODUCTION_ANDROID_ABIS[1:]:
        missing_libraries = baseline - libraries[abi]
        extra_libraries = libraries[abi] - baseline
        if (
            not missing_libraries
            and extra_libraries == {CONTROLLED_ARM64_ONLY_LIBRARY}
        ):
            verify_controlled_jpush_abi_exception(args)
            print(
                "Accepted controlled JPush ABI exception: "
                f"{CONTROLLED_ARM64_ONLY_LIBRARY} is arm64-v8a-only under "
                f"jpush_flutter {CONTROLLED_JPUSH_FLUTTER_VERSION}, "
                f"JPush {CONTROLLED_JPUSH_ANDROID_VERSION}, and "
                f"JCore {CONTROLLED_JCORE_ANDROID_VERSION}."
            )
            continue
        if missing_libraries or extra_libraries:
            details = []
            if missing_libraries:
                details.append(
                    f"{abi} missing " + ", ".join(sorted(missing_libraries))
                )
            if extra_libraries:
                details.append(
                    f"{abi} only " + ", ".join(sorted(extra_libraries))
                )
            fail("APK native libraries are not ABI-symmetric: " + "; ".join(details))
    print(
        "Production APK ABI verification passed for "
        + ", ".join(PRODUCTION_ANDROID_ABIS)
        + "."
    )


def locked_pub_version(path: Path, package: str) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        rf"(?ms)^  {re.escape(package)}:\n(?P<body>(?:    .*\n)+?)(?=^  \S|\Z)",
        text,
    )
    if not match:
        fail(f"pubspec.lock does not contain {package}.")
    version = re.search(r'(?m)^    version: "([^"]+)"$', match.group("body"))
    if not version:
        fail(f"pubspec.lock does not contain a version for {package}.")
    return version.group(1)


def resolved_maven_versions(report: str, coordinate: str) -> set[str]:
    versions: set[str] = set()
    pattern = re.compile(
        rf"{re.escape(coordinate)}:([^\s]+)(?:\s+->\s+([0-9]+\.[0-9]+\.[0-9]+))?"
    )
    for requested, resolved in pattern.findall(report):
        candidate = resolved or requested
        if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", candidate):
            versions.add(candidate)
    return versions


def verify_controlled_jpush_abi_exception(args: argparse.Namespace) -> None:
    dependency_report = getattr(args, "dependency_report", None)
    pubspec_lock = getattr(args, "pubspec_lock", None)
    if not dependency_report or not pubspec_lock:
        fail(
            "The arm64-only libjutils.so exception requires a Gradle dependency "
            "report and pubspec.lock."
        )
    flutter_version = locked_pub_version(Path(pubspec_lock), "jpush_flutter")
    if flutter_version != CONTROLLED_JPUSH_FLUTTER_VERSION:
        fail(
            "The arm64-only libjutils.so exception is not approved for "
            f"jpush_flutter {flutter_version}."
        )
    report = Path(dependency_report).read_text(encoding="utf-8")
    jpush_versions = resolved_maven_versions(report, "cn.jiguang.sdk:jpush")
    jcore_versions = resolved_maven_versions(report, "cn.jiguang.sdk:jcore")
    if jpush_versions != {CONTROLLED_JPUSH_ANDROID_VERSION}:
        fail(
            "The arm64-only libjutils.so exception requires resolved JPush "
            f"{CONTROLLED_JPUSH_ANDROID_VERSION}; found {sorted(jpush_versions)}."
        )
    if jcore_versions != {CONTROLLED_JCORE_ANDROID_VERSION}:
        fail(
            "The arm64-only libjutils.so exception requires resolved JCore "
            f"{CONTROLLED_JCORE_ANDROID_VERSION}; found {sorted(jcore_versions)}."
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    metadata = subparsers.add_parser("metadata")
    metadata.add_argument("--pubspec", required=True)
    metadata.add_argument("--tag", required=True)
    metadata.add_argument("--minimum-supported-build", required=True)
    metadata.add_argument("--release-notes-file", required=True)
    metadata.add_argument("--manifest-url", required=True)
    metadata.add_argument("--apk-base-url", required=True)
    metadata.add_argument("--api-base-url", required=True)
    metadata.add_argument("--allowed-hosts", required=True)
    metadata.add_argument("--tags-file", required=True)
    metadata.add_argument("--output")
    metadata.set_defaults(handler=metadata_command)

    manifest = subparsers.add_parser("manifest")
    manifest.add_argument("--existing")
    manifest.add_argument("--output", required=True)
    manifest.add_argument("--version", required=True)
    manifest.add_argument("--build", required=True, type=int)
    manifest.add_argument("--minimum-supported-build", required=True, type=int)
    manifest.add_argument("--release-notes-file", required=True)
    manifest.add_argument("--published-at", required=True)
    manifest.add_argument("--apk-url", required=True)
    manifest.add_argument("--sha256", required=True)
    manifest.set_defaults(handler=manifest_command)

    verify = subparsers.add_parser("verify-manifest")
    verify.add_argument("--manifest", required=True)
    verify.add_argument("--version", required=True)
    verify.add_argument("--build", required=True, type=int)
    verify.add_argument("--minimum-supported-build", required=True, type=int)
    verify.add_argument("--apk-url", required=True)
    verify.add_argument("--sha256", required=True)
    verify.add_argument("--apk-file")
    verify.set_defaults(handler=verify_manifest_command)

    apk_manifest = subparsers.add_parser("apk-manifest")
    apk_manifest.add_argument("--xml", required=True)
    apk_manifest.add_argument("--expected-package", required=True)
    apk_manifest.add_argument("--expected-version", required=True)
    apk_manifest.add_argument("--expected-build", required=True, type=int)
    apk_manifest.set_defaults(handler=apk_manifest_command)

    apk_abis = subparsers.add_parser("apk-abis")
    apk_abis.add_argument("--apk", required=True)
    apk_abis.add_argument("--dependency-report")
    apk_abis.add_argument("--pubspec-lock")
    apk_abis.set_defaults(handler=apk_abis_command)

    same_origin = subparsers.add_parser("same-origin")
    same_origin.add_argument("--requested", required=True)
    same_origin.add_argument("--effective", required=True)
    same_origin.set_defaults(handler=same_origin_command)
    return parser


def main(argv: list[str] | None = None) -> int:
    try:
        args = build_parser().parse_args(argv)
        args.handler(args)
        return 0
    except (GateError, OSError, ValueError, ET.ParseError, zipfile.BadZipFile) as error:
        print(f"release gate failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
