"""Execute the production Kotlin notification method with a queued JVM fixture.

Run after Gradle resolves the Kotlin compiler; no phone or Bluetooth writes.
"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def production_delivery(source):
    start = source.index("private fun deliver(")
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


HARNESS = r'''
import java.util.UUID

class BluetoothGatt
class QueuedHandler {
    val pending = mutableListOf<() -> Unit>()
    fun post(task: () -> Unit) { pending.add(task) }
    fun drain() { while (pending.isNotEmpty()) pending.removeAt(0).invoke() }
}
class NotificationHarness {
    private val handler = QueuedHandler()
    private var gatt = BluetoothGatt()
    private val notifyId = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    private var nativeId: String? = "fixture-watch"
    private var generation = 1
    private val events = mutableListOf<Map<String, Any?>>()
    private val eventListener: ((Map<String, Any?>) -> Unit)? = { events.add(it) }

    // PRODUCTION_DELIVERY

    fun verify() {
        val buffer = byteArrayOf(0x73, 2, 0, 0)
        deliver(gatt, notifyId, buffer)
        buffer[0] = 0x33
        buffer[1] = 0
        deliver(gatt, notifyId, buffer)
        buffer.fill(0)
        handler.drain()
        check((events[0]["bytes"] as ByteArray).contentEquals(byteArrayOf(0x73, 2, 0, 0))) {
            "First packet changed while queued"
        }
        check((events[1]["bytes"] as ByteArray).contentEquals(byteArrayOf(0x33, 0, 0, 0))) {
            "Second packet changed while queued"
        }
        check(events.all { it["deviceId"] == nativeId && it["generation"] == 1 })
        val old = gatt
        deliver(old, notifyId, byteArrayOf(0x14))
        gatt = BluetoothGatt()
        generation++
        nativeId = "next-watch"
        handler.drain()
        check(events.size == 2) { "Retired connection reached the next target" }
        deliver(gatt, UUID.randomUUID(), byteArrayOf(0x14))
        handler.drain()
        check(events.size == 2) { "Wrong characteristic was delivered" }
    }
}
fun main() { NotificationHarness().verify(); println("Notification snapshot and target checks passed") }
'''


class AndroidNotificationTest(unittest.TestCase):
    def test_actual_delivery_preserves_each_packet_and_rejects_stale_connection(self):
        cache = Path(os.environ.get("GRADLE_USER_HOME", Path.home() / ".gradle"))
        cache = cache / "caches/modules-2/files-2.1"
        coordinates = [
            ("org.jetbrains.kotlin", "kotlin-compiler-embeddable", "2.3.20"),
            ("org.jetbrains.kotlin", "kotlin-stdlib", "2.3.20"),
            ("org.jetbrains.kotlin", "kotlin-script-runtime", "2.3.20"),
            ("org.jetbrains.kotlin", "kotlin-reflect", "1.6.10"),
            ("org.jetbrains.kotlin", "kotlin-daemon-embeddable", "2.3.20"),
            ("org.jetbrains.kotlinx", "kotlinx-coroutines-core-jvm", "1.8.0"),
        ]
        jars = []
        for group, artifact, version in coordinates:
            matches = list((cache / group / artifact / version).glob("*/*.jar"))
            self.assertEqual(len(matches), 1, f"Resolve Gradle dependency first: {artifact}:{version}")
            jars.extend(matches)
        annotations = sorted((cache / "org.jetbrains/annotations").glob("*/*/*.jar"))
        self.assertTrue(annotations, "Resolve Gradle annotations first")
        jars.append(annotations[-1])
        classpath = os.pathsep.join(map(str, jars))
        java = str(Path(os.environ["JAVA_HOME"]) / "bin/java") if os.environ.get("JAVA_HOME") else "java"
        source = (ROOT / "android/app/src/main/kotlin/cc/saidian/saydian_app/UrionGattTransport.kt").read_text()
        method = production_delivery(source)
        with tempfile.TemporaryDirectory(prefix="urion-notification-test-") as folder:
            target = Path(folder) / "NotificationHarness.kt"
            def run(body):
                target.write_text(HARNESS.replace("// PRODUCTION_DELIVERY", body))
                result = subprocess.run([
                    java, "-cp", classpath, "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
                    "-no-stdlib", "-no-reflect", "-classpath", classpath,
                    "-d", folder, str(target),
                ], capture_output=True, text=True, timeout=60)
                self.assertEqual(result.returncode, 0, result.stderr)
                return subprocess.run([
                    java, "-cp", folder + os.pathsep + classpath, "NotificationHarnessKt",
                ], capture_output=True, text=True, timeout=15)
            good = run(method)
            self.assertEqual(good.returncode, 0, good.stderr)
            # 删除实际复制保护必须再次失败，防止仅检查源码文本却没有覆盖错误路径。
            mutant = method.replace("bytes.copyOf()", "bytes")
            self.assertNotEqual(mutant, method)
            bad = run(mutant)
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn("First packet changed while queued", bad.stderr)


if __name__ == "__main__":
    unittest.main()
