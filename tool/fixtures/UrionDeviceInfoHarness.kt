package cc.saidian.saydian_app

import java.util.UUID

class BluetoothGattCharacteristic(val uuid: UUID, val properties: Int = PROPERTY_READ) {
    companion object { const val PROPERTY_READ = 2 }
}
class Service(val values: MutableMap<UUID, BluetoothGattCharacteristic>) {
    fun getCharacteristic(id: UUID) = values[id]
}
class Device {
    var opens = 0
    var previous: BluetoothGatt? = null
    fun connectGatt(context: Any, auto: Boolean, callback: Any, transport: Int): BluetoothGatt {
        check(previous?.closed == true) { "replacement started before old client closed" }
        opens++
        return BluetoothGatt(this)
    }
}
object BluetoothDevice { const val TRANSPORT_LE = 2 }
class BluetoothGatt(val device: Device = Device()) {
    companion object { const val GATT_SUCCESS = 0 }
    val chars = mutableMapOf<UUID, BluetoothGattCharacteristic>()
    val reads = mutableListOf<UUID>()
    var acceptsRead = true
    var disconnects = 0
    var closed = false
    var refusesClose = false
    fun getService(id: UUID) = Service(chars)
    fun readCharacteristic(c: BluetoothGattCharacteristic): Boolean {
        reads.add(c.uuid)
        return acceptsRead
    }
}
class TimerQueue {
    data class Job(val runnable: Runnable, val time: Long)
    private val jobs = mutableListOf<Job>()
    private var now = 0L
    fun post(task: () -> Unit) { postDelayed(Runnable(task), 0) }
    fun postDelayed(task: Runnable, delay: Long) { jobs.add(Job(task, now + delay)) }
    fun removeCallbacks(task: Runnable) { jobs.removeAll { it.runnable === task } }
    fun advance(delta: Long) {
        now += delta
        while (true) {
            val next = jobs.filter { it.time <= now }.minByOrNull { it.time } ?: return
            jobs.remove(next)
            next.runnable.run()
        }
    }
}
object Log { fun d(tag: String, message: String) {} }
class Response {
    var successes = 0
    fun success(value: Map<String, Int>) { successes++ }
}

class DeviceInfoHarness {
    private val handler = TimerQueue()
    private val context = Any()
    private val callback = Any()
    private var gatt: BluetoothGatt? = BluetoothGatt()
    private var writer: Any? = Any()
    private var pendingConnect: Response? = Response()
    private var connectDeadline: Runnable? = null
    private var deviceInfoDeadline: Runnable? = null
    private var pendingDeviceInfo: UUID? = null
    private var skipDeviceInfoForAttempt = false
    private var discoveryRecoveryUsed = false
    private var generation = 1
    private var softwareVersion: String? = null
    private var hardwareVersion: String? = null
    private var failures = 0
    private var emitted = 0
    private val eventListener: ((Map<String, Any?>) -> Unit)? = { emitted++ }
    private val firmwareId = UUID.fromString("00002a26-0000-1000-8000-00805f9b34fb")
    private val hardwareId = UUID.fromString("00002a27-0000-1000-8000-00805f9b34fb")
    private val deviceInfoId = UUID.fromString("0000180a-0000-1000-8000-00805f9b34fb")
    private val connectionDrain = UrionGattDrain<BluetoothGatt>(
        disconnect = { it.disconnects++ },
        close = { check(!it.refusesClose); it.closed = true },
        scheduleTimeout = { complete ->
            val timer = Runnable { complete() }
            handler.postDelayed(timer, 2000)
            val cancel: () -> Unit = { handler.removeCallbacks(timer) }
            cancel
        },
    )
    private fun details(): Map<String, Any?>? = if (writer == null) null else mapOf("model" to hardwareVersion)
    private fun failConnection() { failures++; pendingConnect = null }

    // PRODUCTION_METHODS

    private fun populate(connection: BluetoothGatt) {
        connection.chars[firmwareId] = BluetoothGattCharacteristic(firmwareId)
        connection.chars[hardwareId] = BluetoothGattCharacteristic(hardwareId)
    }
    private fun start(): Pair<BluetoothGatt, Response> {
        val connection = gatt!!
        populate(connection)
        beginDeviceInfo(connection)
        return connection to pendingConnect!!
    }
    private fun firmware(connection: BluetoothGatt) {
        val bytes = "fw".toByteArray()
        finishDeviceInfoRead(connection, firmwareId, bytes, 0)
        bytes.fill(0)
        handler.advance(0)
        check(connection.reads.last() == hardwareId)
    }
    private fun stalledHardware() {
        val (old, result) = start()
        firmware(old)
        old.device.previous = old
        val staleTimeout = deviceInfoDeadline
        handler.advance(1999)
        check(result.successes == 0 && old.disconnects == 0)
        handler.advance(1)
        check(old.disconnects == 1 && gatt == null && writer == null) {
            "optional info timeout did not release stalled client"
        }
        check(old.device.opens == 0 && result.successes == 0)
        finishDeviceInfoRead(old, hardwareId, "late".toByteArray(), 0)
        handler.advance(0)
        check(hardwareVersion == null && result.successes == 0)
        connectionDrain.didDisconnect(old)
        val fresh = gatt!!
        check(fresh !== old && old.closed && old.device.opens == 1)
        check(result.successes == 0) { "replacement was ready before notifications" }
        writer = Any() // Actual CCCD success enters beginDeviceInfo in the production callback.
        beginDeviceInfo(fresh)
        check(result.successes == 1 && fresh.reads.isEmpty())
        check(softwareVersion == "fw" && hardwareVersion == null)
        staleTimeout?.run()
        handler.advance(10000)
        check(result.successes == 1 && old.device.opens == 1 && failures == 0)
    }
    private fun normal() {
        val (connection, result) = start()
        firmware(connection)
        finishDeviceInfoRead(connection, hardwareId, "hw".toByteArray(), 0)
        handler.advance(0)
        check(result.successes == 1 && softwareVersion == "fw" && hardwareVersion == "hw")
        val before = connection.reads.size
        finishDeviceInfoRead(connection, firmwareId, "stale".toByteArray(), 0)
        beginDeviceInfo(connection)
        handler.advance(10000)
        check(result.successes == 1 && connection.reads.size == before && softwareVersion == "fw")
    }
    private fun cancelled() {
        val (old, result) = start()
        old.device.previous = old
        handler.advance(2000)
        pendingConnect = null
        generation++
        cancelDeviceInfoRead()
        connectionDrain.didDisconnect(old)
        handler.advance(10000)
        check(old.device.opens == 0 && result.successes == 0)
    }
    private fun closeFailure() {
        val (old, result) = start()
        old.device.previous = old
        old.refusesClose = true
        handler.advance(4000)
        handler.advance(2000)
        check(failures == 1 && old.device.opens == 0 && result.successes == 0)
    }
    private fun noReadProperties() {
        val connection = gatt!!
        populate(connection)
        connection.chars[firmwareId] = BluetoothGattCharacteristic(firmwareId, 0)
        connection.chars[hardwareId] = BluetoothGattCharacteristic(hardwareId, 0)
        val result = pendingConnect!!
        beginDeviceInfo(connection)
        handler.advance(10000)
        check(connection.reads.isEmpty() && result.successes == 1)
    }
    companion object {
        @JvmStatic fun main(args: Array<String>) {
            if (args.singleOrNull() == "stall") { DeviceInfoHarness().stalledHardware(); return }
            DeviceInfoHarness().normal()
            DeviceInfoHarness().stalledHardware()
            DeviceInfoHarness().cancelled()
            DeviceInfoHarness().closeFailure()
            DeviceInfoHarness().noReadProperties()
            println("Production device-info timeout, drain, cancellation and readback checks passed")
        }
    }
}
