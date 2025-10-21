import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/entities/bluetooth_log_entity.dart';
import '../models/bluetooth_device_model.dart';
import '../models/bluetooth_log_model.dart';
import '../../../../core/utils/permission_helper.dart';

abstract class BluetoothLocalDataSource {
  Stream<List<BluetoothDeviceEntity>> get discoveredDevices;
  Stream<BluetoothLogEntity> get logs;
  Stream<bool> get isScanning;
  Stream<bool> get isBluetoothEnabled;
  
  Future<bool> isBluetoothAvailable();
  Future<bool> requestPermissions();
  Future<void> startScan();
  Future<void> stopScan();
  Future<bool> connectToDevice(String deviceId);
  Future<bool> reconnectToDevice(String deviceId);
  Future<void> disconnectFromDevice(String deviceId);
  Future<void> clearLogs();
  Future<List<BluetoothLogEntity>> getLogs();
}

class BluetoothLocalDataSourceImpl implements BluetoothLocalDataSource {
  final StreamController<List<BluetoothDeviceEntity>> _devicesController = 
      StreamController<List<BluetoothDeviceEntity>>.broadcast();
  final StreamController<BluetoothLogEntity> _logsController = 
      StreamController<BluetoothLogEntity>.broadcast();
  final StreamController<bool> _isScanningController = 
      StreamController<bool>.broadcast();
  final StreamController<bool> _isBluetoothEnabledController = 
      StreamController<bool>.broadcast();
  
  final List<BluetoothLogEntity> _logs = [];
  final Map<String, BluetoothDevice> _connectedDevices = {};
  
  // Карта для дедупликации устройств по MAC-адресу
  final Map<String, BluetoothDeviceEntity> _discoveredDevicesMap = {};
  
  // Дедупликация логов
  String? _lastLogMessage;
  DateTime? _lastLogTime;
  int _duplicateLogCount = 0;
  static const Duration _logDeduplicationWindow = Duration(seconds: 5);
  
  // Улучшенное определение устройств
  final Map<String, String> _deviceNameCache = {};
  
  BluetoothLocalDataSourceImpl() {
    // Инициализация будет выполнена при первом обращении
  }

  bool _isInitialized = false;
  StreamSubscription? _scanResultsSubscription;

  void _initializeBluetooth() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    // Слушаем изменения состояния Bluetooth
    FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothEnabledController.add(state == BluetoothAdapterState.on);
    });
    
    // Слушаем изменения состояния сканирования
    FlutterBluePlus.isScanning.listen((scanning) {
      _isScanningController.add(scanning);
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
      
      // Проверяем состояние адаптера
      final state = await FlutterBluePlus.adapterState.first;
      _addLog(LogLevel.info, 'Состояние Bluetooth адаптера: $state');
      
      if (state == BluetoothAdapterState.on) {
        return true;
      } else if (state == BluetoothAdapterState.off) {
        _addLog(LogLevel.warning, 'Bluetooth выключен. Включите Bluetooth в настройках устройства.');
        return false;
      } else if (state == BluetoothAdapterState.turningOn) {
        _addLog(LogLevel.info, 'Bluetooth включается...');
        // Ждем пока включится
        await Future.delayed(const Duration(seconds: 2));
        final newState = await FlutterBluePlus.adapterState.first;
        return newState == BluetoothAdapterState.on;
      } else if (state == BluetoothAdapterState.turningOff) {
        _addLog(LogLevel.warning, 'Bluetooth выключается...');
        return false;
      } else {
        _addLog(LogLevel.warning, 'Неизвестное состояние Bluetooth: $state');
        return false;
      }
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка проверки доступности Bluetooth: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      _addLog(LogLevel.info, '🔐 Запрос разрешений Bluetooth...');
      
      // Проверяем текущий статус разрешений
      final currentStatuses = await PermissionHelper.getAllPermissionStatuses();
      
      _addLog(LogLevel.info, '📋 Текущий статус разрешений:');
      for (final entry in currentStatuses.entries) {
        final permissionName = PermissionHelper.getPermissionDisplayName(entry.key);
        final statusText = PermissionHelper.getPermissionStatusText(entry.value);
        _addLog(LogLevel.info, '   • $permissionName: $statusText');
      }
      
      // Запрашиваем основные разрешения
      _addLog(LogLevel.info, '📝 Запрашиваем основные разрешения...');
      final results = await PermissionHelper.requestRequiredPermissions();
      
      // Проверяем результат запроса
      final mainGranted = results.values.every((status) => status.isGranted);
      
      if (mainGranted) {
        _addLog(LogLevel.info, '✅ Все основные разрешения Bluetooth получены');
        
        // Запрашиваем дополнительные разрешения (не критичные)
        try {
          _addLog(LogLevel.info, '📝 Запрашиваем дополнительные разрешения...');
          final optionalResults = await PermissionHelper.requestOptionalPermissions();
          
          _addLog(LogLevel.info, '📋 Дополнительные разрешения:');
          for (final entry in optionalResults.entries) {
            final permissionName = PermissionHelper.getPermissionDisplayName(entry.key);
            final statusText = PermissionHelper.getPermissionStatusText(entry.value);
            _addLog(LogLevel.info, '   • $permissionName: $statusText');
          }
        } catch (e) {
          _addLog(LogLevel.warning, '⚠️ Ошибка запроса дополнительных разрешений: $e');
        }
        
        return true;
      } else {
        // Анализируем какие разрешения не получены
        final deniedPermissions = <String>[];
        final permanentlyDeniedPermissions = <String>[];
        
        for (final entry in results.entries) {
          final permissionName = PermissionHelper.getPermissionDisplayName(entry.key);
          final status = entry.value;
          
          if (status.isDenied) {
            deniedPermissions.add(permissionName);
          } else if (status.isPermanentlyDenied) {
            permanentlyDeniedPermissions.add(permissionName);
          }
        }
        
        if (deniedPermissions.isNotEmpty) {
          _addLog(LogLevel.warning, '❌ Отклонены разрешения: ${deniedPermissions.join(', ')}');
          _addLog(LogLevel.info, '💡 Попробуйте разрешить эти разрешения в настройках приложения');
        }
        
        if (permanentlyDeniedPermissions.isNotEmpty) {
          _addLog(LogLevel.error, '🚫 Окончательно отклонены разрешения: ${permanentlyDeniedPermissions.join(', ')}');
          _addLog(LogLevel.info, '💡 Перейдите в настройки приложения и разрешите эти разрешения вручную');
        }
        
        return false;
      }
    } catch (e) {
      _addLog(LogLevel.error, '❌ Ошибка запроса разрешений: $e');
      return false;
    }
  }

  @override
  Future<void> startScan() async {
    try {
      _initializeBluetooth();
      _addLog(LogLevel.info, '🔍 Начинаем поиск Bluetooth устройств...');
      
      // Проверяем доступность Bluetooth перед сканированием
      final isAvailable = await isBluetoothAvailable();
      if (!isAvailable) {
        _addLog(LogLevel.error, '❌ Bluetooth недоступен. Включите Bluetooth в настройках устройства.');
        return;
      }
      
      // Проверяем разрешения
      _addLog(LogLevel.info, '🔐 Проверяем разрешения...');
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        _addLog(LogLevel.error, '❌ Недостаточно разрешений для сканирования');
        _addLog(LogLevel.info, '💡 Перейдите в настройки приложения и разрешите все необходимые разрешения');
        return;
      }
      
      // Очищаем карты найденных устройств для нового сканирования
      _clearDiscoveredDevices();
      _deviceNameCache.clear();
      
      // Запускаем BLE сканирование
      await _startBLEScan();
      
    } catch (e) {
      _addLog(LogLevel.error, '❌ Ошибка начала сканирования: $e');
    }
  }

  Future<void> _startBLEScan() async {
    try {
      _addLog(LogLevel.info, '🔍 Запуск улучшенного BLE сканирования...');
      
      // Логируем уже подключенные BLE устройства
      try {
        final connectedDevices = FlutterBluePlus.connectedDevices;
        if (connectedDevices.isNotEmpty) {
          _addLog(LogLevel.info, 'Найдено ${connectedDevices.length} уже подключенных BLE устройств');
          for (final device in connectedDevices) {
            _addLog(LogLevel.info, 'Подключенное BLE устройство: "${device.platformName}" (${device.remoteId})');
          }
        }
      } catch (e) {
        _addLog(LogLevel.warning, 'Ошибка получения подключенных BLE устройств: $e');
      }
      
      // Отменяем предыдущую подписку если есть
      await _scanResultsSubscription?.cancel();
      
      // Слушаем найденные BLE устройства в реальном времени
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        try {
          
          // Обрабатываем каждый BLE результат
          for (final result in results) {
            final deviceId = result.device.remoteId.toString();
            
            // Создаем новое устройство из результата сканирования
            final newDevice = BluetoothDeviceModel.fromScanResult(result);
            
            // Улучшаем имя устройства
            final improvedDevice = _improveDeviceName(newDevice, result);
            
            if (!_discoveredDevicesMap.containsKey(deviceId)) {
              // Новое BLE устройство - сразу добавляем и обновляем список
              _discoveredDevicesMap[deviceId] = improvedDevice;
              
              // Логируем подробную информацию о найденном устройстве
              _addLog(LogLevel.info, '🔍 Найдено новое устройство: ${improvedDevice.name}',
                deviceId: deviceId,
                deviceName: improvedDevice.name,
                additionalData: {
                  'scan_result_analysis': {
                    'device_id': deviceId,
                    'device_name': improvedDevice.name,
                    'device_type': improvedDevice.deviceType,
                    'rssi': improvedDevice.rssi,
                    'service_count': result.advertisementData.serviceUuids.length,
                    'service_uuids': result.advertisementData.serviceUuids.map((u) => u.toString()).toList(),
                    'manufacturer_data': result.advertisementData.manufacturerData.map((key, value) => 
                      MapEntry(key.toString(), {
                        'company_id': key,
                        'data_length': value.length,
                        'raw_data_hex': value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
                        'raw_data_bytes': value,
                      })),
                    'tx_power_level': result.advertisementData.txPowerLevel,
                    'local_name': result.advertisementData.localName,
                    'platform_name': result.device.platformName,
                    'advertisement_data': {
                      'manufacturer_data_keys': result.advertisementData.manufacturerData.keys.map((k) => k.toString()).toList(),
                      'service_data': result.advertisementData.serviceData.map((key, value) => 
                        MapEntry(key.toString(), {
                          'service_uuid': key.toString(),
                          'data_length': value.length,
                          'raw_data_hex': value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
                          'raw_data_bytes': value,
                        })),
                    },
                  }
                });
              
              print('Найдено устройство: ${improvedDevice.name} | ${improvedDevice.deviceType} | RSSI: ${improvedDevice.rssi}');
              _updateDeviceList(); // Сразу обновляем UI
            } else {
              // Обновляем существующее BLE устройство
              final existingDevice = _discoveredDevicesMap[deviceId]!;
              bool shouldUpdate = false;
              String updateReason = '';
              
              // Проверяем изменение RSSI (более чем на 3 dBm для быстрого обновления)
              if ((improvedDevice.rssi - existingDevice.rssi).abs() > 3) {
                shouldUpdate = true;
                updateReason += 'RSSI: ${existingDevice.rssi} → ${improvedDevice.rssi}; ';
              }
              
              // Проверяем улучшение имени устройства
              if (_isBetterDeviceName(improvedDevice.name, existingDevice.name)) {
                shouldUpdate = true;
                updateReason += 'Имя: "${existingDevice.name}" → "${improvedDevice.name}"; ';
              }
              
              // Проверяем изменение количества сервисов
              if (improvedDevice.serviceUuids.length != existingDevice.serviceUuids.length) {
                shouldUpdate = true;
                updateReason += 'Сервисы: ${existingDevice.serviceUuids.length} → ${improvedDevice.serviceUuids.length}; ';
              }
              
              if (shouldUpdate) {
                _discoveredDevicesMap[deviceId] = improvedDevice;
                if (updateReason.contains('имя') || updateReason.contains('сервис')) {
                  _addLog(LogLevel.debug, 'Обновлено BLE устройство $deviceId: $updateReason');
                }
                _updateDeviceList(); // Сразу обновляем UI при изменениях
              }
            }
          }
        } catch (e) {
          _addLog(LogLevel.error, 'Ошибка обработки BLE результатов сканирования: $e');
        }
      });
      
      // Начинаем BLE сканирование с улучшенными параметрами для реального времени
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        continuousUpdates: true,
        continuousDivisor: 1,
        androidUsesFineLocation: true,
      );
      
      _addLog(LogLevel.info, 'BLE сканирование запущено в режиме реального времени');
      
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка BLE сканирования: $e');
    }
  }

  BluetoothDeviceEntity _improveDeviceName(BluetoothDeviceEntity device, ScanResult result) {
    // Проверяем кэш имен
    final deviceId = device.id;
    if (_deviceNameCache.containsKey(deviceId)) {
      final cachedName = _deviceNameCache[deviceId]!;
      if (cachedName != device.name && _isBetterDeviceName(cachedName, device.name)) {
        return BluetoothDeviceEntity(
          id: device.id,
          name: cachedName,
          isConnected: device.isConnected,
          rssi: device.rssi,
          serviceUuids: device.serviceUuids,
          deviceType: device.deviceType,
          isClassicBluetooth: device.isClassicBluetooth,
          isBonded: device.isBonded,
        );
      }
    }
    
    // Пытаемся получить лучшее имя из разных источников
    String bestName = device.name;
    
    // 1. Проверяем platformName (самый надежный источник)
    if (result.device.platformName.isNotEmpty && 
        result.device.platformName != 'Unknown' && 
        result.device.platformName != 'unknown' &&
        _isValidDeviceName(result.device.platformName) &&
        _isBetterDeviceName(result.device.platformName, bestName)) {
      bestName = result.device.platformName;
    }
    
    // 2. Проверяем localName
    if (result.advertisementData.localName.isNotEmpty && 
        result.advertisementData.localName != 'Unknown' && 
        result.advertisementData.localName != 'unknown' &&
        _isValidDeviceName(result.advertisementData.localName) &&
        _isBetterDeviceName(result.advertisementData.localName, bestName)) {
      bestName = result.advertisementData.localName;
    }
    
    // 3. Проверяем advName
    try {
      if (result.advertisementData.advName.isNotEmpty && 
          result.advertisementData.advName != 'Unknown' && 
          result.advertisementData.advName != 'unknown' &&
          _isValidDeviceName(result.advertisementData.advName) &&
          _isBetterDeviceName(result.advertisementData.advName, bestName)) {
        bestName = result.advertisementData.advName;
      }
    } catch (e) {
      // advName может быть недоступен
    }
    
    // 4. Если имя все еще плохое, пытаемся создать описательное имя
    if (!_isValidDeviceName(bestName) || bestName.contains('устройство') || bestName.contains('device')) {
      bestName = _generateDescriptiveName(device, result);
    }
    
    // Кэшируем лучшее имя
    if (bestName != device.name) {
      _deviceNameCache[deviceId] = bestName;
    }
    
    // Возвращаем улучшенное устройство с обновленным типом
    return BluetoothDeviceEntity(
      id: device.id,
      name: bestName,
      isConnected: device.isConnected,
      rssi: device.rssi,
      serviceUuids: device.serviceUuids,
      deviceType: _getImprovedDeviceType(bestName, device.serviceUuids),
      isClassicBluetooth: device.isClassicBluetooth,
      isBonded: device.isBonded,
    );
  }

  bool _isValidDeviceName(String name) {
    if (name.trim().isEmpty || name.length < 2) return false;
    if (name.toLowerCase().contains('unknown')) return false;
    if (name.toLowerCase().contains('bluetooth')) return false;
    if (name.toLowerCase().contains('device')) return false;
    if (name.length > 50) return false; // Слишком длинное имя
    
    // Проверяем на искаженные символы - более строгая проверка
    final validChars = name.codeUnits.where((code) => 
        (code >= 32 && code <= 126) || // ASCII печатные символы
        (code >= 1040 && code <= 1103) || // Кириллица
        code == 1025 || code == 1105 || // Ё и ё
        code == 32 || code == 45 || code == 95 // пробел, дефис, подчеркивание
    ).length;
    
    // Если меньше 80% символов валидные, отбрасываем
    if (validChars < name.length * 0.8) return false;
    
    // Проверяем на слишком много специальных символов
    final specialChars = name.codeUnits.where((code) => 
        code < 32 || (code > 126 && code < 1040) || code > 1103).length;
    if (specialChars > name.length * 0.2) return false;
    
    return true;
  }

  String _generateDescriptiveName(BluetoothDeviceEntity device, ScanResult result) {
    // Определяем тип по сервисам
    String deviceTypeHint = 'Устройство';
    
    if (device.serviceUuids.any((uuid) => uuid.toLowerCase().contains('110b') ||
                                         uuid.toLowerCase().contains('110e'))) {
      deviceTypeHint = 'Аудио';
    } else if (device.serviceUuids.any((uuid) => uuid.toLowerCase().contains('180d'))) {
      deviceTypeHint = 'Фитнес';
    } else if (device.serviceUuids.any((uuid) => uuid.toLowerCase().contains('1812'))) {
      deviceTypeHint = 'Ввод';
    } else if (device.serviceUuids.any((uuid) => uuid.toLowerCase().contains('180f'))) {
      deviceTypeHint = 'Батарея';
    } else if (device.serviceUuids.any((uuid) => uuid.toLowerCase().contains('180a'))) {
      deviceTypeHint = 'Устройство';
    }
    
    // Берем последние 4 символа MAC-адреса для создания уникального имени
    final deviceId = device.id;
    final shortId = deviceId.length > 4 ? deviceId.substring(deviceId.length - 4) : deviceId;
    
    return '$deviceTypeHint $shortId';
  }

  String _getImprovedDeviceType(String deviceName, List<String> serviceUuids) {
    final name = deviceName.toLowerCase();
    
    // 1. Сначала проверяем UUID сервисов (самый надежный способ)
    final typeByServices = _getDeviceTypeByServices(serviceUuids);
    if (typeByServices != 'Неизвестное устройство') {
      return typeByServices;
    }
    
    // 2. Затем проверяем конкретные паттерны имен
    if (_isPhone(name)) return 'Телефон';
    if (_isAudioDevice(name)) return 'Аудио устройство';
    if (_isComputer(name)) return 'Компьютер';
    if (_isGamingDevice(name)) return 'Игровое устройство';
    if (_isCar(name)) return 'Автомобиль';
    if (_isWearableDevice(name)) return 'Носимые устройства';
    
    // 3. Проверяем по типу устройства (если доступно)
    if (name.contains('аудио')) return 'Аудио устройство';
    if (name.contains('фитнес')) return 'Фитнес устройство';
    if (name.contains('ввод')) return 'Устройство ввода';
    if (name.contains('батарея')) return 'Устройство с батареей';
    
    return 'Bluetooth устройство';
  }

  String _getDeviceTypeByServices(List<String> serviceUuids) {
    final uuidStrings = serviceUuids.map((uuid) => uuid.toLowerCase()).toList();
    
    // Аудио устройства
    if (uuidStrings.any((uuid) => 
        uuid.contains('110b') || // Audio Source
        uuid.contains('110e') || // Audio Sink
        uuid.contains('110a')    // Advanced Audio Distribution
    )) {
      return 'Аудио устройство';
    }
    
    // Фитнес устройства
    if (uuidStrings.any((uuid) => 
        uuid.contains('180d') || // Heart Rate
        uuid.contains('1814') || // Environmental Sensing
        uuid.contains('181c')    // User Data
    )) {
      return 'Фитнес устройство';
    }
    
    // Устройства ввода
    if (uuidStrings.any((uuid) => 
        uuid.contains('1812') || // Human Interface Device
        uuid.contains('1124')    // HID over GATT
    )) {
      return 'Устройство ввода';
    }
    
    // Устройства с батареей
    if (uuidStrings.any((uuid) => 
        uuid.contains('180f')    // Battery Service
    )) {
      return 'Устройство с батареей';
    }
    
    return 'Bluetooth устройство';
  }

  void _updateDeviceList() {
    final devicesList = _discoveredDevicesMap.values.toList();
    
    // Сортируем устройства
    devicesList.sort((a, b) {
      // Подключенные устройства всегда первые
      if (a.isConnected && !b.isConnected) return -1;
      if (!a.isConnected && b.isConnected) return 1;
      
      // Затем по силе сигнала (больше RSSI = ближе)
      return b.rssi.compareTo(a.rssi);
    });
    
    _devicesController.add(devicesList);
  }

  // Вспомогательные методы для определения типов устройств
  bool _isPhone(String name) {
    final phonePatterns = [
      'iphone', 'samsung', 'galaxy', 'note', 'pixel', 'xiaomi', 'huawei', 'oneplus',
      'oppo', 'vivo', 'realme', 'motorola', 'lg', 'sony', 'nokia', 'htc',
      'phone', 'mobile', 'smartphone', 'android', 'ios'
    ];
    return phonePatterns.any((pattern) => name.contains(pattern));
  }

  bool _isAudioDevice(String name) {
    final audioPatterns = [
      'jbl', 'bose', 'sony', 'sennheiser', 'audio', 'speaker', 'headphone', 'headset',
      'earphone', 'earbud', 'airpods', 'beats', 'harman', 'marshall', 'jabra',
      'sound', 'music', 'bluetooth', 'wireless', 'колонка', 'наушники'
    ];
    return audioPatterns.any((pattern) => name.contains(pattern));
  }

  bool _isComputer(String name) {
    final computerPatterns = [
      'macbook', 'mac', 'laptop', 'notebook', 'pc', 'computer', 'desktop',
      'windows', 'linux', 'ubuntu', 'thinkpad', 'dell', 'hp', 'lenovo',
      'asus', 'acer', 'msi', 'gigabyte', 'компьютер', 'ноутбук'
    ];
    return computerPatterns.any((pattern) => name.contains(pattern));
  }

  bool _isGamingDevice(String name) {
    final gamingPatterns = [
      'xbox', 'playstation', 'ps4', 'ps5', 'nintendo', 'switch', 'steam',
      'gaming', 'game', 'controller', 'joystick', 'pad', 'игра', 'геймпад'
    ];
    return gamingPatterns.any((pattern) => name.contains(pattern));
  }

  bool _isCar(String name) {
    final carPatterns = [
      'car', 'auto', 'vehicle', 'bmw', 'mercedes', 'audi', 'toyota', 'honda',
      'ford', 'chevrolet', 'nissan', 'hyundai', 'kia', 'volkswagen', 'skoda',
      'авто', 'машина', 'автомобиль'
    ];
    return carPatterns.any((pattern) => name.contains(pattern));
  }

  bool _isWearableDevice(String name) {
    final wearablePatterns = [
      'watch', 'band', 'fitness', 'tracker', 'mi band', 'apple watch', 'galaxy watch',
      'fitbit', 'garmin', 'huawei band', 'amazfit', 'wear', 'smartwatch',
      'браслет', 'часы', 'фитнес', 'трекер'
    ];
    return wearablePatterns.any((pattern) => name.contains(pattern));
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
      // Записываем итоговый результат сканирования
      final totalDevices = _discoveredDevicesMap.length;
      _addLog(LogLevel.info, 'Сканирование завершено. Найдено устройств: $totalDevices');
      
      // Выводим список найденных устройств
      if (totalDevices > 0) {
        _addLog(LogLevel.info, '=== Список найденных устройств ===');
        
        // BLE устройства
        for (final device in _discoveredDevicesMap.values) {
          _addLog(LogLevel.info, '• ${device.name} (${device.deviceType}) - RSSI: ${device.rssi} dBm');
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
      // Получаем информацию об устройстве для логов
      final deviceInfo = _discoveredDevicesMap[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';
      
      _addLog(LogLevel.info, 'Попытка подключения к "$deviceName"');
      
      // Останавливаем сканирование перед подключением
      await FlutterBluePlus.stopScan();
      
      // Ждем немного после остановки сканирования
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Создаем BluetoothDevice из ID
      final device = BluetoothDevice.fromId(deviceId);
      
      // Проверяем, не подключено ли уже
      if (device.isConnected) {
        _addLog(LogLevel.info, 'Устройство "$deviceName" уже подключено');
        return true;
      }
      
      // Подключаемся с увеличенным таймаутом и без autoConnect
      await device.connect(
        timeout: const Duration(seconds: 30),
        autoConnect: false,
      );
      
      // Ждем установления соединения
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (device.isConnected) {
        _addLog(LogLevel.info, '✅ Успешно подключено к "$deviceName"');
        
        // Сохраняем подключенное устройство
        _connectedDevices[deviceId] = device;
        
        // Слушаем состояние подключения
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _addLog(LogLevel.warning, '❌ Устройство "$deviceName" отключено');
            _connectedDevices.remove(deviceId);
          }
        });
        
        // Начинаем получение данных с устройства
        _startDataCollection(device, deviceName);
        
        return true;
      } else {
        _addLog(LogLevel.error, '❌ Не удалось подключиться к "$deviceName"');
        return false;
      }
      
    } catch (e) {
      final deviceInfo = _discoveredDevicesMap[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';
      
      // Обрабатываем специфичные ошибки Android
      String errorMessage = e.toString();
      if (errorMessage.contains('133')) {
        errorMessage = 'Ошибка подключения (код 133). Попробуйте еще раз или перезапустите Bluetooth.';
      } else if (errorMessage.contains('connection timeout')) {
        errorMessage = 'Таймаут подключения. Устройство может быть недоступно.';
      }
      
      _addLog(LogLevel.error, '❌ Ошибка подключения к "$deviceName": $errorMessage');
      return false;
    }
  }

  /// Начинает сбор данных с подключенного устройства
  Future<void> _startDataCollection(BluetoothDevice device, String deviceName) async {
    try {
      _addLog(LogLevel.info, '📡 Начинаем получение данных с "$deviceName"');
      
      // Обнаруживаем сервисы
      final services = await device.discoverServices();
      _addLog(LogLevel.info, '🔍 Найдено ${services.length} сервисов на "$deviceName"', 
        additionalData: {
          'device_id': device.remoteId.toString(),
          'device_name': deviceName,
          'service_count': services.length,
          'service_uuids': services.map((s) => s.uuid.toString()).toList(),
        });
      
      for (var service in services) {
        _addLog(LogLevel.debug, '🔍 Сервис: ${service.uuid}', 
          additionalData: {
            'service_uuid': service.uuid.toString(),
            'characteristic_count': service.characteristics.length,
            'characteristics': service.characteristics.map((c) => {
              'uuid': c.uuid.toString(),
              'properties': {
                'read': c.properties.read,
                'write': c.properties.write,
                'writeWithoutResponse': c.properties.writeWithoutResponse,
                'notify': c.properties.notify,
                'indicate': c.properties.indicate,
                'authenticatedSignedWrites': c.properties.authenticatedSignedWrites,
                'extendedProperties': c.properties.extendedProperties,
              }
            }).toList(),
          });
        
        for (var characteristic in service.characteristics) {
          try {
            // Собираем информацию о характеристике
            final charInfo = {
              'characteristic_uuid': characteristic.uuid.toString(),
              'service_uuid': service.uuid.toString(),
              'properties': {
                'read': characteristic.properties.read,
                'write': characteristic.properties.write,
                'writeWithoutResponse': characteristic.properties.writeWithoutResponse,
                'notify': characteristic.properties.notify,
                'indicate': characteristic.properties.indicate,
              },
            };
            
            // Читаем характеристики, которые поддерживают чтение
            if (characteristic.properties.read) {
              try {
                final value = await characteristic.read();
                _addLog(LogLevel.info, '📊 Чтение характеристики "${characteristic.uuid}": ${value.length} байт', 
                  additionalData: {
                    ...charInfo,
                    'operation': 'read',
                    'data_length': value.length,
                    'raw_data_hex': value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
                    'raw_data_decimal': value.join(' '),
                    'raw_data_bytes': value,
                    'read_success': true,
                  });
                
                // Попытка декодирования
                try {
                  final decoded = String.fromCharCodes(value.where((b) => b >= 32 && b <= 126));
                  if (decoded.isNotEmpty) {
                    _addLog(LogLevel.debug, '🔤 Декодированные данные: "$decoded"', 
                      additionalData: {
                        ...charInfo,
                        'operation': 'decode',
                        'decoded_string': decoded,
                      });
                  }
                } catch (e) {
                  // Игнорируем ошибки декодирования
                }
              } catch (e) {
                _addLog(LogLevel.warning, '⚠️ Ошибка чтения характеристики ${characteristic.uuid}: $e',
                  additionalData: {
                    ...charInfo,
                    'operation': 'read',
                    'error': e.toString(),
                    'read_success': false,
                  });
              }
            }
            
            // Подписываемся на уведомления
            if (characteristic.properties.notify || characteristic.properties.indicate) {
              try {
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  _addLog(LogLevel.info, '📨 Уведомление от "${characteristic.uuid}": ${value.length} байт',
                    additionalData: {
                      ...charInfo,
                      'operation': 'notification_received',
                      'data_length': value.length,
                      'raw_data_hex': value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
                      'raw_data_decimal': value.join(' '),
                      'raw_data_bytes': value,
                      'notification_type': characteristic.properties.notify ? 'notify' : 'indicate',
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                  
                  // Попытка декодирования уведомления
                  try {
                    final decoded = String.fromCharCodes(value.where((b) => b >= 32 && b <= 126));
                    if (decoded.isNotEmpty) {
                      _addLog(LogLevel.debug, '🔔 Декодированное уведомление: "$decoded"',
                        additionalData: {
                          ...charInfo,
                          'operation': 'notification_decode',
                          'decoded_string': decoded,
                        });
                    }
                  } catch (e) {
                    // Игнорируем ошибки декодирования
                  }
                });
                _addLog(LogLevel.info, '🔔 Подписались на уведомления от "${characteristic.uuid}"',
                  additionalData: {
                    ...charInfo,
                    'operation': 'subscribe',
                    'subscription_success': true,
                  });
              } catch (e) {
                _addLog(LogLevel.warning, '⚠️ Ошибка подписки на ${characteristic.uuid}: $e',
                  additionalData: {
                    ...charInfo,
                    'operation': 'subscribe',
                    'error': e.toString(),
                    'subscription_success': false,
                  });
              }
            }
          } catch (e) {
            _addLog(LogLevel.warning, '⚠️ Общая ошибка работы с характеристикой ${characteristic.uuid}: $e',
              additionalData: {
                'characteristic_uuid': characteristic.uuid.toString(),
                'service_uuid': service.uuid.toString(),
                'error': e.toString(),
                'error_type': e.runtimeType.toString(),
              });
          }
        }
      }
    } catch (e) {
      _addLog(LogLevel.error, '❌ Ошибка сбора данных с "$deviceName": $e',
        additionalData: {
          'device_id': device.remoteId.toString(),
          'device_name': deviceName,
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
        });
    }
  }

  @override
  Future<bool> reconnectToDevice(String deviceId) async {
    try {
      _addLog(LogLevel.info, 'Попытка повторного подключения к устройству: $deviceId');
      
      // Сначала отключаемся если подключены
      final device = _connectedDevices[deviceId];
      if (device != null && device.isConnected) {
        await device.disconnect();
        _connectedDevices.remove(deviceId);
        _addLog(LogLevel.info, 'Отключились перед повторным подключением');
        
        // Ждем немного перед повторным подключением
        await Future.delayed(const Duration(seconds: 2));
      }
      
      // Пытаемся подключиться снова
      return await connectToDevice(deviceId);
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка повторного подключения: $e');
      return false;
    }
  }

  @override
  Future<void> disconnectFromDevice(String deviceId) async {
    try {
      // Получаем информацию об устройстве для логов
      final deviceInfo = _discoveredDevicesMap[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';
      
      final device = BluetoothDevice.fromId(deviceId);
      
      if (device.isConnected) {
        _addLog(LogLevel.info, '🔌 Отключение от "$deviceName"...');
        await device.disconnect();
        _addLog(LogLevel.info, '✅ Успешно отключено от "$deviceName"');
      } else {
        _addLog(LogLevel.warning, '⚠️ Устройство "$deviceName" уже отключено');
      }
      
      _connectedDevices.remove(deviceId);
    } catch (e) {
      final deviceInfo = _discoveredDevicesMap[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';
      _addLog(LogLevel.error, '❌ Ошибка отключения от "$deviceName": $e');
    }
  }

  void _addLog(LogLevel level, String message, {String? deviceId, String? deviceName, Map<String, dynamic>? additionalData}) {
    final now = DateTime.now();
    
    // Проверяем дедупликацию
    if (_lastLogMessage == message && _lastLogTime != null) {
      final timeDiff = now.difference(_lastLogTime!);
      
      if (timeDiff <= _logDeduplicationWindow) {
        // Увеличиваем счетчик дубликатов
        _duplicateLogCount++;
        _lastLogTime = now;
        
        // Обновляем последний лог с информацией о количестве повторений
        if (_logs.isNotEmpty) {
          final lastLogIndex = _logs.length - 1;
          final lastLog = _logs[lastLogIndex];
          
          // Создаем обновленный лог с счетчиком
          final updatedMessage = _duplicateLogCount > 1 
            ? message.replaceAll(RegExp(r' \(повторено \d+ раз\)$'), '') + ' (повторено $_duplicateLogCount раз)'
            : message + ' (повторено $_duplicateLogCount раз)';
            
          final updatedLog = BluetoothLogModel.create(
            level: level,
            message: updatedMessage,
            deviceId: deviceId,
            deviceName: deviceName,
            additionalData: additionalData,
            timestamp: lastLog.timestamp, // Сохраняем оригинальное время
          );
          
          _logs[lastLogIndex] = updatedLog;
          _logsController.add(updatedLog);
        }
        return;
      }
    }
    
    // Сбрасываем дедупликацию для нового сообщения
    _lastLogMessage = message;
    _lastLogTime = now;
    _duplicateLogCount = 0;
    
    // Создаем новый лог
    final log = BluetoothLogModel.create(
      level: level,
      message: message,
      deviceId: deviceId,
      deviceName: deviceName,
      additionalData: additionalData,
    );
    
    _logs.add(log);
    _logsController.add(log);
  }

  @override
  Future<void> clearLogs() async {
    _logs.clear();
    
    // Сбрасываем дедупликацию логов
    _lastLogMessage = null;
    _lastLogTime = null;
    _duplicateLogCount = 0;
    
    _addLog(LogLevel.info, 'Логи очищены');
  }

  @override
  Future<List<BluetoothLogEntity>> getLogs() async {
    return List.from(_logs);
  }

  /// Определяет, является ли новое имя устройства лучше существующего
  bool _isBetterDeviceName(String newName, String existingName) {
    // Проверяем валидность имен
    final newNameValid = _isValidDeviceName(newName);
    final existingNameValid = _isValidDeviceName(existingName);
    
    // Если новое имя валидное, а существующее нет, новое лучше
    if (newNameValid && !existingNameValid) return true;
    
    // Если существующее имя валидное, а новое нет, существующее лучше
    if (!newNameValid && existingNameValid) return false;
    
    // Если оба невалидные, выбираем более длинное
    if (!newNameValid && !existingNameValid) {
      return newName.length > existingName.length;
    }
    
    // Если существующее имя содержит "устройство" или "device", новое имя лучше
    if (existingName.toLowerCase().contains('устройство') || 
        existingName.toLowerCase().contains('device') ||
        existingName.toLowerCase().contains('неизвестное')) {
      return true;
    }
    
    // Если новое имя содержит "устройство" или "device", а существующее нет, то существующее лучше
    if (newName.toLowerCase().contains('устройство') || 
        newName.toLowerCase().contains('device') ||
        newName.toLowerCase().contains('неизвестное')) {
      return false;
    }
    
    // Если новое имя длиннее и не содержит "устройство", оно лучше
    if (newName.length > existingName.length && 
        !newName.toLowerCase().contains('устройство')) {
      return true;
    }
    
    // Если существующее имя слишком короткое (менее 3 символов), новое имя лучше
    if (existingName.length < 3) {
      return true;
    }
    
    // Если новое имя содержит известные бренды, оно лучше
    final knownBrands = ['samsung', 'iphone', 'jbl', 'sony', 'bose', 'xiaomi', 'huawei', 'oneplus'];
    final newHasBrand = knownBrands.any((brand) => newName.toLowerCase().contains(brand));
    final existingHasBrand = knownBrands.any((brand) => existingName.toLowerCase().contains(brand));
    
    if (newHasBrand && !existingHasBrand) return true;
    if (!newHasBrand && existingHasBrand) return false;
    
    return false;
  }

  /// Очищает карту найденных устройств (вызывается при новом сканировании)
  void _clearDiscoveredDevices() {
    _discoveredDevicesMap.clear();
    _addLog(LogLevel.info, 'Очищена карта найденных устройств');
  }

  void dispose() {
    _devicesController.close();
    _logsController.close();
    _isScanningController.close();
    _isBluetoothEnabledController.close();
  }
}