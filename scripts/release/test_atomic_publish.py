#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent


class AtomicPublishTest(unittest.TestCase):
    def test_apk_is_public_before_manifest_and_is_immutable(self) -> None:
        with tempfile.TemporaryDirectory(prefix="saydian-release-") as directory:
            root = Path(directory)
            remote = root / "remote"
            local = root / "local"
            fake_bin = root / "bin"
            remote.mkdir()
            local.mkdir()
            fake_bin.mkdir()
            self.install_fake_transport(fake_bin)

            apk = local / "Saydian-1.2.3+45-release.apk"
            checksum = local / "SHA256SUMS-1.2.3+45.txt"
            manifest = local / "app-update.json"
            apk.write_bytes(b"verified production apk fixture")
            digest = hashlib.sha256(apk.read_bytes()).hexdigest()
            checksum.write_text(f"{digest}  {apk.name}\n", encoding="utf-8")
            manifest.write_text(
                json.dumps({"sha256": digest}, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            key = local / "key"
            known_hosts = local / "known_hosts"
            key.write_text("fixture-key\n", encoding="utf-8")
            known_hosts.write_text("fixture-host\n", encoding="utf-8")
            environment = {
                **os.environ,
                "PATH": f"{fake_bin}:/usr/bin:/bin",
                "FAKE_REMOTE_ROOT": str(remote),
                "RELEASE_SSH_HOST": "release.saidian.cn",
                "RELEASE_SSH_USER": "publisher",
                "RELEASE_SSH_PORT": "22",
                "RELEASE_SSH_KEY_PATH": str(key),
                "RELEASE_SSH_KNOWN_HOSTS_PATH": str(known_hosts),
                "RELEASE_REMOTE_ROOT": str(remote),
                "APK_FILE": str(apk),
                "CHECKSUM_FILE": str(checksum),
                "MANIFEST_FILE": str(manifest),
                "APK_PUBLIC_URL": f"https://downloads.saidian.cn/android/{apk.name}",
                "MANIFEST_PUBLIC_URL": "https://downloads.saidian.cn/app-update.json",
                "EXPECTED_SHA256": digest,
                "EXPECTED_PREVIOUS_MANIFEST_SHA256": "absent",
                "RELEASE_TOKEN": "fixture-1",
            }
            script = HERE / "atomic_publish.sh"
            subprocess.run(["bash", str(script)], env=environment, check=True)
            self.assertEqual(apk.read_bytes(), (remote / "android" / apk.name).read_bytes())
            self.assertEqual(manifest.read_bytes(), (remote / "app-update.json").read_bytes())

            # A retry with the exact same immutable APK is allowed.
            environment["EXPECTED_PREVIOUS_MANIFEST_SHA256"] = hashlib.sha256(
                manifest.read_bytes()
            ).hexdigest()
            environment["RELEASE_TOKEN"] = "fixture-2"
            subprocess.run(["bash", str(script)], env=environment, check=True)

            # Redirects may change paths but must never leave the requested
            # HTTPS origin, even when the bytes and digest would otherwise pass.
            environment["FAKE_CROSS_ORIGIN"] = "1"
            environment["RELEASE_TOKEN"] = "fixture-cross-origin"
            result = subprocess.run(["bash", str(script)], env=environment)
            self.assertEqual(4, result.returncode)
            self.assertEqual(manifest.read_bytes(), (remote / "app-update.json").read_bytes())
            self.assertFalse((remote / ".production-release.lock").exists())
            environment.pop("FAKE_CROSS_ORIGIN")

            # A stale publisher's cleanup must stop on a token mismatch and
            # must never delete a newer publisher's lock.
            environment["FAKE_CROSS_ORIGIN"] = "1"
            environment["FAKE_STEAL_LOCK"] = "1"
            environment["RELEASE_TOKEN"] = "fixture-stolen-lock"
            result = subprocess.run(["bash", str(script)], env=environment)
            self.assertEqual(6, result.returncode)
            stolen_lock = remote / ".production-release.lock"
            self.assertEqual("competitor", (stolen_lock / "token").read_text())
            (stolen_lock / "token").unlink()
            (stolen_lock / "created_at").unlink()
            stolen_lock.rmdir()
            (remote / ".fake-lock-stolen").unlink()
            environment.pop("FAKE_CROSS_ORIGIN")
            environment.pop("FAKE_STEAL_LOCK")

            # When two publishers race to take an expired legacy directory
            # lease, the loser must not overwrite the winner's token.
            legacy_lock = remote / ".production-release.lock"
            legacy_lock.mkdir()
            (legacy_lock / "token").write_text("expired", encoding="utf-8")
            (legacy_lock / "created_at").write_text("1", encoding="utf-8")
            environment["FAKE_RACE_LOCK"] = "1"
            environment["RELEASE_TOKEN"] = "fixture-lock-race"
            result = subprocess.run(["bash", str(script)], env=environment)
            self.assertEqual(3, result.returncode)
            self.assertTrue(legacy_lock.is_dir())
            self.assertEqual("competitor", (legacy_lock / "token").read_text())
            (legacy_lock / "token").unlink()
            (legacy_lock / "created_at").unlink()
            legacy_lock.rmdir()
            environment.pop("FAKE_RACE_LOCK")

            # A public-manifest verification failure must restore the prior
            # manifest after the atomic rename.
            original_manifest = (remote / "app-update.json").read_bytes()
            manifest.write_text(
                json.dumps({"sha256": digest, "revision": 2}, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            environment["FAKE_FAIL_MANIFEST"] = "1"
            environment["RELEASE_TOKEN"] = "fixture-rollback"
            result = subprocess.run(["bash", str(script)], env=environment)
            self.assertEqual(5, result.returncode)
            self.assertEqual(original_manifest, (remote / "app-update.json").read_bytes())
            self.assertEqual([], list((remote / ".staging").iterdir()))
            environment.pop("FAKE_FAIL_MANIFEST")

            # The same public file name may never be replaced by different bytes.
            apk.write_bytes(b"different apk bytes")
            changed_digest = hashlib.sha256(apk.read_bytes()).hexdigest()
            checksum.write_text(f"{changed_digest}  {apk.name}\n", encoding="utf-8")
            manifest.write_text(
                json.dumps({"sha256": changed_digest}, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            environment["EXPECTED_SHA256"] = changed_digest
            environment["RELEASE_TOKEN"] = "fixture-3"
            result = subprocess.run(["bash", str(script)], env=environment)
            self.assertEqual(3, result.returncode)
            self.assertEqual(digest, json.loads((remote / "app-update.json").read_text())["sha256"])

    @staticmethod
    def install_fake_transport(directory: Path) -> None:
        scripts = {
            "sha256sum": r'''
                #!/usr/bin/env python3
                import hashlib, pathlib, sys
                for filename in sys.argv[1:]:
                    value = pathlib.Path(filename).read_bytes()
                    print(f"{hashlib.sha256(value).hexdigest()}  {filename}")
            ''',
            "ssh": r'''
                #!/usr/bin/env python3
                import subprocess, sys
                args = sys.argv[1:]
                remaining = []
                index = 0
                while index < len(args):
                    if args[index] in {"-p", "-i", "-o"}:
                        index += 2
                    else:
                        remaining.append(args[index])
                        index += 1
                if len(remaining) < 2:
                    raise SystemExit(2)
                result = subprocess.run(
                    remaining[1], shell=True, executable="/bin/bash", check=False
                )
                raise SystemExit(result.returncode)
            ''',
            "scp": r'''
                #!/usr/bin/env python3
                import pathlib, shutil, sys
                args = sys.argv[1:]
                remaining = []
                index = 0
                while index < len(args):
                    if args[index] in {"-P", "-i", "-o"}:
                        index += 2
                    else:
                        remaining.append(args[index])
                        index += 1
                source, target = remaining
                destination = pathlib.Path(target.split(":", 1)[1])
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
            ''',
            "curl": r'''
                #!/usr/bin/env python3
                import json, os, pathlib, shutil, sys, time, urllib.parse
                args = sys.argv[1:]
                output_flag = "--output" if "--output" in args else "-o"
                output = pathlib.Path(args[args.index(output_flag) + 1])
                url = next(value for value in args if value.startswith("https://"))
                remote_root = pathlib.Path(os.environ["FAKE_REMOTE_ROOT"])
                stolen_marker = remote_root / ".fake-lock-stolen"
                lock = remote_root / ".production-release.lock"
                if (
                    os.environ.get("FAKE_STEAL_LOCK") == "1"
                    and lock.is_dir()
                    and not stolen_marker.exists()
                ):
                    (lock / "token").write_text("competitor", encoding="utf-8")
                    (lock / "created_at").write_text(
                        str(int(time.time())), encoding="utf-8"
                    )
                    stolen_marker.write_text("1", encoding="utf-8")
                effective_url = url
                if os.environ.get("FAKE_CROSS_ORIGIN") == "1":
                    parsed = urllib.parse.urlparse(url)
                    effective_url = urllib.parse.urlunparse(
                        parsed._replace(netloc="redirect.saidian.cn")
                    )
                path = urllib.parse.unquote(urllib.parse.urlparse(url).path).lstrip("/")
                source = remote_root / path
                status = "200"
                if not source.is_file():
                    status = "404"
                    if "--write-out" in args:
                        output_format = args[args.index("--write-out") + 1]
                        print(
                            output_format.replace("%{http_code}", status).replace(
                                "%{url_effective}", effective_url
                            ),
                            end="",
                        )
                    raise SystemExit(22)
                if path == "app-update.json" and os.environ.get("FAKE_FAIL_MANIFEST") == "1":
                    try:
                        if json.loads(source.read_text()).get("revision") == 2:
                            status = "503"
                            if "--write-out" in args:
                                output_format = args[args.index("--write-out") + 1]
                                print(
                                    output_format.replace("%{http_code}", status).replace(
                                        "%{url_effective}", effective_url
                                    ),
                                    end="",
                                )
                            raise SystemExit(22)
                    except json.JSONDecodeError:
                        raise SystemExit(22)
                shutil.copyfile(source, output)
                if "--write-out" in args:
                    output_format = args[args.index("--write-out") + 1]
                    print(
                        output_format.replace("%{http_code}", status).replace(
                            "%{url_effective}", effective_url
                        ),
                        end="",
                    )
            ''',
            "mkdir": r'''
                #!/usr/bin/env python3
                import os, pathlib, sys, time
                target = pathlib.Path(sys.argv[-1])
                if (
                    os.environ.get("FAKE_RACE_LOCK") == "1"
                    and target.name == ".production-release.lock"
                    and not target.exists()
                    and "-p" not in sys.argv
                ):
                    target.mkdir()
                    (target / "token").write_text("competitor", encoding="utf-8")
                    (target / "created_at").write_text(
                        str(int(time.time())), encoding="utf-8"
                    )
                    raise SystemExit(1)
                os.execv("/bin/mkdir", ["mkdir", *sys.argv[1:]])
            ''',
            "sleep": r'''
                #!/usr/bin/env python3
            ''',
        }
        for name, source in scripts.items():
            path = directory / name
            path.write_text(textwrap.dedent(source).lstrip(), encoding="utf-8")
            path.chmod(0o755)


if __name__ == "__main__":
    unittest.main()
