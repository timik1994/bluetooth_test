package com.example.bluetooth_test_main

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
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
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var bluetoothGattServer: BluetoothGattServer? = null
    private var advertisingCallback: AdvertiseCallback? = null
    private var methodChannel: MethodChannel? = null
    
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
            Log.d("BLE", "Method call received: ${call.method}")
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
            Log.d("BLE", "Characteristic: ${characteristic.uuid}")
            Log.d("BLE", "Data size: ${value.size} bytes")
            Log.d("BLE", "Data HEX: ${value.joinToString(" ") { "%02X".format(it) }}")
            Log.d("BLE", "Offset: $offset, PreparedWrite: $preparedWrite, ResponseNeeded: $responseNeeded")
            
            // Обрабатываем данные от дорожки
            val dataString = try {
                String(value, Charsets.UTF_8)
            } catch (e: Exception) {
                "Binary data (${value.size} bytes)"
            }
            val hexString = value.joinToString(" ") { "%02X".format(it) }
            
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
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val dataConfigDescriptor = BluetoothGattDescriptor(
            CLIENT_CONFIG_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        treadmillData.addDescriptor(dataConfigDescriptor)
        customDataService.addCharacteristic(treadmillData)
        
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
}
