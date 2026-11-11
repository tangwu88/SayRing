package cc.saidian.saydian_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** EB1 transports only BLE bytes. Packet decoding and health decisions live in Dart. */
internal class UrionGattTransport(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private val bluetooth = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val verifiedCache = context.getSharedPreferences("sayring.u19.verified", Context.MODE_PRIVATE)
    private val found = linkedMapOf<String, Pair<BluetoothDevice, Map<String, Any?>>>()
    private var scannerCallback: ScanCallback? = null
    private var scanCompletion: MethodChannel.Result? = null
    private var scanDeadline: Runnable? = null
    private var observedAdvertisements = 0
    private var observedCompanyAdvertisements = 0
    private var gatt: BluetoothGatt? = null
    private val connectionDrain = UrionGattDrain<BluetoothGatt>(
        disconnect = { it.disconnect() },
        close = { it.close() },
        scheduleTimeout = { completion ->
            val deadline = Runnable { completion() }
            handler.postDelayed(deadline, 2000)
            val cancel: () -> Unit = { handler.removeCallbacks(deadline) }
            cancel
        },
    )
    private var writer: BluetoothGattCharacteristic? = null
    private var pendingConnect: MethodChannel.Result? = null
    private var connectDeadline: Runnable? = null
    private var pendingWrite: MethodChannel.Result? = null
    private var nativeId: String? = null
    private var generation = 0
    private var discoveryRecoveryUsed = false
    private var softwareVersion: String? = null
    private var hardwareVersion: String? = null
    var eventListener: ((Map<String, Any?>) -> Unit)? = null

    private val serviceId = UUID.fromString("6e40fff0-b5a3-f393-e0a9-e50e24dcca9e")
    private val writeId = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    private val notifyId = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    private val cccdId = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    private val deviceInfoId = UUID.fromString("0000180a-0000-1000-8000-00805f9b34fb")
    private val firmwareId = UUID.fromString("00002a26-0000-1000-8000-00805f9b34fb")
    private val hardwareId = UUID.fromString("00002a27-0000-1000-8000-00805f9b34fb")

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "stopScan") {
            stopScan()
            result.success(null)
            return
        }
        if (call.method == "disconnect") {
            closeConnection()
            connectionDrain.whenDrained { closed ->
                if (closed) result.success(null)
                else result.error("DISCONNECT_FAILED", "手表连接尚未关闭，请重新打开应用后重试", null)
            }
            return
        }
        if (!hasPermission()) {
            result.error("BLE_PERMISSION_REQUIRED", "允许相关权限后使用", null)
            return
        }
        try {
            when (call.method) {
                "configureHealthPolicy" -> result.success(null) // iOS 独立许可；Android 仍由真实能力控制。
                "rememberVerifiedDevice" -> {
                    val id = nativeId
                    val candidate = found[id]
                    if (id != null && id == call.argument<String>("deviceId") && candidate != null && writer != null) {
                        verifiedCache.edit().putString("$id.address", candidate.first.address).putString("$id.name", candidate.second["name"] as? String ?: "U19").apply()
                    }
                    result.success(null)
                }
                "prepareRememberedDevice" -> {
                    val id = call.argument<String>("deviceId").orEmpty()
                    val address = verifiedCache.getString("$id.address", null)
                    if (address == null || !BluetoothAdapter.checkBluetoothAddress(address)) result.success(null)
                    else {
                        val device = bluetooth.adapter.getRemoteDevice(address)
                        val description = mapOf<String, Any?>("id" to id, "name" to verifiedCache.getString("$id.name", "U19"), "hardwareAddress" to address)
                        found[id] = device to description
                        result.success(description)
                    }
                }
                "scanDevices" -> scan(result)
                "connect" -> connect(call.argument<String>("deviceId").orEmpty(), result)
                "getDeviceDetails" -> result.success(details())
                "writeFrame" -> write(call.argument<ByteArray>("bytes"), result)
                else -> result.notImplemented()
            }
        } catch (_: SecurityException) {
            result.error("BLE_PERMISSION_REQUIRED", "允许相关权限后使用", null)
        } catch (_: Throwable) {
            result.error("DEVICE_UNAVAILABLE", "暂时无法连接手表，请重试", null)
        }
    }

    private fun hasPermission(): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= 31)
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        return permissions.all { context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    }

    private fun scan(result: MethodChannel.Result) {
        stopScan()
        found.clear()
        observedAdvertisements = 0
        observedCompanyAdvertisements = 0
        val adapter = bluetooth.adapter
        if (adapter?.isEnabled != true) {
            result.error("BLUETOOTH_DISABLED", "请开启手机蓝牙后再试", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.error("DEVICE_UNAVAILABLE", "暂时无法查找手表", null)
            return
        }
        scanCompletion = result
        Log.d("U19GATT", "scan started")
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) = accept(result)
            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach(::accept)
            }
            override fun onScanFailed(errorCode: Int) {
                Log.d("U19GATT", "scan failed code=$errorCode")
                scanCompletion?.error("SCAN_FAILED", "暂时无法查找手表，请重试", null)
                scanCompletion = null
                stopScan()
            }
        }
        scannerCallback = callback
        scanner.startScan(callback)
        val deadline = Runnable { stopScan() }
        scanDeadline = deadline
        handler.postDelayed(deadline, 10000)
    }

    private fun accept(result: ScanResult) {
        observedAdvertisements++
        // Android separates the little-endian company ID from manufacturer data.
        val data = result.scanRecord?.getManufacturerSpecificData(0x1234) ?: return
        observedCompanyAdvertisements++
        if (data.size < 8 || data[0] != 0xfe.toByte() || data[1] != 0xe7.toByte()) return
        val mac = data.copyOfRange(2, 8).joinToString(":") { "%02X".format(it.toInt() and 0xff) }
        val payload = mapOf<String, Any?>(
            "id" to mac,
            "name" to (result.scanRecord?.deviceName ?: result.device.name ?: "U19"),
            "hardwareAddress" to mac,
            "rssi" to result.rssi,
        )
        val isNewCandidate = !found.containsKey(mac)
        found[mac] = result.device to payload
        if (isNewCandidate) Log.d("U19GATT", "verified manufacturer candidate found")
        eventListener?.invoke(mapOf("type" to "scanDevice", "payload" to payload))
    }

    private fun stopScan() {
        if (scannerCallback != null) Log.d(
            "U19GATT",
            "scan finished advertisements=$observedAdvertisements company=$observedCompanyAdvertisements verified=${found.size}",
        )
        scanDeadline?.let(handler::removeCallbacks)
        scanDeadline = null
        scannerCallback?.let { callback ->
            try { bluetooth.adapter?.bluetoothLeScanner?.stopScan(callback) } catch (_: Throwable) { }
        }
        scannerCallback = null
        scanCompletion?.success(found.values.map { it.second })
        scanCompletion = null
    }

    private fun connect(id: String, result: MethodChannel.Result) {
        if (pendingConnect != null) {
            result.error("CONNECT_IN_PROGRESS", "正在连接手表", null)
            return
        }
        val device = found[id]?.first
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "请重新搜索并选择手表", null)
            return
        }
        stopScan()
        closeConnection()
        generation++
        val requestGeneration = generation
        pendingConnect = result
        connectionDrain.whenDrained { closed ->
            if (pendingConnect !== result || generation != requestGeneration) return@whenDrained
            if (!closed) {
                failConnection()
                return@whenDrained
            }
            nativeId = id
            try {
                gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
                if (gatt == null) {
                    failConnection()
                } else {
                    val deadline = Runnable {
                        if (pendingConnect === result) {
                            Log.d("U19GATT", "connection initialization timed out")
                            failConnection()
                        }
                    }
                    connectDeadline = deadline
                    handler.postDelayed(deadline, 25000)
                }
            } catch (_: Throwable) {
                failConnection()
            }
        }
    }

    private fun details(): Map<String, Any?>? {
        val id = nativeId ?: return null
        if (writer == null) return null
        return found[id]?.second?.plus(mapOf(
            "firmwareVersion" to softwareVersion,
            "model" to hardwareVersion,
        ))
    }

    private fun write(bytes: ByteArray?, result: MethodChannel.Result) {
        val active = gatt
        val characteristic = writer
        if (active == null || characteristic == null || bytes?.size != 16 || pendingWrite != null) {
            result.error("WRITE_UNAVAILABLE", "手表暂时无响应，请重试", null)
            return
        }
        pendingWrite = result
        val ok = if (Build.VERSION.SDK_INT >= 33) {
            active.writeCharacteristic(
                characteristic, bytes, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
            ) == BluetoothGatt.GATT_SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.value = bytes
            @Suppress("DEPRECATION")
            active.writeCharacteristic(characteristic)
        }
        if (!ok) {
            pendingWrite = null
            result.error("WRITE_FAILED", "手表暂时无响应，请重试", null)
        }
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(connection: BluetoothGatt, status: Int, state: Int) {
            handler.post {
                if (connection !== gatt) {
                    if (state == BluetoothProfile.STATE_DISCONNECTED) {
                        connectionDrain.didDisconnect(connection)
                    }
                    return@post
                }
                Log.d("U19GATT", "state status=$status state=$state")
                if (status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
                    // Some phones report the link before the watch accepts
                    // service discovery. Keep the original connection timeout
                    // as the final bound, and never mark it ready without the
                    // actual discovery callback.
                    handler.postDelayed({
                        if (connection === gatt && pendingConnect != null) {
                            val started = connection.discoverServices()
                            Log.d("U19GATT", "service discovery started=$started")
                            if (!started) failConnection()
                        }
                    }, 600)
                    handler.postDelayed({
                        if (connection === gatt && pendingConnect != null && writer == null) {
                            recoverStalledDiscovery(connection)
                        }
                    }, 7000)
                } else {
                    val wasReady = writer != null
                    val disconnectedId = nativeId
                    val endedGeneration = generation
                    if (pendingConnect != null) failConnection() else closeConnection()
                    if (state == BluetoothProfile.STATE_DISCONNECTED) {
                        connectionDrain.didDisconnect(connection)
                    }
                    if (wasReady) eventListener?.invoke(mapOf(
                        "type" to "disconnected",
                        "payload" to mapOf("deviceId" to (disconnectedId ?: ""), "generation" to endedGeneration),
                    ))
                }
            }
        }

        override fun onServicesDiscovered(connection: BluetoothGatt, status: Int) {
            handler.post {
                if (connection !== gatt || pendingConnect == null || writer != null) return@post
                Log.d("U19GATT", "services status=$status")
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    failConnection(); return@post
                }
                val service = connection.getService(serviceId)
                val write = service?.getCharacteristic(writeId)
                val notify = service?.getCharacteristic(notifyId)
                val cccd = notify?.getDescriptor(cccdId)
                Log.d("U19GATT", "profile write=${write != null} notify=${notify != null} cccd=${cccd != null}")
                if (write == null || notify == null || cccd == null ||
                    !connection.setCharacteristicNotification(notify, true)) {
                    failConnection(); return@post
                }
                writer = write
                val ok = if (Build.VERSION.SDK_INT >= 33) {
                    connection.writeDescriptor(cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) ==
                        BluetoothGatt.GATT_SUCCESS
                } else {
                    @Suppress("DEPRECATION")
                    cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    @Suppress("DEPRECATION")
                    connection.writeDescriptor(cccd)
                }
                if (!ok) failConnection()
            }
        }

        override fun onDescriptorWrite(connection: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            handler.post {
                if (connection !== gatt || descriptor.uuid != cccdId) return@post
                Log.d("U19GATT", "notifications status=$status")
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    failConnection(); return@post
                }
                readDeviceVersion(connection, firmwareId)
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicRead(connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            onInfoRead(connection, characteristic.uuid, characteristic.value ?: byteArrayOf(), status)
        }

        override fun onCharacteristicRead(
            connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic,
            value: ByteArray, status: Int,
        ) = onInfoRead(connection, characteristic.uuid, value, status)

        private fun onInfoRead(connection: BluetoothGatt, uuid: UUID, bytes: ByteArray, status: Int) {
            val snapshot = bytes.copyOf()
            handler.post {
                if (connection !== gatt) return@post
                Log.d("U19GATT", "device-info status=$status")
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    val text = snapshot.toString(Charsets.UTF_8).trim('\u0000', ' ')
                    if (uuid == firmwareId) softwareVersion = text.take(64)
                    if (uuid == hardwareId) hardwareVersion = text.take(64)
                }
                if (uuid == firmwareId) readDeviceVersion(connection, hardwareId)
                else completeConnection()
            }
        }

        override fun onCharacteristicChanged(connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            @Suppress("DEPRECATION")
            deliver(connection, characteristic.uuid, characteristic.value ?: byteArrayOf())
        }

        override fun onCharacteristicChanged(connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            deliver(connection, characteristic.uuid, value)
        }

        private fun deliver(connection: BluetoothGatt, uuid: UUID, bytes: ByteArray) {
            // 通知跨线程排队前固定原始字节，避免连续血压包共用可变缓冲区。
            // 仍在投递时核对 GATT 实例，旧连接的迟到结果不能进入新设备。
            val snapshot = bytes.copyOf()
            handler.post {
                if (connection !== gatt || uuid != notifyId) return@post
                eventListener?.invoke(mapOf(
                    "type" to "bytes", "bytes" to snapshot,
                    "deviceId" to (nativeId ?: ""), "generation" to generation,
                ))
            }
        }

        override fun onCharacteristicWrite(connection: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            handler.post {
                if (connection !== gatt || characteristic.uuid != writeId) return@post
                val completion = pendingWrite ?: return@post
                pendingWrite = null
                if (status == BluetoothGatt.GATT_SUCCESS) completion.success(null)
                else completion.error("WRITE_FAILED", "手表暂时无响应，请重试", null)
            }
        }
    }

    private fun readDeviceVersion(connection: BluetoothGatt, uuid: UUID) {
        val characteristic = connection.getService(deviceInfoId)?.getCharacteristic(uuid)
        if (characteristic == null || !connection.readCharacteristic(characteristic)) {
            if (uuid == firmwareId) readDeviceVersion(connection, hardwareId)
            else completeConnection()
        }
    }

    private fun completeConnection() {
        val completion = pendingConnect ?: return
        Log.d("U19GATT", "ready")
        connectDeadline?.let(handler::removeCallbacks)
        connectDeadline = null
        pendingConnect = null
        completion.success(mapOf("generation" to generation))
        details()?.let { eventListener?.invoke(mapOf("type" to "deviceDetails", "payload" to (it + ("generation" to generation)))) }
    }

    private fun recoverStalledDiscovery(connection: BluetoothGatt) {
        if (discoveryRecoveryUsed) return
        val request = pendingConnect ?: return
        val requestGeneration = generation
        discoveryRecoveryUsed = true
        Log.d("U19GATT", "service discovery stalled; replacing GATT client")
        gatt = null
        connectionDrain.retire(connection)
        connectionDrain.whenDrained { closed ->
            if (pendingConnect !== request || generation != requestGeneration) return@whenDrained
            if (!closed) {
                failConnection()
                return@whenDrained
            }
            try {
                gatt = connection.device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
                if (gatt == null) failConnection()
            } catch (_: Throwable) {
                failConnection()
            }
        }
    }

    private fun failConnection() {
        Log.d("U19GATT", "connection failed")
        pendingConnect?.error("CONNECT_FAILED", "暂时无法连接手表，请重试", null)
        pendingConnect = null
        closeConnection()
    }

    fun closeConnection() {
        connectDeadline?.let(handler::removeCallbacks)
        connectDeadline = null
        generation++
        discoveryRecoveryUsed = false
        pendingWrite?.error("DISCONNECTED", "手表已断开连接", null)
        pendingWrite = null
        pendingConnect?.error("DISCONNECTED", "手表已断开连接", null)
        pendingConnect = null
        writer = null
        softwareVersion = null
        hardwareVersion = null
        val retiring = gatt
        gatt = null
        nativeId = null
        // Detach first so late callbacks cannot mutate the next connection.
        retiring?.let(connectionDrain::retire)
    }

    fun close() { stopScan(); closeConnection(); eventListener = null }
}
