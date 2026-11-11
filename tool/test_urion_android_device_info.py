"""Execute the real Android optional-info methods and GATT retirement barrier."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NATIVE = "android/app/src/main/kotlin/cc/saidian/saydian_app/UrionGattTransport.kt"


def method(source, name):
    start = source.index(f"private fun {name}(")
    opening = source.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


class DeviceInfoTest(unittest.TestCase):
    def test_real_optional_read_timeout_and_native_close_barrier(self):
        cache = Path(os.environ.get("GRADLE_USER_HOME", Path.home() / ".gradle")) / "caches/modules-2/files-2.1"
        coordinates = [("org.jetbrains.kotlin", name, version) for name, version in (
            ("kotlin-compiler-embeddable", "2.3.20"), ("kotlin-stdlib", "2.3.20"),
            ("kotlin-script-runtime", "2.3.20"), ("kotlin-reflect", "1.6.10"),
            ("kotlin-daemon-embeddable", "2.3.20"),
        )] + [("org.jetbrains.kotlinx", "kotlinx-coroutines-core-jvm", "1.8.0")]
        jars = []
        for group, artifact, version in coordinates:
            values = list((cache / group / artifact / version).glob("*/*.jar"))
            self.assertEqual(len(values), 1)
            jars += values
        jars.append(sorted((cache / "org.jetbrains/annotations").glob("*/*/*.jar"))[-1])
        classpath = os.pathsep.join(map(str, jars))
        java = str(Path(os.environ["JAVA_HOME"]) / "bin/java")
        source = (ROOT / NATIVE).read_text(encoding="utf-8")
        names = ("beginDeviceInfo", "cancelDeviceInfoRead", "finishDeviceInfoRead", "readDeviceVersion", "completeConnection", "recoverStalledDiscovery")
        methods = "\n".join(method(source, name) for name in names)
        fixture = (ROOT / "tool/fixtures/UrionDeviceInfoHarness.kt").read_text(encoding="utf-8")
        drain = ROOT / "android/app/src/main/kotlin/cc/saidian/saydian_app/UrionGattDrain.kt"
        descriptor = source[source.index("override fun onDescriptorWrite("):source.index('@Suppress("DEPRECATION")', source.index("override fun onDescriptorWrite("))]
        self.assertIn("pendingConnect == null", descriptor)
        self.assertIn("status != BluetoothGatt.GATT_SUCCESS", descriptor)
        self.assertIn("beginDeviceInfo(connection)", descriptor)
        self.assertIn("cancelDeviceInfoRead()", source[source.index("fun closeConnection() {"):])
        with tempfile.TemporaryDirectory(prefix="urion-device-info-") as directory:
            target = Path(directory) / "Harness.kt"
            def run(body, args=()):
                target.write_text(fixture.replace("// PRODUCTION_METHODS", body), encoding="utf-8")
                compiled = subprocess.run([java, "-cp", classpath, "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect", "-classpath", classpath, "-d", directory, str(target), str(drain)], capture_output=True, text=True, timeout=60)
                self.assertEqual(compiled.returncode, 0, compiled.stderr)
                return subprocess.run([java, "-cp", directory + os.pathsep + classpath, "cc.saidian.saydian_app.DeviceInfoHarness", *args], capture_output=True, text=True, timeout=20)
            good = run(methods)
            self.assertEqual(good.returncode, 0, good.stderr)
            print(good.stdout.strip())
            mutant = methods.replace("handler.postDelayed(deadline, 2000)", "Unit")
            self.assertNotEqual(mutant, methods)
            bad = run(mutant, ("stall",))
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn("optional info timeout did not release stalled client", bad.stderr)
            baseline = (ROOT / "tool/fixtures/UrionDeviceInfoBeforeTimeout.kt.txt").read_text(encoding="utf-8")
            red = run(baseline, ("stall",))
            self.assertNotEqual(red.returncode, 0)
            self.assertIn("optional info timeout did not release stalled client", red.stderr)


if __name__ == "__main__":
    unittest.main()
