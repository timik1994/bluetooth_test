import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/entities/bluetooth_log_entity.dart';
import '../models/bluetooth_device_model.dart';
import '../services/app_logger.dart';

abstract class BluetoothSimpleDataSource {
  Stream<List<BluetoothDeviceEntity>> get discoveredDevices;
  Stream<BluetoothLogEntity> get logs;
  Stream<bool> get isScanning;
  Stream<bool> get isBluetoothEnabled;

  Future<bool> isBluetoothAvailable();
  Future<bool> requestPermissions();
  Future<void> startScan();
  Future<void> stopScan();
  Future<bool> connectToDevice(String deviceId);
  Future<void> disconnectFromDevice(String deviceId);
  Future<void> clearLogs();
  Future<List<BluetoothLogEntity>> getLogs();
}

class BluetoothSimpleDataSourceImpl implements BluetoothSimpleDataSource {
  final StreamController<List<BluetoothDeviceEntity>> _devicesController =
      StreamController<List<BluetoothDeviceEntity>>.broadcast();
  final StreamController<BluetoothLogEntity> _logsController =
      StreamController<BluetoothLogEntity>.broadcast();
  final StreamController<bool> _isScanningController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _isBluetoothEnabledController =
      StreamController<bool>.broadcast();

  final List<BluetoothLogEntity> _logs = [];
  final Map<String, BluetoothDeviceEntity> _discoveredDevices = {};
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final AppLogger _appLogger = AppLogger();
  
  StreamSubscription? _scanResultsSubscription;
  bool _isInitialized = false;

  BluetoothSimpleDataSourceImpl() {
    _initializeAppLogger();
    _initializeBluetooth(); // Инициализируем сразу при создании
  }

  void _initializeAppLogger() async {
    await _appLogger.initialize();
  }

  void _initializeBluetooth() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Слушаем изменения состояния Bluetooth
    FlutterBluePlus.adapterState.listen((state) {
      final isEnabled = state == BluetoothAdapterState.on;
      _isBluetoothEnabledController.add(isEnabled);
      _addLog(LogLevel.info, 'Bluetooth состояние изменилось: ${isEnabled ? "Включен" : "Выключен"}');
    });

    // Слушаем изменения состояния сканирования
    FlutterBluePlus.isScanning.listen((scanning) {
      _isScanningController.add(scanning);
    });
    
    // Получаем текущее состояние Bluetooth сразу
    FlutterBluePlus.adapterState.first.then((state) {
      final isEnabled = state == BluetoothAdapterState.on;
      _isBluetoothEnabledController.add(isEnabled);
    }).catchError((e) {
      _addLog(LogLevel.error, 'Ошибка получения начального состояния Bluetooth: $e');
    });
  }

  @override
  Stream<List<BluetoothDeviceEntity>> get discoveredDevices => _devicesController.stream;

  @override
  Stream<BluetoothLogEntity> get logs => _logsController.stream;

  @override
  Stream<bool> get isScanning => _isScanningController.stream;

  @override
  Stream<bool> get isBluetoothEnabled => _isBluetoothEnabledController.stream;

  @override
  Future<bool> isBluetoothAvailable() async {
    try {
      _initializeBluetooth();
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка проверки доступности Bluetooth: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      _addLog(LogLevel.info, 'Запрос разрешений Bluetooth...');

      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ];

      final results = await permissions.request();
      final allGranted = results.values.every((status) => status.isGranted);

      if (allGranted) {
        _addLog(LogLevel.info, 'Все разрешения Bluetooth получены');
      } else {
        final deniedPermissions = results.entries
            .where((entry) => !entry.value.isGranted)
            .map((entry) => entry.key.toString())
            .join(', ');
        _addLog(LogLevel.warning, 'Не все разрешения получены. Отклонены: $deniedPermissions');
      }

      return allGranted;
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка запроса разрешений: $e');
      return false;
    }
  }

  @override
  Future<void> startScan() async {
    try {
      _initializeBluetooth();
      _addLog(LogLevel.info, '🔍 Начинаем поиск Bluetooth устройств...');

      final isAvailable = await isBluetoothAvailable();
      if (!isAvailable) {
        _addLog(LogLevel.error, 'Bluetooth недоступен');
        return;
      }

      // Очищаем предыдущие результаты
      _discoveredDevices.clear();
      
      // Сначала добавляем уже подключенные устройства
      await _loadConnectedDevices();

      // Запускаем сканирование
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: true,
      );

      // Отменяем предыдущую подписку
      await _scanResultsSubscription?.cancel();

      // Слушаем результаты сканирования
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        for(int i=0;i<results.length;i++){
          print(results[i].advertisementData.toString());
        }
        try {
          for (final result in results) {
            final deviceId = result.device.remoteId.toString();
            
            if (!_discoveredDevices.containsKey(deviceId)) {
              final device = BluetoothDeviceModel.fromScanResult(result);
              
              // Проверяем, является ли устройство сопряженным
              final isBonded = _isDeviceBonded(result.device);
              final deviceWithBondInfo = BluetoothDeviceModel(
                id: device.id,
                name: device.name,
                isConnected: result.device.isConnected,
                rssi: device.rssi,
                serviceUuids: device.serviceUuids,
                deviceType: device.deviceType,
                isClassicBluetooth: false,
                isBonded: isBonded,
                isConnectable: device.isConnectable,
              );
              
              _discoveredDevices[deviceId] = deviceWithBondInfo;
              //print('Найдено устройство: ${deviceWithBondInfo.name} | ${deviceWithBondInfo.deviceType} | RSSI: ${deviceWithBondInfo.rssi}${isBonded ? " (Сопряжено)" : ""}');
              
              // Сразу обновляем UI
              _updateDeviceList();
            } else {
              // Обновляем RSSI для существующего устройства
              final existingDevice = _discoveredDevices[deviceId]!;
              if (existingDevice.rssi != result.rssi) {
                _discoveredDevices[deviceId] = BluetoothDeviceModel(
                  id: existingDevice.id,
                  name: existingDevice.name,
                  isConnected: existingDevice.isConnected,
                  rssi: result.rssi,
                  serviceUuids: existingDevice.serviceUuids,
                  deviceType: existingDevice.deviceType,
                  isClassicBluetooth: existingDevice.isClassicBluetooth,
                  isBonded: existingDevice.isBonded,
                  isConnectable: existingDevice.isConnectable,
                );
                _updateDeviceList();
              }
            }
          }
        } catch (e) {
          _addLog(LogLevel.error, 'Ошибка обработки результатов сканирования: $e');
        }
      });

    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка начала сканирования: $e');
    }
  }

  Future<void> _loadConnectedDevices() async {
    try {
      final connectedDevices = FlutterBluePlus.connectedDevices;
      for (final device in connectedDevices) {
        final deviceId = device.remoteId.toString();
        final deviceModel = BluetoothDeviceModel(
          id: deviceId,
          name: device.platformName.isNotEmpty ? device.platformName : 'Подключенное устройство',
          isConnected: true,
          rssi: 0,
          serviceUuids: [],
          deviceType: 'Подключенное устройство',
          isClassicBluetooth: false,
          isBonded: true, // Подключенные устройства считаем сопряженными
          isConnectable: true, // Подключенные устройства всегда подключаемы
        );
        
        _discoveredDevices[deviceId] = deviceModel;
        _connectedDevices[deviceId] = device;
      }
      
      if (connectedDevices.isNotEmpty) {
        _addLog(LogLevel.info, 'Найдено ${connectedDevices.length} подключенных устройств');
        _updateDeviceList();
      }
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка загрузки подключенных устройств: $e');
    }
  }

  bool _isDeviceBonded(BluetoothDevice device) {
    // Простая проверка - если устройство уже подключено, считаем его сопряженным
    return device.isConnected || _connectedDevices.containsKey(device.remoteId.toString());
  }

  void _updateDeviceList() {
    final devicesList = _discoveredDevices.values.toList();
    
    // Сортируем: сначала подключенные, потом сопряженные, потом по RSSI
    devicesList.sort((a, b) {
      if (a.isConnected && !b.isConnected) return -1;
      if (!a.isConnected && b.isConnected) return 1;
      
      if (a.isBonded && !b.isBonded) return -1;
      if (!a.isBonded && b.isBonded) return 1;
      
      return b.rssi.compareTo(a.rssi);
    });
    
    _devicesController.add(devicesList);
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;

      final totalDevices = _discoveredDevices.length;
      _addLog(LogLevel.info, 'Сканирование завершено. Найдено устройств: $totalDevices');

      if (totalDevices > 0) {
        _addLog(LogLevel.info, '=== Список найденных устройств ===');
        for (final device in _discoveredDevices.values) {
          final status = device.isConnected ? 'Подключено' : 
                        device.isBonded ? 'Сопряжено' : 'Новое';
          _addLog(LogLevel.info, '• ${device.name} (${device.deviceType}) - $status - RSSI: ${device.rssi} dBm');
        }
        _addLog(LogLevel.info, '================================');
      }
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка остановки сканирования: $e');
    }
  }

  @override
  Future<bool> connectToDevice(String deviceId) async {
    try {
      final deviceInfo = _discoveredDevices[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';

      _addLog(LogLevel.info, 'Попытка подключения к "$deviceName"');

      // Останавливаем сканирование
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 500));

      final device = BluetoothDevice.fromId(deviceId);

      if (device.isConnected) {
        _addLog(LogLevel.info, 'Устройство "$deviceName" уже подключено');
        return true;
      }

      // Подключаемся
      await device.connect(
        timeout: const Duration(seconds: 30),
        autoConnect: false,
      );

      await Future.delayed(const Duration(milliseconds: 1000));

      if (device.isConnected) {
        _addLog(LogLevel.info, '✅ Успешно подключено к "$deviceName"');
        
        _connectedDevices[deviceId] = device;
        
        // Обновляем статус устройства в списке
        if (_discoveredDevices.containsKey(deviceId)) {
          final existingDevice = _discoveredDevices[deviceId]!;
          _discoveredDevices[deviceId] = BluetoothDeviceModel(
            id: existingDevice.id,
            name: existingDevice.name,
            isConnected: true,
            rssi: existingDevice.rssi,
            serviceUuids: existingDevice.serviceUuids,
            deviceType: existingDevice.deviceType,
            isClassicBluetooth: existingDevice.isClassicBluetooth,
            isBonded: true,
            isConnectable: existingDevice.isConnectable,
          );
          _updateDeviceList();
        }

        // Слушаем отключения
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _addLog(LogLevel.warning, '❌ Устройство "$deviceName" отключено');
            _connectedDevices.remove(deviceId);
            
            // Обновляем статус в списке
            if (_discoveredDevices.containsKey(deviceId)) {
              final existingDevice = _discoveredDevices[deviceId]!;
              _discoveredDevices[deviceId] = BluetoothDeviceModel(
                id: existingDevice.id,
                name: existingDevice.name,
                isConnected: false,
                rssi: existingDevice.rssi,
                serviceUuids: existingDevice.serviceUuids,
                deviceType: existingDevice.deviceType,
                isClassicBluetooth: existingDevice.isClassicBluetooth,
                isBonded: existingDevice.isBonded,
                isConnectable: existingDevice.isConnectable,
              );
              _updateDeviceList();
            }
          }
        });

        // Начинаем получение данных
        _startDataCollection(device, deviceName);
        
        return true;
      } else {
        _addLog(LogLevel.error, '❌ Не удалось подключиться к "$deviceName"');
        return false;
      }

    } catch (e) {
      final deviceInfo = _discoveredDevices[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';

      String errorMessage = e.toString();
      if (errorMessage.contains('133')) {
        errorMessage = 'Ошибка подключения (код 133). Попробуйте еще раз или перезапустите Bluetooth.';
      }

      _addLog(LogLevel.error, '❌ Ошибка подключения к "$deviceName": $errorMessage');
      return false;
    }
  }

  Future<void> _startDataCollection(BluetoothDevice device, String deviceName) async {
    try {
      _addLog(LogLevel.info, '📡 Начинаем получение данных с "$deviceName"');

      final services = await device.discoverServices();
      _addLog(LogLevel.info, '🔍 Найдено ${services.length} сервисов на "$deviceName"');

      // Логируем информацию о сервисах через AppLogger
      final servicesInfo = services.map((service) => {
        'uuid': service.uuid.toString(),
        'characteristics': service.characteristics.map((char) => {
          'uuid': char.uuid.toString(),
          'properties': char.properties.toString(),
        }).toList(),
      }).toList();

      await _appLogger.logDeviceServices(
        deviceName,
        device.remoteId.toString(),
        servicesInfo,
      );

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          try {
            if (characteristic.properties.read) {
              final value = await characteristic.read();
              _addLog(LogLevel.info, '📊 Данные от "$deviceName": ${value.length} байт');
              
              // Логируем данные через AppLogger
              final hexData = value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
              await _appLogger.logDataReceived(
                deviceName,
                device.remoteId.toString(),
                {
                  'characteristicUuid': characteristic.uuid.toString(),
                  'serviceUuid': service.uuid.toString(),
                  'hexData': hexData,
                  'dataSize': value.length,
                  'rawData': value,
                  'data': String.fromCharCodes(value.where((b) => b >= 32 && b <= 126)),
                },
              );
            }

            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) async {
                _addLog(LogLevel.info, '📨 Уведомление от "$deviceName": ${value.length} байт');
                
                // Логируем уведомления через AppLogger
                final hexData = value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
                await _appLogger.logDataReceived(
                  deviceName,
                  device.remoteId.toString(),
                  {
                    'characteristicUuid': characteristic.uuid.toString(),
                    'serviceUuid': service.uuid.toString(),
                    'hexData': hexData,
                    'dataSize': value.length,
                    'rawData': value,
                    'data': String.fromCharCodes(value.where((b) => b >= 32 && b <= 126)),
                    'type': 'notification',
                  },
                );
              });
              _addLog(LogLevel.info, '🔔 Подписались на уведомления от "$deviceName"');
            }
          } catch (e) {
            // Игнорируем ошибки чтения отдельных характеристик
            await _appLogger.logError('Ошибка чтения характеристики ${characteristic.uuid}: $e', 
                context: 'DataCollection', 
                deviceId: device.remoteId.toString(), 
                deviceName: deviceName);
          }
        }
      }
    } catch (e) {
      _addLog(LogLevel.error, '❌ Ошибка сбора данных с "$deviceName": $e');
      await _appLogger.logError('Ошибка сбора данных: $e', 
          context: 'DataCollection', 
          deviceId: device.remoteId.toString(), 
          deviceName: deviceName);
    }
  }

  @override
  Future<void> disconnectFromDevice(String deviceId) async {
    try {
      final deviceInfo = _discoveredDevices[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';

      final device = BluetoothDevice.fromId(deviceId);

      if (device.isConnected) {
        _addLog(LogLevel.info, '🔌 Отключение от "$deviceName"...');
        await device.disconnect();
        _addLog(LogLevel.info, '✅ Успешно отключено от "$deviceName"');
      }

      _connectedDevices.remove(deviceId);
    } catch (e) {
      _addLog(LogLevel.error, '❌ Ошибка отключения: $e');
    }
  }

  @override
  Future<void> clearLogs() async {
    _logs.clear();
    _addLog(LogLevel.info, 'Логи очищены');
  }

  @override
  Future<List<BluetoothLogEntity>> getLogs() async {
    return List<BluetoothLogEntity>.from(_logs);
  }

  void _addLog(LogLevel level, String message) {
    final log = BluetoothLogEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      level: level,
      message: message,
      timestamp: DateTime.now(),
    );
    _logs.add(log);
    _logsController.add(log);
  }
}
