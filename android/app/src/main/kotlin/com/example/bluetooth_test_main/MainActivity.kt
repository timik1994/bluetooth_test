package com.example.bluetooth_test_main

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.ParcelUuid
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ble_peripheral"
    private val NATIVE_CONNECTION_CHANNEL = "native_bluetooth_connection"
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var bluetoothGattServer: BluetoothGattServer? = null
    private var advertisingCallback: AdvertiseCallback? = null
    private var methodChannel: MethodChannel? = null
    private var nativeConnectionChannel: MethodChannel? = null
    
    // Для нативного подключения
    private var bluetoothGattClient: BluetoothGatt? = null
    private val connectedGattDevices = mutableMapOf<String, BluetoothGatt>()
    private val characteristicsToRead = mutableMapOf<String, MutableList<BluetoothGattCharacteristic>>() // Для периодического чтения
    private val readHandlers = mutableMapOf<String, android.os.Handler>() // Для периодического чтения
    private var scanner: android.bluetooth.le.BluetoothLeScanner? = null
    
    // UUID для BLE сервисов и характеристик
    private val HEART_RATE_SERVICE_UUID = UUID.fromString("0000180D-0000-1000-8000-00805F9B34FB")
    private val HEART_RATE_MEASUREMENT_UUID = UUID.fromString("00002A37-0000-1000-8000-00805F9B34FB")
    private val BATTERY_SERVICE_UUID = UUID.fromString("0000180F-0000-1000-8000-00805F9B34FB")
    private val BATTERY_LEVEL_UUID = UUID.fromString("00002A19-0000-1000-8000-00805F9B34FB")
    private val DEVICE_INFO_SERVICE_UUID = UUID.fromString("0000180A-0000-1000-8000-00805F9B34FB")
    private val DEVICE_NAME_UUID = UUID.fromString("00002A00-0000-1000-8000-00805F9B34FB")
    private val CLIENT_CONFIG_UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    
    // UUID для сервисов дорожки (fitness equipment)
    private val FITNESS_EQUIPMENT_SERVICE_UUID = UUID.fromString("00001826-0000-1000-8000-00805F9B34FB")
    private val FITNESS_CONTROL_POINT_UUID = UUID.fromString("00002AD9-0000-1000-8000-00805F9B34FB")
    private val FITNESS_FEATURE_UUID = UUID.fromString("00002ADA-0000-1000-8000-00805F9B34FB")
    
    // Custom UUID для получения данных от дорожки
    private val CUSTOM_DATA_SERVICE_UUID = UUID.fromString("12345678-1234-1234-1234-123456789ABC")
    private val TREADMILL_DATA_UUID = UUID.fromString("12345678-1234-1234-1234-123456789ABD")
    
    private var currentHeartRate = 75
    private var currentBatteryLevel = 85
    private var connectedDevice: BluetoothDevice? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Инициализируем Bluetooth
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        
        // GATT сервер будет инициализирован при запуске рекламации

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        Log.d("BLE", "MethodChannel initialized: $CHANNEL")
        methodChannel?.setMethodCallHandler { call, result ->
            // Логируем только важные методы, не обновления данных
            if (call.method != "updateHeartRate" && call.method != "updateBatteryLevel") {
                Log.d("BLE", "Method call received: ${call.method}")
            }
            when (call.method) {
                "startAdvertising" -> {
                    startBLEAdvertising(call, result)
                }
                "stopAdvertising" -> {
                    stopBLEAdvertising(result)
                }
                "updateHeartRate" -> {
                    updateHeartRateData(call, result)
                }
                "updateBatteryLevel" -> {
                    updateBatteryData(call, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Инициализируем канал для нативного подключения
        nativeConnectionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CONNECTION_CHANNEL)
        Log.d("BLE", "Native Connection Channel initialized: $NATIVE_CONNECTION_CHANNEL")
        nativeConnectionChannel?.setMethodCallHandler { call, result ->
            Log.d("BLE", "Native connection method call received: ${call.method}")
            when (call.method) {
                "connectToDevice" -> {
                    connectToDeviceNative(call, result)
                }
                "disconnectFromDevice" -> {
                    disconnectFromDeviceNative(call, result)
                }
                "discoverServices" -> {
                    discoverServicesNative(call, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Инициализируем сканер для нативного подключения
        scanner = bluetoothAdapter?.bluetoothLeScanner
    }

    private fun startBLEAdvertising(call: MethodCall, result: MethodChannel.Result) {
        // Проверяем все необходимые разрешения
        val permissions = arrayOf(
            android.Manifest.permission.BLUETOOTH_ADVERTISE,
            android.Manifest.permission.BLUETOOTH_CONNECT,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        )
        
        val missingPermissions = permissions.filter { 
            ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED 
        }
        
        if (missingPermissions.isNotEmpty()) {
            Log.e("BLE", "Missing permissions: ${missingPermissions.joinToString()}")
            result.error("PERMISSIONS_REQUIRED", "Missing permissions: ${missingPermissions.joinToString()}", null)
            return
        }

        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null)
            return
        }

        if (bluetoothLeAdvertiser == null) {
            result.error("BLE_NOT_SUPPORTED", "BLE advertising not supported", null)
            return
        }
        
        Log.d("BLE", "All permissions granted, proceeding with advertising setup")

        try {
            val deviceName = call.argument<String>("deviceName") ?: "Fitness Watch"
            val heartRateService = call.argument<String>("heartRateService") ?: "0000180D-0000-1000-8000-00805F9B34FB"
            val batteryService = call.argument<String>("batteryService") ?: "0000180F-0000-1000-8000-00805F9B34FB"
            val deviceInfoService = call.argument<String>("deviceInfoService") ?: "0000180A-0000-1000-8000-00805F9B34FB"

            // Останавливаем предыдущую рекламацию если есть
            advertisingCallback?.let { callback ->
                if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED) {
                    bluetoothLeAdvertiser?.stopAdvertising(callback)
                }
            }

            // Проверяем, что Bluetooth включен и доступен
            if (bluetoothAdapter?.isEnabled != true) {
                result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null)
                return
            }

            // Устанавливаем имя устройства для рекламации (требует разрешения BLUETOOTH_CONNECT)
            if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                try {
                    bluetoothAdapter?.name = deviceName
                    Log.d("BLE", "Device name set to: $deviceName")
                } catch (e: Exception) {
                    Log.w("BLE", "Failed to set device name: ${e.message}")
                }
            } else {
                Log.w("BLE", "BLUETOOTH_CONNECT permission not granted for setting device name")
            }

            // Настройки рекламации - используем BALANCED для лучшей видимости
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(0) // Без ограничения времени
                .build()

            // Данные рекламации - активно включаем все нужные данные
            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .addServiceUuid(ParcelUuid(UUID.fromString(heartRateService)))
                .addServiceUuid(ParcelUuid(UUID.fromString(batteryService)))
                .addServiceUuid(ParcelUuid(UUID.fromString(deviceInfoService)))
                .setIncludeTxPowerLevel(false) // Отключаем для экономии места в пакете
                .build()

            Log.d("BLE", "Starting advertising with device name: $deviceName")
            Log.d("BLE", "HeartRate Service UUID: $heartRateService")
            Log.d("BLE", "Battery Service UUID: $batteryService")
            Log.d("BLE", "DeviceInfo Service UUID: $deviceInfoService")

            // Callback для рекламации
            advertisingCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    Log.d("BLE", "Advertising started successfully!")
                    Log.d("BLE", "Settings in effect: mode=${settingsInEffect.mode}, power=${settingsInEffect.txPowerLevel}, connectable=${settingsInEffect.isConnectable}")
                    
                    // Тестовое уведомление Flutter о том, что рекламация запущена
                    try {
                        methodChannel?.invokeMethod("onAdvertisingStarted", mapOf(
                            "message" to "BLE рекламация запущена успешно",
                            "timestamp" to System.currentTimeMillis()
                        ))
                        Log.e("BLE", "Test notification sent to Flutter")
                    } catch (e: Exception) {
                        Log.e("BLE", "Error sending test notification: ${e.message}")
                    }
                    
                    result.success(true)
                }

                override fun onStartFailure(errorCode: Int) {
                    val errorMessage = when (errorCode) {
                        ADVERTISE_FAILED_DATA_TOO_LARGE -> "ADVERTISE_FAILED_DATA_TOO_LARGE"
                        ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                        ADVERTISE_FAILED_ALREADY_STARTED -> "ADVERTISE_FAILED_ALREADY_STARTED"
                        ADVERTISE_FAILED_INTERNAL_ERROR -> "ADVERTISE_FAILED_INTERNAL_ERROR"
                        ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                        else -> "Unknown error: $errorCode"
                    }
                    Log.e("BLE", "Failed to start advertising: $errorMessage ($errorCode)")
                    result.error("ADVERTISING_FAILED", errorMessage, errorCode)
                }
            }

            // Инициализируем GATT сервер и создаем сервисы перед рекламацией
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            try {
                Log.e("BLE", "=== CREATING GATT SERVER ===")
                bluetoothGattServer = bluetoothManager.openGattServer(this, gattServerCallback)
                if (bluetoothGattServer != null) {
                    Log.e("BLE", "GATT server created successfully!")
                    createGattServices()
                    Log.e("BLE", "GATT server created and services added")
                } else {
                    Log.e("BLE", "Failed to create GATT server - returned null")
                }
            } catch (e: Exception) {
                Log.e("BLE", "Error creating GATT server: ${e.message}")
                e.printStackTrace()
            }
            
            // Запускаем рекламацию (разрешения уже проверены выше)
            try {
                bluetoothLeAdvertiser?.startAdvertising(settings, data, advertisingCallback)
                Log.d("BLE", "Advertising start requested")
            } catch (e: Exception) {
                Log.e("BLE", "Error starting advertising: ${e.message}")
                result.error("ADVERTISING_ERROR", "Failed to start advertising: ${e.message}", null)
                return
            }

        } catch (e: Exception) {
            Log.e("BLE", "Error starting advertising", e)
            result.error("ADVERTISING_ERROR", e.message, null)
        }
    }

    private fun stopBLEAdvertising(result: MethodChannel.Result) {
        try {
            advertisingCallback?.let { callback ->
                if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED) {
                    bluetoothLeAdvertiser?.stopAdvertising(callback)
                    Log.d("BLE", "Advertising stopped")
                }
            }
            
            // Останавливаем GATT сервер
            bluetoothGattServer?.close()
            bluetoothGattServer = null
            
            result.success(true)
        } catch (e: Exception) {
            Log.e("BLE", "Error stopping advertising", e)
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun updateHeartRateData(call: MethodCall, result: MethodChannel.Result) {
        val heartRate = call.argument<Int>("heartRate") ?: 75
        currentHeartRate = heartRate
        
        // Отправляем обновленные данные пульса всем подключенным устройствам
        sendHeartRateNotification(heartRate)
        result.success(true)
    }

    private fun updateBatteryData(call: MethodCall, result: MethodChannel.Result) {
        val batteryLevel = call.argument<Int>("batteryLevel") ?: 85
        currentBatteryLevel = batteryLevel
        
        // Отправляем обновленные данные батареи всем подключенным устройствам
        sendBatteryNotification(batteryLevel)
        result.success(true)
    }
    
    // GATT Server Callback для обработки подключений и запросов
    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            super.onConnectionStateChange(device, status, newState)
            Log.e("BLE", "=== CONNECTION STATE CHANGE ===")
            Log.e("BLE", "Device: ${device.address} - Status: $status, State: $newState")
            Log.e("BLE", "Device name: ${device.name}, Bond state: ${device.bondState}")
            Log.e("BLE", "STATE_CONNECTED = ${BluetoothGatt.STATE_CONNECTED}")
            Log.e("BLE", "STATE_DISCONNECTED = ${BluetoothGatt.STATE_DISCONNECTED}")
            
            // Проверяем подключение - используем разные условия
            val isConnected = newState == BluetoothGatt.STATE_CONNECTED || 
                             newState == 2 || // Альтернативная проверка
                             (status == 0 && newState == 2)
            
            Log.e("BLE", "isConnected check: $isConnected (newState=$newState, status=$status)")
            
            if (isConnected) {
                Log.e("BLE", "=== DEVICE CONNECTED SUCCESSFULLY ===")
                Log.e("BLE", "Device: ${device.address}")
                Log.e("BLE", "Name: ${device.name}, Type: ${device.type}, Bond: ${device.bondState}")
                connectedDevice = device
                
                // Уведомляем Flutter о подключении с дополнительной информацией
                if (methodChannel == null) {
                    Log.e("BLE", "MethodChannel is null! Trying to reinitialize...")
                    // Попробуем переинициализировать methodChannel
                    try {
                        val flutterEngine = flutterEngine
                        if (flutterEngine != null) {
                            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                            Log.e("BLE", "MethodChannel reinitialized")
                        }
                    } catch (e: Exception) {
                        Log.e("BLE", "Failed to reinitialize MethodChannel: ${e.message}")
                    }
                }
                
                if (methodChannel != null) {
                    try {
                        // Собираем информацию о всех сервисах и характеристиках
                        val servicesInfo = mutableListOf<Map<String, Any>>()
                        bluetoothGattServer?.services?.forEach { service ->
                            val characteristicsInfo = mutableListOf<Map<String, Any>>()
                            service.characteristics.forEach { characteristic ->
                                characteristicsInfo.add(mapOf(
                                    "uuid" to characteristic.uuid.toString(),
                                    "properties" to characteristic.properties,
                                    "permissions" to characteristic.permissions,
                                    "value" to (characteristic.value?.let { 
                                        it.map { byte -> byte.toInt() } 
                                    } ?: emptyList<Int>())
                                ))
                            }
                            servicesInfo.add(mapOf(
                                "uuid" to service.uuid.toString(),
                                "type" to service.type,
                                "characteristics" to characteristicsInfo
                            ))
                        }
                        
                        val connectionData = mapOf<String, Any>(
                            "deviceName" to (device.name ?: "Неизвестное устройство"),
                            "deviceAddress" to device.address,
                            "deviceType" to device.type,
                            "bondState" to device.bondState,
                            "isConnected" to true,
                            "services" to servicesInfo,
                            "deviceClass" to (device.bluetoothClass?.majorDeviceClass ?: -1),
                            "deviceClassString" to getDeviceClassString(device.bluetoothClass?.majorDeviceClass ?: -1),
                            "timestamp" to System.currentTimeMillis()
                        )
                        Log.e("BLE", "Sending connection data to Flutter: $connectionData")
                        
                        // Выполняем на главном потоке
                        runOnUiThread {
                            try {
                                methodChannel?.invokeMethod("onDeviceConnected", connectionData)
                                Log.e("BLE", "Flutter notified about device connection: ${device.name}")
                            } catch (e: Exception) {
                                Log.e("BLE", "Error notifying Flutter on UI thread: ${e.message}")
                                e.printStackTrace()
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("BLE", "Error preparing connection data: ${e.message}")
                        e.printStackTrace()
                    }
                } else {
                    Log.e("BLE", "MethodChannel is still null! Cannot notify Flutter about connection")
                }
            } else {
                Log.e("BLE", "=== DEVICE DISCONNECTED OR OTHER STATE ===")
                Log.e("BLE", "Device: ${device.address}, State: $newState")
                if (connectedDevice?.address == device.address) {
                    connectedDevice = null
                    Log.e("BLE", "Cleared connected device")
                }
                // Уведомляем Flutter об отключении
                if (methodChannel != null) {
                    try {
                        val disconnectionData = mapOf(
                            "deviceAddress" to device.address,
                            "timestamp" to System.currentTimeMillis()
                        )
                        
                        // Выполняем на главном потоке
                        runOnUiThread {
                            try {
                                methodChannel?.invokeMethod("onDeviceDisconnected", disconnectionData)
                                Log.e("BLE", "Flutter notified about device disconnection")
                            } catch (e: Exception) {
                                Log.e("BLE", "Error notifying Flutter about disconnection on UI thread: ${e.message}")
                                e.printStackTrace()
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("BLE", "Error preparing disconnection data: ${e.message}")
                        e.printStackTrace()
                    }
                } else {
                    Log.e("BLE", "MethodChannel is null! Cannot notify Flutter about disconnection")
                }
            }
        }
        
        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            super.onServiceAdded(status, service)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d("BLE", "Service added successfully: ${service.uuid}")
            } else {
                Log.e("BLE", "Failed to add service: ${service.uuid}, status: $status")
            }
        }
        
        override fun onCharacteristicReadRequest(device: BluetoothDevice, requestId: Int, offset: Int, characteristic: BluetoothGattCharacteristic) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
            
            when (characteristic.uuid) {
                HEART_RATE_MEASUREMENT_UUID -> {
                    val heartRateData = encodeHeartRate(currentHeartRate)
                    characteristic.value = heartRateData
                    bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, heartRateData)
                }
                BATTERY_LEVEL_UUID -> {
                    val batteryData = byteArrayOf(currentBatteryLevel.toByte())
                    characteristic.value = batteryData
                    bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, batteryData)
                }
                DEVICE_NAME_UUID -> {
                    val deviceName = "Fitness Watch".toByteArray(Charsets.UTF_8)
                    characteristic.value = deviceName
                    bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, deviceName)
                }
            }
        }
        
        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)
            
            if (descriptor.uuid == CLIENT_CONFIG_UUID) {
                val enableNotifications = value.isNotEmpty() && value[0].toInt() == 1
                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
                
                if (enableNotifications) {
                    Log.d("BLE", "Notifications enabled for device: ${device.address}")
                    // Начинаем отправку периодических уведомлений о пульсе
                }
            }
        }
        
        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
            
            Log.d("BLE", "=== DATA RECEIVED FROM TREADMILL ===")
            Log.d("BLE", "Device: ${device.address} (${device.name ?: "Unknown"})")
            Log.d("BLE", "Characteristic UUID: ${characteristic.uuid}")
            Log.d("BLE", "Service UUID: ${characteristic.service.uuid}")
            Log.d("BLE", "Data size: ${value.size} bytes")
            Log.d("BLE", "Data HEX: ${value.joinToString(" ") { "%02X".format(it) }}")
            Log.d("BLE", "Offset: $offset, PreparedWrite: $preparedWrite, ResponseNeeded: $responseNeeded")
            
            // Обрабатываем данные от дорожки (принимаем данные на любую характеристику с WRITE свойством)
            // Не пытаемся преобразовывать бинарные данные в строку - это приводит к "каракулям"
            val hexString = value.joinToString(" ") { "%02X".format(it) }
            val dataString = try {
                // Пытаемся декодировать только если все байты в читаемом диапазоне
                val readableBytes = value.filter { it.toInt() in 32..126 || it.toInt() == 9 || it.toInt() == 10 || it.toInt() == 13 }
                if (readableBytes.size == value.size && readableBytes.isNotEmpty()) {
                    String(readableBytes.toByteArray(), Charsets.UTF_8)
                } else {
                    "Binary data (${value.size} bytes)"
                }
            } catch (e: Exception) {
                "Binary data (${value.size} bytes)"
            }
            
            Log.d("BLE", "Data as string: $dataString")
            
            // Уведомляем Flutter о полученных данных
            if (methodChannel != null) {
                try {
                    // Анализируем данные более детально
                    val dataAnalysis = analyzeReceivedData(value, characteristic.uuid.toString())
                    
                    val dataReceivedMap = mapOf(
                        "deviceAddress" to device.address,
                        "deviceName" to (device.name ?: "Unknown Device"),
                        "characteristicUuid" to characteristic.uuid.toString(),
                        "serviceUuid" to characteristic.service.uuid.toString(),
                        "data" to dataString,
                        "hexData" to hexString,
                        "rawData" to value.map { it.toInt() },
                        "dataSize" to value.size,
                        "offset" to offset,
                        "preparedWrite" to preparedWrite,
                        "responseNeeded" to responseNeeded,
                        "analysis" to dataAnalysis,
                        "timestamp" to System.currentTimeMillis()
                    )
                    
                    // Выполняем на главном потоке
                    runOnUiThread {
                        try {
                            methodChannel?.invokeMethod("onDataReceived", dataReceivedMap)
                            Log.d("BLE", "Flutter notified about received data")
                        } catch (e: Exception) {
                            Log.e("BLE", "Error notifying Flutter about data on UI thread: ${e.message}")
                            e.printStackTrace()
                        }
                    }
                } catch (e: Exception) {
                    Log.e("BLE", "Error preparing data notification: ${e.message}")
                    e.printStackTrace()
                }
            } else {
                Log.e("BLE", "MethodChannel is null! Cannot notify Flutter about received data")
            }
            
            // Отправляем ответ, если требуется
            if (responseNeeded) {
                bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                Log.d("BLE", "Response sent to device")
            }
        }
        
        override fun onExecuteWrite(device: BluetoothDevice, requestId: Int, execute: Boolean) {
            super.onExecuteWrite(device, requestId, execute)
            Log.d("BLE", "Execute write from ${device.address}: execute=$execute")
            
            bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
        }
        
        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            super.onNotificationSent(device, status)
            Log.d("BLE", "Notification sent to ${device.address}: status=$status")
        }
    }
    
    private fun createGattServices() {
        if (bluetoothGattServer == null) {
            Log.e("BLE", "GATT server is null, cannot create services")
            return
        }
        
        Log.d("BLE", "Creating GATT services...")
        
        // Heart Rate Service
        val heartRateService = BluetoothGattService(HEART_RATE_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        
        // Heart Rate Measurement Characteristic (Notify)
        val heartRateMeasurement = BluetoothGattCharacteristic(
            HEART_RATE_MEASUREMENT_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val heartRateConfigDescriptor = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        heartRateMeasurement.addDescriptor(heartRateConfigDescriptor)
        heartRateService.addCharacteristic(heartRateMeasurement)
        
        // Battery Service
        val batteryService = BluetoothGattService(BATTERY_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        
        // Battery Level Characteristic (Read, Notify)
        val batteryLevel = BluetoothGattCharacteristic(
            BATTERY_LEVEL_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val batteryConfigDescriptor = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        batteryLevel.addDescriptor(batteryConfigDescriptor)
        batteryService.addCharacteristic(batteryLevel)
        
        // Device Information Service
        val deviceInfoService = BluetoothGattService(DEVICE_INFO_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        
        // Device Name Characteristic (Read)
        val deviceName = BluetoothGattCharacteristic(
            DEVICE_NAME_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        deviceInfoService.addCharacteristic(deviceName)
        
        // Custom Service для получения данных от дорожки
        val customDataService = BluetoothGattService(CUSTOM_DATA_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        
        // Характеристика для данных дорожки (Write + Read)
        val treadmillData = BluetoothGattCharacteristic(
            TREADMILL_DATA_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val dataConfigDescriptor = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        treadmillData.addDescriptor(dataConfigDescriptor)
        customDataService.addCharacteristic(treadmillData)
        
        // Fitness Machine Service - стандартный сервис для фитнес-оборудования (включая дорожки)
        // Это позволяет дорожке отправлять нам данные через стандартный протокол
        val fitnessMachineService = BluetoothGattService(FITNESS_EQUIPMENT_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        
        // Fitness Machine Control Point - для получения команд и данных от дорожки
        val fitnessControlPoint = BluetoothGattCharacteristic(
            FITNESS_CONTROL_POINT_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_INDICATE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val controlPointConfigDescriptor = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        fitnessControlPoint.addDescriptor(controlPointConfigDescriptor)
        fitnessMachineService.addCharacteristic(fitnessControlPoint)
        
        // Fitness Machine Feature - для получения информации о возможностях дорожки
        val fitnessFeature = BluetoothGattCharacteristic(
            FITNESS_FEATURE_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        fitnessMachineService.addCharacteristic(fitnessFeature)
        
        // Treadmill Data Characteristic (стандартный UUID для данных дорожки)
        // UUID: 00002ACD-0000-1000-8000-00805F9B34FB
        val treadmillDataCharUuid = UUID.fromString("00002ACD-0000-1000-8000-00805F9B34FB")
        val treadmillDataChar = BluetoothGattCharacteristic(
            treadmillDataCharUuid,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val treadmillDataConfigDescriptor = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        treadmillDataChar.addDescriptor(treadmillDataConfigDescriptor)
        fitnessMachineService.addCharacteristic(treadmillDataChar)
        
        // Добавляем сервисы к GATT серверу один за другим
        try {
            Log.d("BLE", "Adding Heart Rate Service...")
            bluetoothGattServer?.addService(heartRateService)
            
            Log.d("BLE", "Adding Battery Service...")
            bluetoothGattServer?.addService(batteryService)
            
            Log.d("BLE", "Adding Device Info Service...")
            bluetoothGattServer?.addService(deviceInfoService)
            
            Log.d("BLE", "Adding Custom Data Service for treadmill...")
            bluetoothGattServer?.addService(customDataService)
            
            Log.d("BLE", "Adding Fitness Machine Service (standard for treadmills)...")
            bluetoothGattServer?.addService(fitnessMachineService)
            
            Log.d("BLE", "All GATT services added successfully")
        } catch (e: Exception) {
            Log.e("BLE", "Error adding GATT services: ${e.message}")
        }
    }
    
    private fun sendHeartRateNotification(heartRate: Int) {
        val characteristic = bluetoothGattServer?.getService(HEART_RATE_SERVICE_UUID)
            ?.getCharacteristic(HEART_RATE_MEASUREMENT_UUID)
        
        characteristic?.let { char ->
            char.value = encodeHeartRate(heartRate)
            // Отправляем уведомление всем подключенным устройствам
            // bluetoothGattServer?.notifyCharacteristicChanged(device, char, false)
        }
    }
    
    private fun sendBatteryNotification(batteryLevel: Int) {
        val characteristic = bluetoothGattServer?.getService(BATTERY_SERVICE_UUID)
            ?.getCharacteristic(BATTERY_LEVEL_UUID)
        
        characteristic?.let { char ->
            char.value = byteArrayOf(batteryLevel.toByte())
        }
    }
    
    private fun encodeHeartRate(heartRate: Int): ByteArray {
        // Кодируем данные пульса согласно спецификации Heart Rate Service
        val flags = 0x00 // Без контакта с датчиком, UINT16 format
        val hrValue = heartRate.toShort().toInt() and 0xFFFF
        
        return byteArrayOf(
            flags.toByte(),
            (hrValue and 0xFF).toByte(),      // LSB
            ((hrValue shr 8) and 0xFF).toByte() // MSB
        )
    }
    
    private fun getDeviceClassString(deviceClass: Int): String {
        return when (deviceClass) {
            0x200 -> "Аудио/Видео"
            0x100 -> "Компьютер"
            0x900 -> "Здоровье/Фитнес"
            0x600 -> "Изображения"
            0x000 -> "Разное"
            0x300 -> "Сеть"
            0x500 -> "Периферия"
            0x200 -> "Телефон"
            0x800 -> "Игрушка"
            0x700 -> "Носимые устройства"
            else -> "Неизвестный класс ($deviceClass)"
        }
    }
    
    private fun analyzeReceivedData(data: ByteArray, characteristicUuid: String): Map<String, Any> {
        val analysis = mutableMapOf<String, Any>()
        
        // Базовый анализ
        analysis["size"] = data.size
        analysis["hex"] = data.joinToString(" ") { "%02X".format(it) }
        analysis["decimal"] = data.joinToString(" ") { it.toInt().toString() }
        analysis["binary"] = data.joinToString(" ") { Integer.toBinaryString(it.toInt() and 0xFF).padStart(8, '0') }
        
        // Попытка декодирования как строка
        try {
            val stringValue = String(data, Charsets.UTF_8)
            if (stringValue.matches(Regex("[\\x20-\\x7E\\x0A\\x0D\\x09]*")) && stringValue.trim().isNotEmpty()) {
                analysis["utf8"] = stringValue
            }
        } catch (e: Exception) {
            analysis["utf8"] = "Ошибка декодирования UTF-8"
        }
        
        // Анализ по размеру данных
        when (data.size) {
            1 -> {
                analysis["interpretation"] = "Однобайтовое значение"
                analysis["value"] = data[0].toInt() and 0xFF
                analysis["signed"] = data[0].toInt()
            }
            2 -> {
                analysis["interpretation"] = "16-битное значение"
                val value = ((data[1].toInt() and 0xFF) shl 8) or (data[0].toInt() and 0xFF)
                analysis["littleEndian"] = value
                val bigEndian = ((data[0].toInt() and 0xFF) shl 8) or (data[1].toInt() and 0xFF)
                analysis["bigEndian"] = bigEndian
            }
            4 -> {
                analysis["interpretation"] = "32-битное значение"
                val littleEndian = ((data[3].toInt() and 0xFF) shl 24) or 
                                  ((data[2].toInt() and 0xFF) shl 16) or 
                                  ((data[1].toInt() and 0xFF) shl 8) or 
                                  (data[0].toInt() and 0xFF)
                analysis["littleEndian"] = littleEndian
                val bigEndian = ((data[0].toInt() and 0xFF) shl 24) or 
                               ((data[1].toInt() and 0xFF) shl 16) or 
                               ((data[2].toInt() and 0xFF) shl 8) or 
                               (data[3].toInt() and 0xFF)
                analysis["bigEndian"] = bigEndian
            }
            else -> {
                analysis["interpretation"] = "Многобайтовые данные"
            }
        }
        
        // Специфичный анализ для известных характеристик
        when (characteristicUuid) {
            TREADMILL_DATA_UUID.toString() -> {
                analysis["type"] = "Данные дорожки"
                if (data.size >= 1) {
                    analysis["command"] = data[0].toInt() and 0xFF
                }
            }
        }
        
        return analysis
    }
    
    // ========== НАТИВНОЕ ПОДКЛЮЧЕНИЕ К УСТРОЙСТВУ ==========
    
    private fun connectToDeviceNative(call: MethodCall, result: MethodChannel.Result) {
        val permissions = arrayOf(
            android.Manifest.permission.BLUETOOTH_CONNECT,
            android.Manifest.permission.BLUETOOTH_SCAN,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        )
        
        val missingPermissions = permissions.filter { 
            ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED 
        }
        
        if (missingPermissions.isNotEmpty()) {
            Log.e("BLE_NATIVE", "Missing permissions: ${missingPermissions.joinToString()}")
            result.error("PERMISSIONS_REQUIRED", "Missing permissions: ${missingPermissions.joinToString()}", null)
            return
        }
        
        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null)
            return
        }
        
        try {
            val deviceAddress = call.argument<String>("deviceAddress")
            
            if (deviceAddress == null) {
                result.error("INVALID_ARGUMENT", "Device address is required", null)
                return
            }
            
            Log.d("BLE_NATIVE", "Attempting to connect to device: $deviceAddress")
            
            // Получаем устройство по адресу
            val device = if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                bluetoothAdapter?.getRemoteDevice(deviceAddress)
            } else {
                result.error("PERMISSIONS_REQUIRED", "BLUETOOTH_CONNECT permission required", null)
                return
            }
            
            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "Device not found", null)
                return
            }
            
            // Проверяем, не подключены ли уже
            val existingGatt = connectedGattDevices[deviceAddress]
            if (existingGatt != null) {
                Log.d("BLE_NATIVE", "Already connected to device: $deviceAddress")
                result.success(mapOf(
                    "success" to true,
                    "deviceAddress" to deviceAddress,
                    "deviceName" to (device.name ?: "Unknown Device"),
                    "message" to "Already connected"
                ))
                return
            }
            
            // Подключаемся как GATT клиент
            val gattCallback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    super.onConnectionStateChange(gatt, status, newState)
                    Log.d("BLE_NATIVE", "Connection state changed: status=$status, newState=$newState")
                    
                    if (newState == BluetoothGatt.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                        Log.d("BLE_NATIVE", "Successfully connected to device: ${gatt.device.address}")
                        connectedGattDevices[deviceAddress] = gatt
                        
                        // Автоматически запускаем обнаружение сервисов после успешного подключения
                        if (ActivityCompat.checkSelfPermission(this@MainActivity, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                            val discoveryStarted = gatt.discoverServices()
                            Log.d("BLE_NATIVE", "Service discovery started: $discoveryStarted")
                        }
                        
                        // Уведомляем Flutter о подключении
                        runOnUiThread {
                            try {
                                nativeConnectionChannel?.invokeMethod("onDeviceConnected", mapOf(
                                    "deviceAddress" to deviceAddress,
                                    "deviceName" to (device.name ?: "Unknown Device"),
                                    "bondState" to device.bondState,
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            } catch (e: Exception) {
                                Log.e("BLE_NATIVE", "Error notifying Flutter: ${e.message}")
                            }
                        }
                    } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                        Log.d("BLE_NATIVE", "Disconnected from device: ${gatt.device.address}, status=$status")
                        
                        // Останавливаем периодическое чтение
                        stopPeriodicCharacteristicReading(deviceAddress)
                        
                        connectedGattDevices.remove(deviceAddress)
                        characteristicsToRead.remove(deviceAddress)
                        
                        // Закрываем GATT подключение
                        try {
                            gatt.close()
                        } catch (e: Exception) {
                            Log.e("BLE_NATIVE", "Error closing GATT: ${e.message}")
                        }
                        
                        // Уведомляем Flutter об отключении с информацией об ошибке
                        runOnUiThread {
                            try {
                                val errorMessage = when (status) {
                                    133 -> "GATT_ERROR - Connection failed (status 133)"
                                    8 -> "GATT_INTERNAL_ERROR"
                                    19 -> "GATT_INSUFFICIENT_AUTHORIZATION"
                                    22 -> "GATT_INSUFFICIENT_ENCRYPTION"
                                    else -> if (status != 0) "Connection error: status=$status" else null
                                }
                                
                                nativeConnectionChannel?.invokeMethod("onDeviceDisconnected", mapOf(
                                    "deviceAddress" to deviceAddress,
                                    "errorStatus" to status,
                                    "errorMessage" to (errorMessage ?: ""),
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            } catch (e: Exception) {
                                Log.e("BLE_NATIVE", "Error notifying Flutter: ${e.message}")
                            }
                        }
                    }
                }
                
                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    super.onServicesDiscovered(gatt, status)
                    Log.d("BLE_NATIVE", "Services discovered: status=$status")
                    
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val servicesInfo = mutableListOf<Map<String, Any>>()
                        var subscribedCount = 0
                        
                        gatt.services.forEach { service ->
                            val characteristicsInfo = mutableListOf<Map<String, Any>>()
                            
                            service.characteristics.forEach { characteristic ->
                                val hasNotify = (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
                                val hasIndicate = (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0
                                
                                characteristicsInfo.add(mapOf(
                                    "uuid" to characteristic.uuid.toString(),
                                    "properties" to characteristic.properties,
                                    "permissions" to characteristic.permissions,
                                    "hasNotify" to hasNotify,
                                    "hasIndicate" to hasIndicate
                                ))
                                
                                // Автоматически подписываемся на характеристики с NOTIFY или INDICATE
                                if ((hasNotify || hasIndicate) && ActivityCompat.checkSelfPermission(
                                        this@MainActivity,
                                        android.Manifest.permission.BLUETOOTH_CONNECT
                                    ) == PackageManager.PERMISSION_GRANTED) {
                                    try {
                                        // Включаем уведомления/индикации
                                        val descriptor = characteristic.getDescriptor(CLIENT_CONFIG_UUID)
                                        if (descriptor != null) {
                                            val enableValue = if (hasIndicate) {
                                                BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                                            } else {
                                                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                            }
                                            
                                            descriptor.value = enableValue
                                            val writeSuccess = gatt.writeDescriptor(descriptor)
                                            
                                            if (writeSuccess) {
                                                subscribedCount++
                                                Log.d("BLE_NATIVE", "Subscribed to ${characteristic.uuid} (${if (hasIndicate) "INDICATE" else "NOTIFY"})")
                                            } else {
                                                Log.w("BLE_NATIVE", "Failed to subscribe to ${characteristic.uuid}")
                                            }
                                        } else {
                                            Log.w("BLE_NATIVE", "No descriptor found for ${characteristic.uuid}")
                                        }
                                    } catch (e: Exception) {
                                        Log.e("BLE_NATIVE", "Error subscribing to ${characteristic.uuid}: ${e.message}")
                                    }
                                }
                                
                                // Также сохраняем характеристики с READ свойством для периодического чтения
                                val hasRead = (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0
                                val isFitnessMachineService = service.uuid.toString().contains("1826", ignoreCase = true)
                                val isTreadmillData = characteristic.uuid.toString().contains("2ACD", ignoreCase = true) ||
                                                      characteristic.uuid.toString().contains("2AD9", ignoreCase = true) ||
                                                      characteristic.uuid.toString().contains("2ADA", ignoreCase = true)
                                
                                // Сохраняем важные характеристики для дорожек для периодического чтения (если они не поддерживают NOTIFY)
                                if (hasRead && !hasNotify && !hasIndicate && (isFitnessMachineService || isTreadmillData)) {
                                    if (!characteristicsToRead.containsKey(deviceAddress)) {
                                        characteristicsToRead[deviceAddress] = mutableListOf()
                                    }
                                    characteristicsToRead[deviceAddress]?.add(characteristic)
                                    Log.d("BLE_NATIVE", "Added ${characteristic.uuid} to periodic read list")
                                }
                            }
                            
                            servicesInfo.add(mapOf(
                                "uuid" to service.uuid.toString(),
                                "type" to service.type,
                                "characteristics" to characteristicsInfo
                            ))
                        }
                        
                        Log.d("BLE_NATIVE", "Subscribed to $subscribedCount characteristics with NOTIFY/INDICATE")
                        
                        // Запускаем периодическое чтение характеристик, которые не поддерживают NOTIFY
                        val characteristicsForReading = characteristicsToRead[deviceAddress]
                        if (characteristicsForReading != null && characteristicsForReading.isNotEmpty()) {
                            Log.d("BLE_NATIVE", "Starting periodic read for ${characteristicsForReading.size} characteristics")
                            startPeriodicCharacteristicReading(gatt, deviceAddress, characteristicsForReading)
                        }
                        
                        runOnUiThread {
                            try {
                                nativeConnectionChannel?.invokeMethod("onServicesDiscovered", mapOf(
                                    "deviceAddress" to deviceAddress,
                                    "services" to servicesInfo,
                                    "subscribedCount" to subscribedCount,
                                    "readCharacteristicsCount" to (characteristicsForReading?.size ?: 0),
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            } catch (e: Exception) {
                                Log.e("BLE_NATIVE", "Error notifying Flutter: ${e.message}")
                            }
                        }
                    }
                }
                
                override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                    super.onDescriptorWrite(gatt, descriptor, status)
                    Log.d("BLE_NATIVE", "Descriptor write: ${descriptor.uuid}, status=$status")
                    
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val characteristic = descriptor.characteristic
                        val isEnabled = descriptor.value?.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) == true ||
                                      descriptor.value?.contentEquals(BluetoothGattDescriptor.ENABLE_INDICATION_VALUE) == true
                        
                        Log.d("BLE_NATIVE", "Notifications ${if (isEnabled) "enabled" else "disabled"} for ${characteristic.uuid}")
                    }
                }
                
                override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    super.onCharacteristicWrite(gatt, characteristic, status)
                    Log.d("BLE_NATIVE", "Characteristic write: ${characteristic.uuid}, status=$status")
                }
                
                override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                    super.onCharacteristicRead(gatt, characteristic, status)
                    Log.d("BLE_NATIVE", "Characteristic read: ${characteristic.uuid}, status=$status")
                    
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val data = characteristic.value ?: byteArrayOf()
                        val hexString = data.joinToString(" ") { "%02X".format(it) }
                        val dataString = try {
                            // Пытаемся декодировать только если все байты в читаемом диапазоне
                            val readableBytes = data.filter { it.toInt() in 32..126 || it.toInt() == 9 || it.toInt() == 10 || it.toInt() == 13 }
                            if (readableBytes.size == data.size && readableBytes.isNotEmpty()) {
                                String(readableBytes.toByteArray(), Charsets.UTF_8)
                            } else {
                                "Binary data (${data.size} bytes)"
                            }
                        } catch (e: Exception) {
                            "Binary data (${data.size} bytes)"
                        }
                        
                        // Анализируем данные
                        val dataAnalysis = analyzeReceivedData(data, characteristic.uuid.toString())
                        
                        runOnUiThread {
                            try {
                                // Отправляем данные в Flutter в том же формате, что и через NOTIFY
                                nativeConnectionChannel?.invokeMethod("onCharacteristicRead", mapOf(
                                    "deviceAddress" to deviceAddress,
                                    "deviceName" to (gatt.device.name ?: "Unknown Device"),
                                    "characteristicUuid" to characteristic.uuid.toString(),
                                    "serviceUuid" to characteristic.service.uuid.toString(),
                                    "hexData" to hexString,
                                    "rawData" to data.map { it.toInt() },
                                    "data" to dataString,
                                    "dataSize" to data.size,
                                    "analysis" to dataAnalysis,
                                    "timestamp" to System.currentTimeMillis()
                                ))
                                
                                // Также отправляем через основной канал для совместимости
                                methodChannel?.invokeMethod("onDataReceived", mapOf(
                                    "deviceAddress" to deviceAddress,
                                    "deviceName" to (gatt.device.name ?: "Unknown Device"),
                                    "characteristicUuid" to characteristic.uuid.toString(),
                                    "serviceUuid" to characteristic.service.uuid.toString(),
                                    "hexData" to hexString,
                                    "rawData" to data.map { it.toInt() },
                                    "data" to dataString,
                                    "dataSize" to data.size,
                                    "analysis" to dataAnalysis,
                                    "timestamp" to System.currentTimeMillis()
                                ))
                                
                                Log.d("BLE_NATIVE", "Flutter notified about received data via READ")
                            } catch (e: Exception) {
                                Log.e("BLE_NATIVE", "Error notifying Flutter: ${e.message}")
                            }
                        }
                    }
                }
                
                override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                    super.onCharacteristicChanged(gatt, characteristic)
                    Log.d("BLE_NATIVE", "=== DATA RECEIVED VIA NOTIFY/INDICATE ===")
                    Log.d("BLE_NATIVE", "Device: ${gatt.device.address} (${gatt.device.name ?: "Unknown"})")
                    Log.d("BLE_NATIVE", "Characteristic UUID: ${characteristic.uuid}")
                    Log.d("BLE_NATIVE", "Service UUID: ${characteristic.service.uuid}")
                    
                    val data = characteristic.value ?: byteArrayOf()
                    Log.d("BLE_NATIVE", "Data size: ${data.size} bytes")
                    val hexString = data.joinToString(" ") { "%02X".format(it) }
                    Log.d("BLE_NATIVE", "Data HEX: $hexString")
                    
                    val dataString = try {
                        // Пытаемся декодировать только если все байты в читаемом диапазоне
                        val readableBytes = data.filter { it.toInt() in 32..126 || it.toInt() == 9 || it.toInt() == 10 || it.toInt() == 13 }
                        if (readableBytes.size == data.size && readableBytes.isNotEmpty()) {
                            String(readableBytes.toByteArray(), Charsets.UTF_8)
                        } else {
                            "Binary data (${data.size} bytes)"
                        }
                    } catch (e: Exception) {
                        "Binary data (${data.size} bytes)"
                    }
                    
                    // Анализируем данные
                    val dataAnalysis = analyzeReceivedData(data, characteristic.uuid.toString())
                    
                    runOnUiThread {
                        try {
                            // Отправляем данные в Flutter через оба канала для совместимости
                            nativeConnectionChannel?.invokeMethod("onCharacteristicChanged", mapOf(
                                "deviceAddress" to deviceAddress,
                                "deviceName" to (gatt.device.name ?: "Unknown Device"),
                                "characteristicUuid" to characteristic.uuid.toString(),
                                "serviceUuid" to characteristic.service.uuid.toString(),
                                "hexData" to hexString,
                                "rawData" to data.map { it.toInt() },
                                "data" to dataString,
                                "dataSize" to data.size,
                                "analysis" to dataAnalysis,
                                "timestamp" to System.currentTimeMillis()
                            ))
                            
                            // Также отправляем через основной канал для совместимости с существующим кодом
                            methodChannel?.invokeMethod("onDataReceived", mapOf(
                                "deviceAddress" to deviceAddress,
                                "deviceName" to (gatt.device.name ?: "Unknown Device"),
                                "characteristicUuid" to characteristic.uuid.toString(),
                                "serviceUuid" to characteristic.service.uuid.toString(),
                                "hexData" to hexString,
                                "rawData" to data.map { it.toInt() },
                                "data" to dataString,
                                "dataSize" to data.size,
                                "analysis" to dataAnalysis,
                                "timestamp" to System.currentTimeMillis()
                            ))
                            
                            Log.d("BLE_NATIVE", "Flutter notified about received data via NOTIFY/INDICATE")
                        } catch (e: Exception) {
                            Log.e("BLE_NATIVE", "Error notifying Flutter: ${e.message}")
                        }
                    }
                }
            }
            
            // Подключаемся
            bluetoothGattClient = if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                device.connectGatt(this, false, gattCallback)
            } else {
                result.error("PERMISSIONS_REQUIRED", "BLUETOOTH_CONNECT permission required", null)
                return
            }
            
            if (bluetoothGattClient == null) {
                result.error("CONNECTION_FAILED", "Failed to initiate connection", null)
                return
            }
            
            Log.d("BLE_NATIVE", "Connection initiated, waiting for callback...")
            result.success(mapOf(
                "success" to true,
                "deviceAddress" to deviceAddress,
                "deviceName" to (device.name ?: "Unknown Device"),
                "message" to "Connection initiated"
            ))
            
        } catch (e: Exception) {
            Log.e("BLE_NATIVE", "Error connecting to device: ${e.message}")
            result.error("CONNECTION_ERROR", e.message, null)
        }
    }
    
    private fun disconnectFromDeviceNative(call: MethodCall, result: MethodChannel.Result) {
        val permissions = arrayOf(
            android.Manifest.permission.BLUETOOTH_CONNECT
        )
        
        val missingPermissions = permissions.filter { 
            ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED 
        }
        
        if (missingPermissions.isNotEmpty()) {
            result.error("PERMISSIONS_REQUIRED", "Missing permissions: ${missingPermissions.joinToString()}", null)
            return
        }
        
        try {
            val deviceAddress = call.argument<String>("deviceAddress")
            
            if (deviceAddress == null) {
                result.error("INVALID_ARGUMENT", "Device address is required", null)
                return
            }
            
            val gatt = connectedGattDevices[deviceAddress]
            if (gatt != null) {
                // Останавливаем периодическое чтение
                stopPeriodicCharacteristicReading(deviceAddress)
                
                if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                    gatt.disconnect()
                    gatt.close()
                }
                connectedGattDevices.remove(deviceAddress)
                characteristicsToRead.remove(deviceAddress)
                Log.d("BLE_NATIVE", "Disconnected from device: $deviceAddress")
                result.success(mapOf("success" to true))
            } else {
                result.success(mapOf("success" to false, "message" to "Device not connected"))
            }
        } catch (e: Exception) {
            Log.e("BLE_NATIVE", "Error disconnecting: ${e.message}")
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }
    
    private fun discoverServicesNative(call: MethodCall, result: MethodChannel.Result) {
        val permissions = arrayOf(
            android.Manifest.permission.BLUETOOTH_CONNECT
        )
        
        val missingPermissions = permissions.filter { 
            ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED 
        }
        
        if (missingPermissions.isNotEmpty()) {
            result.error("PERMISSIONS_REQUIRED", "Missing permissions: ${missingPermissions.joinToString()}", null)
            return
        }
        
        try {
            val deviceAddress = call.argument<String>("deviceAddress")
            
            if (deviceAddress == null) {
                result.error("INVALID_ARGUMENT", "Device address is required", null)
                return
            }
            
            val gatt = connectedGattDevices[deviceAddress]
            if (gatt != null) {
                if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
                    val success = gatt.discoverServices()
                    if (success) {
                        Log.d("BLE_NATIVE", "Service discovery started for: $deviceAddress")
                        result.success(mapOf("success" to true))
                    } else {
                        result.error("SERVICE_DISCOVERY_FAILED", "Failed to start service discovery", null)
                    }
                } else {
                    result.error("PERMISSIONS_REQUIRED", "BLUETOOTH_CONNECT permission required", null)
                }
            } else {
                result.error("DEVICE_NOT_CONNECTED", "Device is not connected", null)
            }
        } catch (e: Exception) {
            Log.e("BLE_NATIVE", "Error discovering services: ${e.message}")
            result.error("SERVICE_DISCOVERY_ERROR", e.message, null)
        }
    }
    
    // Периодическое чтение характеристик для получения данных от дорожки
    private fun startPeriodicCharacteristicReading(gatt: BluetoothGatt, deviceAddress: String, characteristics: List<BluetoothGattCharacteristic>) {
        if (characteristics.isEmpty()) return
        
        // Останавливаем предыдущий handler если есть
        stopPeriodicCharacteristicReading(deviceAddress)
        
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        readHandlers[deviceAddress] = handler
        
        var currentIndex = 0
        val readRunnable = object : Runnable {
            override fun run() {
                val gattConnection = connectedGattDevices[deviceAddress]
                if (gattConnection == null || gattConnection != gatt) {
                    // Устройство отключено, останавливаем чтение
                    stopPeriodicCharacteristicReading(deviceAddress)
                    return
                }
                
                if (currentIndex < characteristics.size) {
                    val characteristic = characteristics[currentIndex]
                    if (ActivityCompat.checkSelfPermission(
                            this@MainActivity,
                            android.Manifest.permission.BLUETOOTH_CONNECT
                        ) == PackageManager.PERMISSION_GRANTED) {
                        try {
                            val readSuccess = gatt.readCharacteristic(characteristic)
                            if (readSuccess) {
                                Log.d("BLE_NATIVE", "Periodic read: ${characteristic.uuid}")
                            }
                        } catch (e: Exception) {
                            Log.e("BLE_NATIVE", "Error in periodic read: ${e.message}")
                        }
                    }
                    currentIndex = (currentIndex + 1) % characteristics.size
                }
                
                // Читаем каждую секунду
                handler.postDelayed(this, 1000)
            }
        }
        
        // Запускаем с небольшой задержкой
        handler.postDelayed(readRunnable, 500)
        Log.d("BLE_NATIVE", "Started periodic reading for ${characteristics.size} characteristics")
    }
    
    private fun stopPeriodicCharacteristicReading(deviceAddress: String) {
        val handler = readHandlers.remove(deviceAddress)
        handler?.removeCallbacksAndMessages(null)
        Log.d("BLE_NATIVE", "Stopped periodic reading for device: $deviceAddress")
    }
}
