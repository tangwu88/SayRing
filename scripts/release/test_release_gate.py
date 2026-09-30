#!/usr/bin/env python3

from __future__ import annotations

import argparse
import base64
import importlib.util
import json
import os
import plistlib
import re
import subprocess
import tempfile
import textwrap
import unittest
import zipfile
from pathlib import Path
from unittest import mock


HERE = Path(__file__).resolve().parent


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gate = load_module("release_gate", "release_gate.py")
push = load_module("prepare_push_config", "prepare_push_config.py")
XCODE_RELEASE_GATE = HERE / "validate_xcode_release.sh"


class ReleaseGateTest(unittest.TestCase):
    def test_ios_vendor_sdk_usage_descriptions_are_explicit(self) -> None:
        info = plistlib.loads((HERE.parents[1] / "ios/Runner/Info.plist").read_bytes())
        for key in (
            "NSAppleMusicUsageDescription",
            "NSSpeechRecognitionUsageDescription",
        ):
            with self.subTest(key=key):
                self.assertIn(key, info)
                self.assertIn("integrated device SDK", info[key])
                self.assertIn("This version does not offer", info[key])
                self.assertIn("you may decline access", info[key])
                self.assertNotIn("$(", info[key])

    def test_ios_vendor_sdk_usage_descriptions_cover_all_locales(self) -> None:
        runner = HERE.parents[1] / "ios/Runner"
        info = plistlib.loads((runner / "Info.plist").read_bytes())
        for locale in ("en", "zh-Hans", "zh-Hant", "de", "fr", "es", "ja", "ko"):
            entries = re.findall(
                r'^"([^"\\]+)"\s*=\s*"((?:\\.|[^"\\])*)";$',
                (runner / f"{locale}.lproj/InfoPlist.strings").read_text(encoding="utf-8"),
                flags=re.MULTILINE,
            )
            for key in (
                "NSAppleMusicUsageDescription",
                "NSSpeechRecognitionUsageDescription",
            ):
                with self.subTest(locale=locale, key=key):
                    values = [value for entry_key, value in entries if entry_key == key]
                    self.assertEqual(len(values), 1)
                    self.assertGreater(len(values[0].strip()), 20)
                    self.assertIn("SDK", values[0])
                    self.assertNotIn("$(", values[0])
                    if locale == "en":
                        self.assertEqual(info[key], values[0])

    def test_ios_vendor_descriptions_do_not_add_background_permissions(self) -> None:
        info = plistlib.loads((HERE.parents[1] / "ios/Runner/Info.plist").read_bytes())
        self.assertEqual(info["UIBackgroundModes"], ["bluetooth-central"])
        self.assertNotIn("NSLocationAlwaysUsageDescription", info)
        self.assertNotIn("NSLocationAlwaysAndWhenInUseUsageDescription", info)
        self.assertNotIn("NSMicrophoneUsageDescription", info)
        self.assertIn("NSLocationWhenInUseUsageDescription", info)

    def test_apk_numeric_resources_must_resolve_uniquely_from_actual_table(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            resources = Path(directory) / "resources.txt"
            resources.write_text(
                "    resource 0x7f100003 xml/network_security_config\n"
                "    resource 0x7f100000 xml/data_extraction_rules\n",
                encoding="utf-8",
            )
            self.assertEqual(
                gate.resolve_apk_resource("@ref/0x7f100003", str(resources)),
                "@xml/network_security_config",
            )
            self.assertEqual(
                gate.resolve_apk_resource("@ref/0x7f100000", str(resources)),
                "@xml/data_extraction_rules",
            )
            for reference, table in [
                ("@ref/0x7f100003", None),
                ("@ref/0x7f100004", str(resources)),
                ("@ref/../malformed", str(resources)),
            ]:
                with self.subTest(reference=reference, table=table):
                    with self.assertRaises(gate.GateError):
                        gate.resolve_apk_resource(reference, table)
            resources.write_text(
                "resource 0x7f100003 xml/network_security_config\n"
                "resource 0x7f100003 xml/untrusted_rules\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(gate.GateError, "ambiguous"):
                gate.resolve_apk_resource("@ref/0x7f100003", str(resources))

    def test_metadata_requires_version_and_build_to_increase(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text("version: 0.2.0+24\n", encoding="utf-8")
            (root / "tags").write_text("android-v0.2.0+23\n", encoding="utf-8")
            (root / "notes").write_text("Production fixes\n", encoding="utf-8")
            args = argparse.Namespace(
                pubspec=str(root / "pubspec.yaml"),
                tag="android-v0.2.0+24",
                minimum_supported_build="23",
                release_notes_file=str(root / "notes"),
                manifest_url="https://download.saidian.cn/app-update.json",
                apk_base_url="https://download.saidian.cn/android",
                api_base_url="https://app.saidian.cc",
                allowed_hosts="download.saidian.cn",
                tags_file=str(root / "tags"),
                output=None,
            )
            with self.assertRaises(gate.GateError):
                gate.metadata_command(args)

            (root / "pubspec.yaml").write_text("version: 0.2.1+24\n", encoding="utf-8")
            args.tag = "android-v0.2.1+24"
            gate.metadata_command(args)

            # The highest semantic version and highest build can belong to
            # different historical tags; both maxima remain monotonic gates.
            (root / "tags").write_text(
                "android-v0.3.0+20\nandroid-v0.2.0+23\n",
                encoding="utf-8",
            )
            with self.assertRaises(gate.GateError):
                gate.metadata_command(args)

    def test_manifest_preserves_ios_and_replaces_android(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            existing = {
                "schema_version": 1,
                "channel": "production",
                "releases": [
                    self.ios_release(),
                    self.android_release(build=23, sha="1" * 64),
                ],
            }
            (root / "existing.json").write_text(json.dumps(existing), encoding="utf-8")
            (root / "notes").write_text("New Android release\n", encoding="utf-8")
            args = argparse.Namespace(
                existing=str(root / "existing.json"),
                output=str(root / "output.json"),
                version="0.2.1",
                build=24,
                minimum_supported_build=23,
                release_notes_file=str(root / "notes"),
                published_at="2026-08-29T01:00:00Z",
                apk_url="https://download.saidian.cn/android/Saydian-0.2.1+24-release.apk",
                sha256="2" * 64,
            )
            gate.manifest_command(args)
            generated = json.loads((root / "output.json").read_text(encoding="utf-8"))
            self.assertEqual(["ios", "android"], [item["platform"] for item in generated["releases"]])
            self.assertEqual(24, generated["releases"][1]["latest_build"])
            self.assertEqual("2" * 64, generated["releases"][1]["sha256"])

    def test_manifest_rejects_rollback_against_live_release(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            existing = {
                "schema_version": 1,
                "channel": "production",
                "releases": [self.android_release(build=200, sha="1" * 64)],
            }
            existing["releases"][0]["latest_version"] = "2.0.0"
            (root / "existing.json").write_text(json.dumps(existing), encoding="utf-8")
            (root / "notes").write_text("Rollback attempt\n", encoding="utf-8")
            args = argparse.Namespace(
                existing=str(root / "existing.json"),
                output=str(root / "output.json"),
                version="1.9.0",
                build=199,
                minimum_supported_build=100,
                release_notes_file=str(root / "notes"),
                published_at="2026-08-29T01:00:00Z",
                apk_url="https://download.saidian.cn/android/Saydian-1.9.0+199-release.apk",
                sha256="2" * 64,
            )
            with self.assertRaises(gate.GateError):
                gate.manifest_command(args)

    def test_ios_release_requires_a_concrete_app_store_product(self) -> None:
        release = self.ios_release()
        release["destination"] = {
            "type": "app_store",
            "url": "https://apps.apple.com/",
        }
        with self.assertRaises(gate.GateError):
            gate.validate_release(release)

    def test_verify_rejects_manifest_hash_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {
                "schema_version": 1,
                "channel": "production",
                "releases": [self.android_release(build=24, sha="2" * 64)],
            }
            path = root / "manifest.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            args = argparse.Namespace(
                manifest=str(path),
                version="0.2.1",
                build=24,
                minimum_supported_build=23,
                apk_url=manifest["releases"][0]["destination"]["url"],
                sha256="3" * 64,
                apk_file=None,
            )
            with self.assertRaises(gate.GateError):
                gate.verify_manifest_command(args)

    def test_apk_manifest_requires_gated_version_and_push_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text(
                textwrap.dedent(
                    f'''\
                    <manifest xmlns:android="{gate.ANDROID_NS}"
                        package="cc.saidian.app"
                        android:versionName="0.2.1"
                        android:versionCode="24">
                      <uses-feature android:name="android.hardware.camera"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.any"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.autofocus"
                          android:required="false" />
                      <application android:allowBackup="false"
                          android:fullBackupContent="false"
                          android:usesCleartextTraffic="false"
                          android:networkSecurityConfig="@xml/network_security_config"
                          android:dataExtractionRules="@xml/data_extraction_rules">
                        <meta-data android:name="JPUSH_APPKEY"
                            android:value="0123456789abcdef01234567" />
                        <meta-data android:name="JPUSH_CHANNEL"
                            android:value="production" />
                      </application>
                    </manifest>
                    '''
                ),
                encoding="utf-8",
            )
            args = argparse.Namespace(
                xml=str(manifest),
                expected_package="cc.saidian.app",
                expected_version="0.2.1",
                expected_build=24,
            )
            environment = {
                "JPUSH_APP_KEY": "0123456789abcdef01234567",
                "JPUSH_CHANNEL": "production",
                "JPUSH_VENDOR_CHANNELS": "none",
            }
            with mock.patch.dict(os.environ, environment, clear=True):
                gate.apk_manifest_command(args)
                args.expected_build = 25
                with self.assertRaises(gate.GateError):
                    gate.apk_manifest_command(args)
                args.expected_build = 24
                manifest.write_text(
                    manifest.read_text(encoding="utf-8").replace(
                        "<application ",
                        '<uses-feature android:name="android.bluetooth.le" '
                        'android:required="true" /><application ',
                        1,
                    ),
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(gate.GateError, "invalid Bluetooth feature"):
                    gate.apk_manifest_command(args)

    def test_apk_manifest_rejects_forbidden_permissions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text(
                textwrap.dedent(
                    f'''\
                    <manifest xmlns:android="{gate.ANDROID_NS}"
                        package="cc.saidian.app"
                        android:versionName="0.2.1"
                        android:versionCode="24">
                      <uses-permission android:name="android.permission.READ_PHONE_STATE" />
                      <uses-feature android:name="android.hardware.camera"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.any"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.autofocus"
                          android:required="false" />
                      <application android:allowBackup="false"
                          android:fullBackupContent="false"
                          android:usesCleartextTraffic="false"
                          android:networkSecurityConfig="@xml/network_security_config"
                          android:dataExtractionRules="@xml/data_extraction_rules">
                        <meta-data android:name="JPUSH_APPKEY"
                            android:value="0123456789abcdef01234567" />
                        <meta-data android:name="JPUSH_CHANNEL"
                            android:value="production" />
                      </application>
                    </manifest>
                    '''
                ),
                encoding="utf-8",
            )
            args = argparse.Namespace(
                xml=str(manifest),
                expected_package="cc.saidian.app",
                expected_version="0.2.1",
                expected_build=24,
            )
            environment = {
                "JPUSH_APP_KEY": "0123456789abcdef01234567",
                "JPUSH_CHANNEL": "production",
                "JPUSH_VENDOR_CHANNELS": "none",
            }
            with mock.patch.dict(os.environ, environment, clear=True):
                with self.assertRaisesRegex(gate.GateError, "forbidden permission"):
                    gate.apk_manifest_command(args)

    def test_apk_manifest_rejects_unsafe_backup_and_exported_vendor_component(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text(
                textwrap.dedent(
                    f'''\
                    <manifest xmlns:android="{gate.ANDROID_NS}"
                        package="cc.saidian.app"
                        android:versionName="0.2.1"
                        android:versionCode="24">
                      <uses-feature android:name="android.hardware.camera"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.any"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.autofocus"
                          android:required="false" />
                      <application android:allowBackup="true"
                          android:fullBackupContent="false"
                          android:usesCleartextTraffic="false"
                          android:networkSecurityConfig="@xml/network_security_config"
                          android:dataExtractionRules="@xml/data_extraction_rules">
                        <service
                            android:name="com.yucheng.ycbtsdk.upgrade.utils.DfuService"
                            android:exported="true" />
                        <meta-data android:name="JPUSH_APPKEY"
                            android:value="0123456789abcdef01234567" />
                        <meta-data android:name="JPUSH_CHANNEL"
                            android:value="production" />
                      </application>
                    </manifest>
                    '''
                ),
                encoding="utf-8",
            )
            args = argparse.Namespace(
                xml=str(manifest),
                expected_package="cc.saidian.app",
                expected_version="0.2.1",
                expected_build=24,
            )
            environment = {
                "JPUSH_APP_KEY": "0123456789abcdef01234567",
                "JPUSH_CHANNEL": "production",
                "JPUSH_VENDOR_CHANNELS": "none",
            }
            with mock.patch.dict(os.environ, environment, clear=True):
                with self.assertRaisesRegex(gate.GateError, "allowBackup"):
                    gate.apk_manifest_command(args)

                text = manifest.read_text(encoding="utf-8")
                manifest.write_text(
                    text.replace('android:allowBackup="true"', 'android:allowBackup="false"'),
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(gate.GateError, "exposes internal component"):
                    gate.apk_manifest_command(args)

    def test_apk_manifest_uses_final_vivo_and_honor_metadata_names(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "AndroidManifest.xml"
            manifest.write_text(
                textwrap.dedent(
                    f'''\
                    <manifest xmlns:android="{gate.ANDROID_NS}"
                        package="cc.saidian.app"
                        android:versionName="0.2.1"
                        android:versionCode="24">
                      <uses-feature android:name="android.hardware.camera"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.any"
                          android:required="false" />
                      <uses-feature android:name="android.hardware.camera.autofocus"
                          android:required="false" />
                      <application android:allowBackup="false"
                          android:fullBackupContent="false"
                          android:usesCleartextTraffic="false"
                          android:networkSecurityConfig="@xml/network_security_config"
                          android:dataExtractionRules="@xml/data_extraction_rules">
                        <meta-data android:name="JPUSH_APPKEY"
                            android:value="test-jpush-app-key" />
                        <meta-data android:name="JPUSH_CHANNEL"
                            android:value="production" />
                        <meta-data android:name="com.vivo.push.api_key"
                            android:value="test-vivo-key" />
                        <meta-data android:name="com.vivo.push.app_id"
                            android:value="test-vivo-id" />
                        <meta-data android:name="com.hihonor.push.app_id"
                            android:value="test-honor-id" />
                      </application>
                    </manifest>
                    '''
                ),
                encoding="utf-8",
            )
            args = argparse.Namespace(
                xml=str(manifest),
                expected_package="cc.saidian.app",
                expected_version="0.2.1",
                expected_build=24,
            )
            environment = {
                "JPUSH_APP_KEY": "test-jpush-app-key",
                "JPUSH_CHANNEL": "production",
                "JPUSH_VENDOR_CHANNELS": "vivo,honor",
                "JPUSH_VIVO_APP_KEY": "test-vivo-key",
                "JPUSH_VIVO_APP_ID": "test-vivo-id",
                "JPUSH_HONOR_APP_ID": "test-honor-id",
            }
            with mock.patch.dict(os.environ, environment, clear=True):
                gate.apk_manifest_command(args)

            text = manifest.read_text(encoding="utf-8")
            manifest.write_text(
                text.replace("com.vivo.push.api_key", "VIVO_APPKEY"),
                encoding="utf-8",
            )
            with mock.patch.dict(os.environ, environment, clear=True):
                with self.assertRaisesRegex(gate.GateError, "missing or mismatches"):
                    gate.apk_manifest_command(args)

    def test_redirect_must_remain_on_same_https_origin(self) -> None:
        gate.verify_same_https_origin(
            "https://download.saidian.cn/app-update.json?attempt=1",
            "https://download.saidian.cn/releases/app-update.json",
        )
        gate.verify_same_https_origin(
            "https://download.saidian.cn:443/app-update.json",
            "https://download.saidian.cn/app-update.json",
        )
        with self.assertRaises(gate.GateError):
            gate.verify_same_https_origin(
                "https://download.saidian.cn/app-update.json",
                "https://cdn.saidian.cn/app-update.json",
            )
        with self.assertRaises(gate.GateError):
            gate.verify_same_https_origin(
                "https://download.saidian.cn/app-update.json",
                "https://download.saidian.cn:8443/app-update.json",
            )
        with self.assertRaises(gate.GateError):
            gate.verify_same_https_origin(
                "https://download.saidian.cn/app-update.json",
                "http://download.saidian.cn/app-update.json",
            )

    def test_apk_native_libraries_must_be_dual_abi_and_symmetric(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            valid = root / "valid.apk"
            with zipfile.ZipFile(valid, "w") as archive:
                for abi in gate.PRODUCTION_ANDROID_ABIS:
                    archive.writestr(f"lib/{abi}/libapp.so", b"fixture")
                    archive.writestr(f"lib/{abi}/libvendor.so", b"fixture")
            gate.apk_abis_command(argparse.Namespace(apk=str(valid)))

            asymmetric = root / "asymmetric.apk"
            with zipfile.ZipFile(asymmetric, "w") as archive:
                archive.writestr("lib/armeabi-v7a/libapp.so", b"fixture")
                archive.writestr("lib/arm64-v8a/libapp.so", b"fixture")
                archive.writestr("lib/arm64-v8a/libvendor.so", b"fixture")
            with self.assertRaisesRegex(gate.GateError, "not ABI-symmetric"):
                gate.apk_abis_command(argparse.Namespace(apk=str(asymmetric)))

            unexpected = root / "unexpected.apk"
            with zipfile.ZipFile(unexpected, "w") as archive:
                for abi in (*gate.PRODUCTION_ANDROID_ABIS, "x86_64"):
                    archive.writestr(f"lib/{abi}/libapp.so", b"fixture")
            with self.assertRaisesRegex(gate.GateError, "unexpected ABI"):
                gate.apk_abis_command(argparse.Namespace(apk=str(unexpected)))

    def test_jutils_arm64_exception_requires_exact_locked_jpush_stack(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "jpush.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                for abi in gate.PRODUCTION_ANDROID_ABIS:
                    archive.writestr(f"lib/{abi}/libapp.so", b"fixture")
                archive.writestr("lib/arm64-v8a/libjutils.so", b"fixture")
            lock = root / "pubspec.lock"
            lock.write_text(
                textwrap.dedent(
                    '''\
                    packages:
                      jpush_flutter:
                        dependency: "direct main"
                        description:
                          name: jpush_flutter
                        source: hosted
                        version: "3.5.1"
                    '''
                ),
                encoding="utf-8",
            )
            report = root / "dependencies.txt"
            report.write_text(
                "+--- cn.jiguang.sdk:jpush:6.2.0\n"
                "|    \\--- cn.jiguang.sdk:jcore:[1.0.0,) -> 5.5.2\n",
                encoding="utf-8",
            )
            args = argparse.Namespace(
                apk=str(apk),
                dependency_report=str(report),
                pubspec_lock=str(lock),
            )
            gate.apk_abis_command(args)

            report.write_text(
                "+--- cn.jiguang.sdk:jpush:6.2.0\n"
                "|    \\--- cn.jiguang.sdk:jcore:[1.0.0,) -> 5.5.1\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(gate.GateError, "requires resolved JCore"):
                gate.apk_abis_command(args)

            report.write_text(
                "+--- cn.jiguang.sdk:jpush:6.2.0\n"
                "|    \\--- cn.jiguang.sdk:jcore:[1.0.0,) -> 5.5.2\n",
                encoding="utf-8",
            )
            lock.write_text(
                lock.read_text(encoding="utf-8").replace('"3.5.1"', '"3.5.2"'),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(gate.GateError, "not approved"):
                gate.apk_abis_command(args)

    @staticmethod
    def ios_release() -> dict[str, object]:
        return {
            "schema_version": 1,
            "platform": "ios",
            "channel": "production",
            "latest_version": "0.2.0",
            "latest_build": 23,
            "minimum_supported_build": 20,
            "release_notes": "iOS production",
            "published_at": "2026-08-28T01:00:00Z",
            "destination": {
                "type": "app_store",
                "url": "https://apps.apple.com/app/id1234567890",
            },
        }

    @staticmethod
    def android_release(build: int, sha: str) -> dict[str, object]:
        return {
            "schema_version": 1,
            "platform": "android",
            "channel": "production",
            "latest_version": "0.2.1" if build == 24 else "0.2.0",
            "latest_build": build,
            "minimum_supported_build": 23,
            "release_notes": "Android production",
            "published_at": "2026-08-29T01:00:00Z",
            "destination": {
                "type": "android_apk",
                "url": f"https://download.saidian.cn/android/Saydian-{build}.apk",
            },
            "sha256": sha,
        }


class PushConfigTest(unittest.TestCase):
    def test_requires_explicit_vendor_decision(self) -> None:
        with self.assertRaises(push.PushConfigError):
            push.parse_vendors("")
        self.assertEqual([], push.parse_vendors("none"))

    def test_validates_environment_without_mutating_pubspec(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pubspec = root / "pubspec.yaml"
            pubspec.write_text("name: app\nversion: 1.0.0+1\n", encoding="utf-8")
            huawei = {
                "client": [
                    {
                        "client_info": {
                            "android_client_info": {"package_name": "cc.saidian.app"}
                        }
                    }
                ]
            }
            environment = {
                "JPUSH_APP_KEY": "0123456789abcdef01234567",
                "JPUSH_CHANNEL": "production",
                "HUAWEI_AGCONNECT_SERVICES_JSON_BASE64": base64.b64encode(
                    json.dumps(huawei).encode("utf-8")
                ).decode("ascii"),
            }
            with mock.patch.dict(os.environ, environment, clear=True):
                push.prepare(
                    pubspec,
                    ["huawei"],
                    root / "android/app/agconnect-services.json",
                    "cc.saidian.app",
                )
            value = pubspec.read_text(encoding="utf-8")
            self.assertEqual("name: app\nversion: 1.0.0+1\n", value)
            self.assertNotIn("HUAWEI_AGCONNECT_SERVICES_JSON_BASE64", value)


class XcodeReleaseBuildGateTest(unittest.TestCase):
    def no_push_environment(self) -> dict[str, str]:
        return {
            "CONFIGURATION": "Release",
            "SAIDIAN_PRODUCTION_RELEASE": "true",
            "SAIDIAN_IOS_PUSH_ENABLED": "false",
            "PRODUCT_BUNDLE_IDENTIFIER": "cn.saydian.ring",
            "APS_ENVIRONMENT": "production",
            "SAIDIAN_DEVELOPMENT_TEAM": "TESTTEAM",
            "SAIDIAN_CODE_SIGN_IDENTITY": "Apple Distribution",
            "SAIDIAN_PROVISIONING_PROFILE_SPECIFIER": "Test App Store",
            "SAYDIAN_API_BASE_URL": "https://api.example.invalid",
            "SAYDIAN_UPDATE_MANIFEST_URL": "https://downloads.example.invalid/app-update.json",
            "SAYDIAN_UPDATE_ALLOWED_HOSTS": "downloads.example.invalid,apps.apple.com",
            "SAIDIAN_WECHAT_APP_ID": "wx1234567890abcdef",
            "SAIDIAN_WECHAT_UNIVERSAL_LINK": "https://pay.example.invalid/wechat/",
            "SAIDIAN_WECHAT_UNIVERSAL_LINK_HOST": "pay.example.invalid",
            "SAIDIAN_ALIPAY_URL_SCHEME": "cn.saydian.ring.alipay",
            "DART_DEFINES": base64.b64encode(b"JPUSH_APP_KEY=").decode(),
        }

    def run_gate(self, environment: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/sh", str(XCODE_RELEASE_GATE)],
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_debug_build_does_not_require_release_configuration(self) -> None:
        result = self.run_gate({"CONFIGURATION": "Debug"})
        self.assertEqual(0, result.returncode, result.stderr)

    def test_unconfigured_release_is_blocked(self) -> None:
        result = self.run_gate({"CONFIGURATION": "Release"})
        self.assertNotEqual(0, result.returncode)
        self.assertIn("exactly one explicit", result.stderr)

    def test_explicit_qa_release_is_allowed(self) -> None:
        result = self.run_gate(
            {
                "CONFIGURATION": "Release",
                "SAIDIAN_ALLOW_QA_RELEASE": "true",
            }
        )
        self.assertEqual(0, result.returncode, result.stderr)

    def test_production_release_requires_and_accepts_complete_configuration(self) -> None:
        incomplete = self.run_gate(
            {
                "CONFIGURATION": "Release",
                "SAIDIAN_PRODUCTION_RELEASE": "true",
            }
        )
        self.assertNotEqual(0, incomplete.returncode)

        complete = self.run_gate(
            {
                "CONFIGURATION": "Release",
                "SAIDIAN_PRODUCTION_RELEASE": "true",
                "JPUSH_APP_KEY": "test-app-key",
                "PRODUCT_BUNDLE_IDENTIFIER": "cn.saydian.ring",
                "APS_ENVIRONMENT": "production",
                "SAIDIAN_DEVELOPMENT_TEAM": "TESTTEAM",
                "SAIDIAN_CODE_SIGN_IDENTITY": "Apple Distribution",
                "SAIDIAN_PROVISIONING_PROFILE_SPECIFIER": "Test Ad Hoc",
                "SAYDIAN_API_BASE_URL": "https://api.example.invalid",
                "SAYDIAN_UPDATE_MANIFEST_URL":
                    "https://downloads.example.invalid/app-update.json",
                "SAYDIAN_UPDATE_ALLOWED_HOSTS":
                    "downloads.example.invalid,apps.apple.com",
                "SAIDIAN_WECHAT_APP_ID": "wx1234567890abcdef",
                "SAIDIAN_WECHAT_UNIVERSAL_LINK":
                    "https://pay.example.invalid/wechat/",
                "SAIDIAN_WECHAT_UNIVERSAL_LINK_HOST": "pay.example.invalid",
                "SAIDIAN_ALIPAY_URL_SCHEME": "cn.saydian.ring.alipay",
            }
        )
        self.assertEqual(0, complete.returncode, complete.stderr)

    def test_production_release_rejects_other_product_identifiers(self) -> None:
        for bundle_id in ("", "cc.saidian.app", "cn.saydian.app.global"):
            with self.subTest(bundle_id=bundle_id):
                result = self.run_gate(
                    {
                        "CONFIGURATION": "Release",
                        "SAIDIAN_PRODUCTION_RELEASE": "true",
                        "PRODUCT_BUNDLE_IDENTIFIER": bundle_id,
                    }
                )
                self.assertNotEqual(0, result.returncode)
                self.assertIn(
                    "requires PRODUCT_BUNDLE_IDENTIFIER=cn.saydian.ring",
                    result.stderr,
                )

    def test_correct_product_still_requires_production_push_configuration(self) -> None:
        result = self.run_gate(
            {
                "CONFIGURATION": "Release",
                "SAIDIAN_PRODUCTION_RELEASE": "true",
                "PRODUCT_BUNDLE_IDENTIFIER": "cn.saydian.ring",
                "APS_ENVIRONMENT": "production",
            }
        )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("requires JPUSH_APP_KEY", result.stderr)

    def test_explicit_no_push_production_release_is_allowed(self) -> None:
        result = self.run_gate(self.no_push_environment())
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("explicitly disables JPush", result.stdout)

    def test_no_push_release_rejects_runtime_keys_and_invalid_defines(self) -> None:
        for defines in (
            "",
            "not-base64!",
            base64.b64encode(b"JPUSH_APP_KEY=unexpected-key").decode(),
            ",".join(base64.b64encode(v).decode() for v in (
                b"JPUSH_APP_KEY=", b"JPUSH_APP_KEY=unexpected-key",
            )),
        ):
            with self.subTest(defines=defines):
                environment = self.no_push_environment()
                environment["DART_DEFINES"] = defines
                result = self.run_gate(environment)
                self.assertNotEqual(0, result.returncode)
                self.assertIn("Disabled iOS push requires", result.stderr)
        environment = self.no_push_environment()
        environment["JPUSH_APP_KEY"] = "unexpected-native-key"
        result = self.run_gate(environment)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("empty JPUSH_APP_KEY", result.stderr)

    def test_no_push_release_still_requires_signing_and_provider_configuration(self) -> None:
        for key, value in (
            ("CODE_SIGNING_ALLOWED", "NO"),
            ("SAIDIAN_CODE_SIGN_IDENTITY", ""),
            ("SAIDIAN_PROVISIONING_PROFILE_SPECIFIER", ""),
            ("SAIDIAN_WECHAT_APP_ID", ""),
            ("SAYDIAN_API_BASE_URL", "http://api.example.invalid"),
            ("SAIDIAN_IOS_PUSH_ENABLED", "yes"),
        ):
            with self.subTest(key=key):
                environment = self.no_push_environment()
                environment[key] = value
                self.assertNotEqual(0, self.run_gate(environment).returncode)

    def test_production_release_rejects_inconsistent_payment_configuration(self) -> None:
        environment = {
            "CONFIGURATION": "Release",
            "SAIDIAN_PRODUCTION_RELEASE": "true",
            "JPUSH_APP_KEY": "test-app-key",
            "PRODUCT_BUNDLE_IDENTIFIER": "cn.saydian.ring",
            "APS_ENVIRONMENT": "production",
            "SAIDIAN_DEVELOPMENT_TEAM": "TESTTEAM",
            "SAIDIAN_CODE_SIGN_IDENTITY": "Apple Distribution",
            "SAIDIAN_PROVISIONING_PROFILE_SPECIFIER": "Test Ad Hoc",
            "SAYDIAN_API_BASE_URL": "https://api.example.invalid",
            "SAYDIAN_UPDATE_MANIFEST_URL":
                "https://downloads.example.invalid/app-update.json",
            "SAYDIAN_UPDATE_ALLOWED_HOSTS":
                "downloads.example.invalid,apps.apple.com",
            "SAIDIAN_WECHAT_APP_ID": "wx1234567890abcdef",
            "SAIDIAN_WECHAT_UNIVERSAL_LINK":
                "https://wrong.example.invalid/wechat/",
            "SAIDIAN_WECHAT_UNIVERSAL_LINK_HOST": "pay.example.invalid",
            "SAIDIAN_ALIPAY_URL_SCHEME": "cn.saydian.ring.alipay",
        }
        result = self.run_gate(environment)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("must match its host", result.stderr)

    def test_release_rejects_ambiguous_or_misspelled_modes(self) -> None:
        ambiguous = self.run_gate(
            {
                "CONFIGURATION": "Release",
                "SAIDIAN_PRODUCTION_RELEASE": "true",
                "SAIDIAN_ALLOW_QA_RELEASE": "true",
            }
        )
        self.assertNotEqual(0, ambiguous.returncode)

        misspelled = self.run_gate(
            {
                "CONFIGURATION": "Release",
                "SAIDIAN_ALLOW_QA_RELEASE": "yes",
            }
        )
        self.assertNotEqual(0, misspelled.returncode)


if __name__ == "__main__":
    unittest.main()
