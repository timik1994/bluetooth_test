import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
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
  
  // Классический Bluetooth
  StreamSubscription<classic.BluetoothDiscoveryResult>? _classicBluetoothSubscription;
  final Map<String, BluetoothDeviceEntity> _classicDevicesMap = {};
  
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
      
      // Проверяем текущий статус
      final currentStatuses = await PermissionHelper.getAllPermissionStatuses();
      
      _addLog(LogLevel.info, 'Текущий статус разрешений: ${currentStatuses.map((k, v) => MapEntry(PermissionHelper.getPermissionDisplayName(k), PermissionHelper.getPermissionStatusText(v))).toString()}');
      
      // Запрашиваем основные разрешения
      final results = await PermissionHelper.requestRequiredPermissions();
      
      // Обновляем статусы
      for (final entry in results.entries) {
        currentStatuses[entry.key] = entry.value;
      }
      
      // Проверяем основные разрешения
      final mainGranted = results.values.every((status) => status.isGranted);
      
      if (mainGranted) {
        _addLog(LogLevel.info, 'Все основные разрешения Bluetooth получены');
        
        // Запрашиваем дополнительные разрешения
        try {
          final optionalResults = await PermissionHelper.requestOptionalPermissions();
          for (final entry in optionalResults.entries) {
            currentStatuses[entry.key] = entry.value;
          }
          _addLog(LogLevel.info, 'Дополнительные разрешения: ${optionalResults.map((k, v) => MapEntry(PermissionHelper.getPermissionDisplayName(k), PermissionHelper.getPermissionStatusText(v))).toString()}');
        } catch (e) {
          _addLog(LogLevel.warning, 'Ошибка запроса дополнительных разрешений: $e');
        }
        
        return true;
      } else {
        final deniedPermissions = results.entries
            .where((entry) => !entry.value.isGranted)
            .map((entry) => PermissionHelper.getPermissionDisplayName(entry.key))
            .join(', ');
        _addLog(LogLevel.warning, 'Не все основные разрешения получены. Отклонены: $deniedPermissions');
        return false;
      }
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
      
      // Проверяем доступность Bluetooth перед сканированием
      final isAvailable = await isBluetoothAvailable();
      if (!isAvailable) {
        _addLog(LogLevel.error, 'Bluetooth недоступен');
        return;
      }
      
      // Проверяем разрешения
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        _addLog(LogLevel.error, 'Недостаточно разрешений для сканирования');
        return;
      }
      
      // Очищаем карты найденных устройств для нового сканирования
      _clearDiscoveredDevices();
      _classicDevicesMap.clear();
      _deviceNameCache.clear();
      
      // Запускаем BLE сканирование
      await _startBLEScan();
      
      // Запускаем классическое Bluetooth сканирование
      await _startClassicBluetoothScan();
      
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка начала сканирования: $e');
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

  Future<void> _startClassicBluetoothScan() async {
    try {
      _addLog(LogLevel.info, '🔍 Запуск классического Bluetooth сканирования...');
      
      // Отменяем предыдущую подписку если есть
      await _classicBluetoothSubscription?.cancel();
      
      // Получаем список уже сопряженных устройств
      try {
        final bondedDevices = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
        if (bondedDevices.isNotEmpty) {
          _addLog(LogLevel.info, 'Найдено ${bondedDevices.length} сопряженных устройств');
          for (final device in bondedDevices) {
            final deviceEntity = _createClassicBluetoothDevice(device, true);
            _classicDevicesMap[device.address] = deviceEntity;
            _addLog(LogLevel.info, '📱 Сопряженное устройство: "${device.name}" (${device.address})');
          }
          _updateDeviceList();
        }
      } catch (e) {
        _addLog(LogLevel.warning, 'Ошибка получения сопряженных устройств: $e');
      }
      
      // Начинаем поиск новых устройств
      _classicBluetoothSubscription = classic.FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
        try {
          final deviceEntity = _createClassicBluetoothDevice(result.device, false);
          final deviceId = result.device.address;
          
          if (!_classicDevicesMap.containsKey(deviceId)) {
            _classicDevicesMap[deviceId] = deviceEntity;
            _addLog(LogLevel.info, '🔴 Новое классическое устройство: "${deviceEntity.name}" (${deviceEntity.deviceType}) - RSSI: ${deviceEntity.rssi}');
            _updateDeviceList(); // Сразу обновляем UI
          } else {
            // Обновляем существующее классическое устройство если нашли лучшую информацию
            final existingDevice = _classicDevicesMap[deviceId]!;
            if (_isBetterDeviceName(deviceEntity.name, existingDevice.name) ||
                deviceEntity.deviceType != existingDevice.deviceType) {
              _classicDevicesMap[deviceId] = deviceEntity;
              _addLog(LogLevel.debug, 'Обновлено классическое устройство: "${deviceEntity.name}"');
              _updateDeviceList(); // Сразу обновляем UI
            }
          }
        } catch (e) {
          _addLog(LogLevel.error, 'Ошибка обработки классического Bluetooth результата: $e');
        }
      });
      
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка классического Bluetooth сканирования: $e');
    }
  }

  BluetoothDeviceEntity _createClassicBluetoothDevice(classic.BluetoothDevice device, bool isBonded) {
    // Улучшаем имя устройства
    String deviceName = device.name ?? 'Неизвестное устройство';
    
    // Если имя пустое или невалидное, создаем описательное
    if (!_isValidDeviceName(deviceName) || deviceName == 'Неизвестное устройство') {
      deviceName = _generateClassicDeviceName(device);
    }
    
    // Определяем тип устройства
    final deviceType = _getImprovedDeviceType(deviceName, const []);
    
    return BluetoothDeviceEntity(
      id: device.address,
      name: deviceName,
      deviceType: deviceType,
      rssi: isBonded ? 0 : -50, // Для сопряженных устройств RSSI неизвестен
      isConnected: false,
      serviceUuids: const [], // Классический Bluetooth не использует UUID сервисов
      isClassicBluetooth: true,
      isBonded: isBonded,
    );
  }

  String _generateClassicDeviceName(classic.BluetoothDevice device) {
    // Определяем тип по классу устройства
    String deviceTypeHint = 'Устройство';
    
    try {
      // Пытаемся определить тип по классу устройства (если доступно)
      if (device.type == classic.BluetoothDeviceType.classic) {
        deviceTypeHint = 'Classic';
      } else if (device.type == classic.BluetoothDeviceType.le) {
        deviceTypeHint = 'BLE';
      } else if (device.type == classic.BluetoothDeviceType.dual) {
        deviceTypeHint = 'Dual';
      }
    } catch (e) {
      // Игнорируем ошибки
    }
    
    // Берем последние 4 символа MAC-адреса для создания уникального имени
    final address = device.address;
    final shortId = address.length > 4 ? address.substring(address.length - 4) : address;
    
    return '$deviceTypeHint $shortId';
  }

  String _getClassicBluetoothDeviceType(classic.BluetoothDevice device) {
    final name = (device.name ?? '').toLowerCase();
    
    // Определяем тип по имени устройства
    if (_isPhone(name)) return 'Телефон';
    if (_isAudioDevice(name)) return 'Аудио устройство';
    if (_isComputer(name)) return 'Компьютер';
    if (_isGamingDevice(name)) return 'Игровое устройство';
    if (_isCar(name)) return 'Автомобиль';
    if (_isWearableDevice(name)) return 'Носимые устройства';
    
    // Определяем по типу устройства
    if (device.type == classic.BluetoothDeviceType.unknown) {
      return 'Неизвестное устройство';
    } else if (device.type == classic.BluetoothDeviceType.classic) {
      return 'Классическое Bluetooth';
    } else if (device.type == classic.BluetoothDeviceType.le) {
      return 'Bluetooth Low Energy';
    } else if (device.type == classic.BluetoothDeviceType.dual) {
      return 'Dual Mode';
    }
    
    return 'Неизвестное устройство';
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
    
    // 4. НЕ используем manufacturerData для имен - это приводит к искаженным символам
    // manufacturerData содержит бинарные данные, а не текстовые имена
    
    // 5. Если имя все еще плохое, пытаемся создать описательное имя
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

  List<String> _extractNamesFromManufacturerData(List<int> data) {
    final names = <String>[];
    
    // НЕ пытаемся декодировать manufacturerData как строку!
    // Эти данные обычно содержат бинарную информацию, а не текст
    // Возвращаем пустой список, чтобы избежать искаженных символов
    
    return names;
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
    
    // Объединяем BLE и классические устройства
    final allDevices = <BluetoothDeviceEntity>[];
    allDevices.addAll(_discoveredDevicesMap.values);
    allDevices.addAll(_classicDevicesMap.values);
    
    // Удаляем дубликаты по MAC-адресу (приоритет у BLE устройств)
    final uniqueDevices = <String, BluetoothDeviceEntity>{};
    
    // Сначала добавляем классические устройства
    for (final device in _classicDevicesMap.values) {
      uniqueDevices[device.id] = device;
    }
    
    // Затем добавляем BLE устройства (они перезапишут классические с тем же MAC)
    for (final device in _discoveredDevicesMap.values) {
      uniqueDevices[device.id] = device;
    }
    
    final finalDevices = uniqueDevices.values.toList();
    
    // Сортируем устройства
    finalDevices.sort((a, b) {
      // Подключенные устройства всегда первые
      if (a.isConnected && !b.isConnected) return -1;
      if (!a.isConnected && b.isConnected) return 1;
      
      // Затем по типу (BLE устройства приоритетнее)
      if (a.isClassicBluetooth != b.isClassicBluetooth) {
        return a.isClassicBluetooth ? 1 : -1;
      }
      
      // Затем по силе сигнала (больше RSSI = ближе)
      return b.rssi.compareTo(a.rssi);
    });
    
    _devicesController.add(finalDevices);
    
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
      await _classicBluetoothSubscription?.cancel();
      _scanResultsSubscription = null;
      _classicBluetoothSubscription = null;
      // Записываем итоговый результат сканирования
      final totalDevices = _discoveredDevicesMap.length + _classicDevicesMap.length;
      _addLog(LogLevel.info, 'Сканирование завершено. Найдено устройств: $totalDevices');
      
      // Выводим список найденных устройств
      if (totalDevices > 0) {
        _addLog(LogLevel.info, '=== Список найденных устройств ===');
        
        // BLE устройства
        for (final device in _discoveredDevicesMap.values) {
          _addLog(LogLevel.info, '• ${device.name} (${device.deviceType}) - RSSI: ${device.rssi} dBm');
        }
        
        // Классические устройства
        for (final device in _classicDevicesMap.values) {
          _addLog(LogLevel.info, '• ${device.name} (${device.deviceType}) - Classic Bluetooth');
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
      _addLog(LogLevel.info, '🔍 Найдено ${services.length} сервисов на "$deviceName"');
      
      for (var service in services) {
        _addLog(LogLevel.debug, '   Сервис: ${service.uuid}');
        
        for (var characteristic in service.characteristics) {
          try {
            // Читаем характеристики, которые поддерживают чтение
            if (characteristic.properties.read) {
              final value = await characteristic.read();
              _addLog(LogLevel.info, '📊 Данные от "$deviceName" (${characteristic.uuid}): ${value.length} байт');
            }
            
            // Подписываемся на уведомления
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                _addLog(LogLevel.info, '📨 Уведомление от "$deviceName" (${characteristic.uuid}): ${value.length} байт');
              });
              _addLog(LogLevel.info, '🔔 Подписались на уведомления от "$deviceName" (${characteristic.uuid})');
            }
          } catch (e) {
            _addLog(LogLevel.warning, '⚠️ Ошибка чтения характеристики ${characteristic.uuid}: $e');
          }
        }
      }
    } catch (e) {
      _addLog(LogLevel.error, '❌ Ошибка сбора данных с "$deviceName": $e');
    }
  }

  Future<bool> _hybridConnectToDevice(String deviceId) async {
    _addLog(LogLevel.info, 'Попытка гибридного подключения к устройству: $deviceId');
    
    // Проверяем, есть ли устройство в BLE карте
    final bleDevice = _discoveredDevicesMap[deviceId];
    final classicDevice = _classicDevicesMap[deviceId];
    
    bool bleSuccess = false;
    bool classicSuccess = false;
    
    // Пытаемся подключиться через BLE
    if (bleDevice != null && !bleDevice.isClassicBluetooth) {
      _addLog(LogLevel.info, '🔵 Попытка BLE подключения к: ${bleDevice.name}');
      bleSuccess = await _connectWithRetry(deviceId, maxRetries: 2);
      if (bleSuccess) {
        _addLog(LogLevel.info, '✅ BLE подключение успешно');
        return true;
      }
    }
    
    // Пытаемся подключиться через классический Bluetooth
    if (classicDevice != null && classicDevice.isClassicBluetooth) {
      _addLog(LogLevel.info, '🔴 Попытка Classic подключения к: ${classicDevice.name}');
      classicSuccess = await _connectClassicBluetooth(deviceId);
      if (classicSuccess) {
        _addLog(LogLevel.info, '✅ Classic подключение успешно');
        return true;
      }
    }
    
    // Если устройство найдено только в одной карте, пытаемся подключиться другим способом
    if (!bleSuccess && !classicSuccess) {
      if (bleDevice != null) {
        _addLog(LogLevel.info, '🔄 Попытка Classic подключения к BLE устройству: ${bleDevice.name}');
        classicSuccess = await _connectClassicBluetooth(deviceId);
      } else if (classicDevice != null) {
        _addLog(LogLevel.info, '🔄 Попытка BLE подключения к Classic устройству: ${classicDevice.name}');
        bleSuccess = await _connectWithRetry(deviceId, maxRetries: 2);
      }
    }
    
    final success = bleSuccess || classicSuccess;
    if (!success) {
      _addLog(LogLevel.error, '❌ Не удалось подключиться ни через BLE, ни через Classic');
    }
    
    return success;
  }

  Future<bool> _connectClassicBluetooth(String deviceId) async {
    try {
      // Ищем устройство по MAC-адресу
      final bondedDevices = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      classic.BluetoothDevice? targetDevice;
      
      for (final device in bondedDevices) {
        if (device.address == deviceId) {
          targetDevice = device;
          break;
        }
      }
      
      if (targetDevice == null) {
        _addLog(LogLevel.warning, 'Classic устройство не найдено среди сопряженных: $deviceId');
        return false;
      }
      
      // Пытаемся подключиться
      final connection = await classic.BluetoothConnection.toAddress(deviceId);
      if (connection.isConnected) {
        _addLog(LogLevel.info, 'Classic Bluetooth подключение установлено');
        
        // Получаем дополнительную информацию об устройстве
        await _getClassicDeviceInfo(targetDevice, connection);
        
        // Закрываем соединение (для демонстрации)
        connection.dispose();
        return true;
      }
      
      return false;
    } catch (e) {
      _addLog(LogLevel.error, 'Ошибка Classic Bluetooth подключения: $e');
      return false;
    }
  }

  Future<void> _getClassicDeviceInfo(classic.BluetoothDevice device, classic.BluetoothConnection connection) async {
    try {
      _addLog(LogLevel.info, '📋 === ИНФОРМАЦИЯ О CLASSIC УСТРОЙСТВЕ ===');
      _addLog(LogLevel.info, '• Имя: ${device.name}');
      _addLog(LogLevel.info, '• Адрес: ${device.address}');
      _addLog(LogLevel.info, '• Тип: ${device.type}');
      _addLog(LogLevel.info, '• Подключено: ${connection.isConnected}');
      
      // Пытаемся получить дополнительную информацию
      if (connection.isConnected) {
        _addLog(LogLevel.info, '• Соединение активно');
        
        // Здесь можно добавить дополнительные запросы к устройству
        // например, запросы AT команд для получения информации
      }
      
    } catch (e) {
      _addLog(LogLevel.warning, 'Ошибка получения информации о Classic устройстве: $e');
    }
  }

  Future<bool> _connectWithRetry(String deviceId, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final device = BluetoothDevice.fromId(deviceId);
        final deviceName = device.platformName.isNotEmpty ? device.platformName : deviceId;
        
        _addLog(LogLevel.info, 'Подключение к устройству: $deviceName (попытка $attempt/$maxRetries)');
        
        // Проверяем состояние Bluetooth адаптера
        if (!await isBluetoothAvailable()) {
          _addLog(LogLevel.error, 'Bluetooth адаптер недоступен');
          return false;
        }
      
      // Проверяем, не подключено ли уже устройство
      if (device.isConnected) {
          _addLog(LogLevel.info, 'Устройство уже подключено: $deviceName');
        _connectedDevices[deviceId] = device;
          _setupDeviceListeners(device);
        return true;
      }
      
        // Если это повторная попытка, делаем паузу и очищаем предыдущие подключения
        if (attempt > 1) {
          _addLog(LogLevel.info, 'Ожидание перед повторной попыткой...');
          await Future.delayed(Duration(seconds: attempt * 2));
          
          // Очищаем предыдущие подключения
          try {
            if (device.isConnected) {
              await device.disconnect();
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } catch (e) {
            _addLog(LogLevel.debug, 'Ошибка при очистке предыдущего подключения: $e');
          }
        }

        // Подключаемся к устройству с увеличенным таймаутом
      await device.connect(
          timeout: Duration(seconds: 15 + (attempt * 5)), // Увеличиваем таймаут с каждой попыткой
          autoConnect: false,
        );

        // Ждем стабилизации подключения
        await Future.delayed(const Duration(milliseconds: 1000));

        // Проверяем успешность подключения
        if (device.isConnected) {
      _connectedDevices[deviceId] = device;
          _setupDeviceListeners(device);
          
          _addLog(LogLevel.info, 'Успешно подключено к устройству: $deviceName');
          
          // Если имя устройства стало доступным после подключения
          if (device.platformName.isNotEmpty && device.platformName != deviceName) {
            _addLog(LogLevel.info, 'Имя устройства после подключения: "${device.platformName}"');
          }
      
      return true;
        }

        // Если подключение не удалось, но это не последняя попытка
        if (attempt < maxRetries) {
          _addLog(LogLevel.warning, 'Попытка $attempt не удалась, повторяем...');
          continue;
        }

    } on FlutterBluePlusException catch (e) {
        final errorMessage = _parseBluetoothError(e);
      
        if (attempt < maxRetries) {
          _addLog(LogLevel.warning, 'Попытка $attempt не удалась: $errorMessage. Повторяем...');
          
          // Для ошибки 133 делаем более длительную паузу
      if (e.toString().contains('android-code: 133')) {
            await Future.delayed(Duration(seconds: attempt * 3));
      }
          continue;
        } else {
          _addLog(LogLevel.error, 'Все попытки подключения исчерпаны: $errorMessage');
      return false;
        }
    } catch (e) {
        final errorMessage = _parseBluetoothError(e);
        
        if (attempt < maxRetries) {
          _addLog(LogLevel.warning, 'Попытка $attempt не удалась: $errorMessage. Повторяем...');
          continue;
        } else {
          _addLog(LogLevel.error, 'Все попытки подключения исчерпаны: $errorMessage');
      return false;
        }
      }
    }

    _addLog(LogLevel.error, 'Не удалось подключиться к устройству после $maxRetries попыток');
    return false;
  }

  String _parseBluetoothError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('android-code: 133') || errorString.contains('gatt_error')) {
      return 'GATT Error (133) - Устройство недоступно или занято другим приложением. Рекомендации:\n'
          '• Убедитесь, что устройство включено и находится рядом\n'
          '• Закройте другие Bluetooth приложения\n'
          '• Перезапустите Bluetooth на телефоне\n'
          '• Попробуйте "забыть" устройство в настройках Bluetooth и подключиться заново';
    } else if (errorString.contains('timeout')) {
      return 'Таймаут подключения - Устройство не отвечает в течение заданного времени';
    } else if (errorString.contains('connection')) {
      return 'Ошибка подключения - Проверьте доступность устройства';
    } else if (errorString.contains('permission')) {
      return 'Недостаточно разрешений для подключения';
    } else if (errorString.contains('bluetooth')) {
      return 'Ошибка Bluetooth - Проверьте состояние адаптера';
    } else {
      return 'Неизвестная ошибка: $error';
    }
  }

  void _setupDeviceListeners(BluetoothDevice device) {
    // Слушаем изменения состояния подключения
    device.connectionState.listen((state) {
      final deviceName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString();
      
      if (state == BluetoothConnectionState.disconnected) {
        _addLog(LogLevel.warning, 'Устройство отключилось: $deviceName');
        _connectedDevices.remove(device.remoteId.toString());
      } else if (state == BluetoothConnectionState.connected) {
        _addLog(LogLevel.info, 'Устройство подключено: $deviceName');
        _connectedDevices[device.remoteId.toString()] = device;
        
        // Пытаемся получить сервисы устройства
        _discoverDeviceServices(device);
      }
    }).onError((error) {
      _addLog(LogLevel.error, 'Ошибка слушателя состояния подключения: $error');
    });
  }

  void _discoverDeviceServices(BluetoothDevice device) {
    if (device.isConnected) {
      device.discoverServices().then((services) {
        final deviceName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString();
        _addLog(LogLevel.info, 'Найдено сервисов: ${services.length} для устройства $deviceName');
        
        // Запускаем полную диагностику устройства
        _performFullDeviceDiagnostics(device, services);
      }).catchError((e) {
        _addLog(LogLevel.warning, 'Ошибка получения сервисов: $e');
      });
    }
  }

  Future<void> _performFullDeviceDiagnostics(BluetoothDevice device, List<BluetoothService> services) async {
    final deviceName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString();
    
    _addLog(LogLevel.info, '🔍 === ПОЛНАЯ ДИАГНОСТИКА УСТРОЙСТВА: $deviceName ===');
    
    // 1. Основная информация об устройстве
    _addLog(LogLevel.info, '📱 ОСНОВНАЯ ИНФОРМАЦИЯ:');
    _addLog(LogLevel.info, '   • ID: ${device.remoteId}');
    _addLog(LogLevel.info, '   • Имя: ${device.platformName}');
    _addLog(LogLevel.info, '   • Подключено: ${device.isConnected}');
    _addLog(LogLevel.info, '   • Состояние: ${device.connectionState}');
    
    // 2. Информация о рекламных данных (если доступна)
    try {
      _addLog(LogLevel.info, '📡 РЕКЛАМНЫЕ ДАННЫЕ:');
      _addLog(LogLevel.info, '   • Local Name: ${device.platformName}');
      _addLog(LogLevel.info, '   • TX Power Level: ${device.platformName}'); // Может быть недоступно
    } catch (e) {
      _addLog(LogLevel.debug, '   • Рекламные данные недоступны: $e');
    }
    
    // 3. Детальная информация о сервисах
    _addLog(LogLevel.info, '🔧 СЕРВИСЫ (${services.length}):');
    for (int i = 0; i < services.length; i++) {
      final service = services[i];
      final serviceName = _getServiceName(service.uuid.toString());
      _addLog(LogLevel.info, '   ${i + 1}. ${service.uuid}');
      if (serviceName.isNotEmpty) {
        _addLog(LogLevel.info, '       • Название: $serviceName');
      }
      
      // Получаем характеристики сервиса
      try {
        final characteristics = service.characteristics;
        _addLog(LogLevel.info, '      Характеристики (${characteristics.length}):');
        
        for (int j = 0; j < characteristics.length; j++) {
          final char = characteristics[j];
          final charName = _getCharacteristicName(char.uuid.toString());
          _addLog(LogLevel.info, '        ${j + 1}. ${char.uuid}');
          if (charName.isNotEmpty) {
            _addLog(LogLevel.info, '           • Название: $charName');
          }
          _addLog(LogLevel.info, '           • Свойства: ${_getCharacteristicProperties(char)}');
          _addLog(LogLevel.info, '           • Дескрипторы: ${char.descriptors.length}');
          
          // Добавляем задержку между операциями для избежания GATT ошибок
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Анализируем дескрипторы
          await _analyzeCharacteristicDescriptors(device, char);
          
          // Добавляем задержку между операциями
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Пытаемся прочитать значение характеристики
          await _readCharacteristicValue(device, char);
          
          // Добавляем задержку между операциями
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Пытаемся подписаться на уведомления
          await _subscribeToCharacteristic(device, char);
          
          // Добавляем задержку между характеристиками
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        _addLog(LogLevel.warning, '      Ошибка получения характеристик: $e');
      }
      
      // Добавляем задержку между сервисами
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    // 4. Информация о производителе (если доступна)
    _addLog(LogLevel.info, '🏭 ИНФОРМАЦИЯ О ПРОИЗВОДИТЕЛЕ:');
    _addLog(LogLevel.info, '   • Данные недоступны через BLE API');
    
    // 5. Статистика подключения
    _addLog(LogLevel.info, '📊 СТАТИСТИКА ПОДКЛЮЧЕНИЯ:');
    _addLog(LogLevel.info, '   • Время подключения: ${DateTime.now()}');
    _addLog(LogLevel.info, '   • Количество сервисов: ${services.length}');
    
    _addLog(LogLevel.info, '✅ === ДИАГНОСТИКА ЗАВЕРШЕНА ===');
  }

  String _getServiceName(String uuid) {
    // Стандартные сервисы Bluetooth
    final standardServices = {
      '00001800-0000-1000-8000-00805f9b34fb': 'Generic Access',
      '00001801-0000-1000-8000-00805f9b34fb': 'Generic Attribute',
      '00001802-0000-1000-8000-00805f9b34fb': 'Immediate Alert',
      '00001803-0000-1000-8000-00805f9b34fb': 'Link Loss',
      '00001804-0000-1000-8000-00805f9b34fb': 'Tx Power',
      '00001805-0000-1000-8000-00805f9b34fb': 'Current Time Service',
      '00001806-0000-1000-8000-00805f9b34fb': 'Reference Time Update Service',
      '00001807-0000-1000-8000-00805f9b34fb': 'Next DST Change Service',
      '00001808-0000-1000-8000-00805f9b34fb': 'Glucose',
      '00001809-0000-1000-8000-00805f9b34fb': 'Health Thermometer',
      '0000180a-0000-1000-8000-00805f9b34fb': 'Device Information',
      '0000180b-0000-1000-8000-00805f9b34fb': 'Heart Rate',
      '0000180c-0000-1000-8000-00805f9b34fb': 'Phone Alert Status Service',
      '0000180d-0000-1000-8000-00805f9b34fb': 'Battery Service',
      '0000180e-0000-1000-8000-00805f9b34fb': 'Blood Pressure',
      '0000180f-0000-1000-8000-00805f9b34fb': 'Alert Notification Service',
      '00001810-0000-1000-8000-00805f9b34fb': 'Human Interface Device',
      '00001811-0000-1000-8000-00805f9b34fb': 'Scan Parameters',
      '00001812-0000-1000-8000-00805f9b34fb': 'Running Speed and Cadence',
      '00001813-0000-1000-8000-00805f9b34fb': 'Automation IO',
      '00001814-0000-1000-8000-00805f9b34fb': 'Audio Input Control',
      '00001815-0000-1000-8000-00805f9b34fb': 'Audio Stream Control',
      '00001816-0000-1000-8000-00805f9b34fb': 'Volume Control',
      '00001817-0000-1000-8000-00805f9b34fb': 'Volume Offset Control',
      '00001818-0000-1000-8000-00805f9b34fb': 'Volume Control Service',
      '00001819-0000-1000-8000-00805f9b34fb': 'Weight Scale',
      '0000181a-0000-1000-8000-00805f9b34fb': 'Weight Scale Service',
      '0000181b-0000-1000-8000-00805f9b34fb': 'Cycling Power',
      '0000181c-0000-1000-8000-00805f9b34fb': 'Cycling Speed and Cadence',
      '0000181d-0000-1000-8000-00805f9b34fb': 'Location and Navigation',
      '0000181e-0000-1000-8000-00805f9b34fb': 'Environmental Sensing',
      '0000181f-0000-1000-8000-00805f9b34fb': 'Body Composition',
      '00001820-0000-1000-8000-00805f9b34fb': 'User Data',
      '00001821-0000-1000-8000-00805f9b34fb': 'Weight Scale',
      '00001822-0000-1000-8000-00805f9b34fb': 'Fitness Machine',
      '00001823-0000-1000-8000-00805f9b34fb': 'Mesh Provisioning Service',
      '00001824-0000-1000-8000-00805f9b34fb': 'Mesh Proxy Service',
      '00001825-0000-1000-8000-00805f9b34fb': 'Reconnection Configuration',
      '00001826-0000-1000-8000-00805f9b34fb': 'Fitness Machine Control Point',
      '00001827-0000-1000-8000-00805f9b34fb': 'Fitness Machine Feature',
      '00001828-0000-1000-8000-00805f9b34fb': 'Fitness Machine Status',
      '00001829-0000-1000-8000-00805f9b34fb': 'Fitness Machine Control Point',
      '0000182a-0000-1000-8000-00805f9b34fb': 'Fitness Machine Feature',
      '0000182b-0000-1000-8000-00805f9b34fb': 'Fitness Machine Status',
    };
    
    final uuidLower = uuid.toLowerCase();
    return standardServices[uuidLower] ?? '';
  }

  String _getCharacteristicName(String uuid) {
    // Стандартные характеристики Bluetooth
    final standardCharacteristics = {
      '00002a00-0000-1000-8000-00805f9b34fb': 'Device Name',
      '00002a01-0000-1000-8000-00805f9b34fb': 'Appearance',
      '00002a02-0000-1000-8000-00805f9b34fb': 'Peripheral Privacy Flag',
      '00002a03-0000-1000-8000-00805f9b34fb': 'Reconnection Address',
      '00002a04-0000-1000-8000-00805f9b34fb': 'Peripheral Preferred Connection Parameters',
      '00002a05-0000-1000-8000-00805f9b34fb': 'Service Changed',
      '00002a06-0000-1000-8000-00805f9b34fb': 'Alert Level',
      '00002a07-0000-1000-8000-00805f9b34fb': 'Tx Power Level',
      '00002a08-0000-1000-8000-00805f9b34fb': 'Date Time',
      '00002a09-0000-1000-8000-00805f9b34fb': 'Day of Week',
      '00002a0a-0000-1000-8000-00805f9b34fb': 'Day Date Time',
      '00002a0b-0000-1000-8000-00805f9b34fb': 'Exact Time 100',
      '00002a0c-0000-1000-8000-00805f9b34fb': 'Exact Time 256',
      '00002a0d-0000-1000-8000-00805f9b34fb': 'DST Offset',
      '00002a0e-0000-1000-8000-00805f9b34fb': 'Time Zone',
      '00002a0f-0000-1000-8000-00805f9b34fb': 'Local Time Information',
      '00002a10-0000-1000-8000-00805f9b34fb': 'Secondary Time Zone',
      '00002a11-0000-1000-8000-00805f9b34fb': 'Time with DST',
      '00002a12-0000-1000-8000-00805f9b34fb': 'Time Accuracy',
      '00002a13-0000-1000-8000-00805f9b34fb': 'Time Source',
      '00002a14-0000-1000-8000-00805f9b34fb': 'Reference Time Information',
      '00002a15-0000-1000-8000-00805f9b34fb': 'Time Broadcast',
      '00002a16-0000-1000-8000-00805f9b34fb': 'Time Update Control Point',
      '00002a17-0000-1000-8000-00805f9b34fb': 'Time Update State',
      '00002a18-0000-1000-8000-00805f9b34fb': 'Le Time',
      '00002a19-0000-1000-8000-00805f9b34fb': 'Temperature',
      '00002a1a-0000-1000-8000-00805f9b34fb': 'Temperature Type',
      '00002a1b-0000-1000-8000-00805f9b34fb': 'Intermediate Temperature',
      '00002a1c-0000-1000-8000-00805f9b34fb': 'Temperature in Celsius',
      '00002a1d-0000-1000-8000-00805f9b34fb': 'Temperature in Fahrenheit',
      '00002a1e-0000-1000-8000-00805f9b34fb': 'Temperature Range',
      '00002a1f-0000-1000-8000-00805f9b34fb': 'Temperature Measurement',
      '00002a20-0000-1000-8000-00805f9b34fb': 'Temperature Type',
      '00002a21-0000-1000-8000-00805f9b34fb': 'Intermediate Temperature',
      '00002a22-0000-1000-8000-00805f9b34fb': 'Measurement Interval',
      '00002a23-0000-1000-8000-00805f9b34fb': 'Boot Keyboard Input Report',
      '00002a24-0000-1000-8000-00805f9b34fb': 'System ID',
      '00002a25-0000-1000-8000-00805f9b34fb': 'Model Number String',
      '00002a26-0000-1000-8000-00805f9b34fb': 'Serial Number String',
      '00002a27-0000-1000-8000-00805f9b34fb': 'Firmware Revision String',
      '00002a28-0000-1000-8000-00805f9b34fb': 'Hardware Revision String',
      '00002a29-0000-1000-8000-00805f9b34fb': 'Software Revision String',
      '00002a2a-0000-1000-8000-00805f9b34fb': 'Manufacturer Name String',
      '00002a2b-0000-1000-8000-00805f9b34fb': 'IEEE 11073-20601 Regulatory Certification Data List',
      '00002a2c-0000-1000-8000-00805f9b34fb': 'Current Time',
      '00002a2d-0000-1000-8000-00805f9b34fb': 'Magnetic Declination',
      '00002a2e-0000-1000-8000-00805f9b34fb': 'Scan Refresh',
      '00002a2f-0000-1000-8000-00805f9b34fb': 'Boot Keyboard Output Report',
      '00002a30-0000-1000-8000-00805f9b34fb': 'Boot Mouse Input Report',
      '00002a31-0000-1000-8000-00805f9b34fb': 'Glucose Measurement',
      '00002a32-0000-1000-8000-00805f9b34fb': 'Battery Level',
      '00002a33-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a34-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a35-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a36-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a37-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a38-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a39-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a3a-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a3b-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a3c-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a3d-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a3e-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a3f-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a40-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a41-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a42-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a43-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a44-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a45-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a46-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a47-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a48-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a49-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a4a-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a4b-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a4c-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a4d-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a4e-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a4f-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a50-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a51-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a52-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a53-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a54-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a55-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a56-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a57-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a58-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a59-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a5a-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a5b-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a5c-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a5d-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a5e-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a5f-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a60-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a61-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a62-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a63-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a64-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a65-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a66-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a67-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a68-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a69-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a6a-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a6b-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a6c-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a6d-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a6e-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a6f-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a70-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a71-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a72-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a73-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a74-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a75-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a76-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a77-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a78-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a79-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a7a-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a7b-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a7c-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a7d-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a7e-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a7f-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a80-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a81-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a82-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a83-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a84-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a85-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a86-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a87-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a88-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a89-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a8a-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a8b-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a8c-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a8d-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a8e-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a8f-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a90-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a91-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a92-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a93-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a94-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a95-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a96-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a97-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a98-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a99-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a9a-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a9b-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a9c-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a9d-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002a9e-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002a9f-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aa0-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aa1-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aa2-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aa3-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aa4-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aa5-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aa6-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aa7-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aa8-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aa9-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aaa-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aab-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aac-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aad-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aae-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aaf-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ab0-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ab1-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ab2-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ab3-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ab4-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ab5-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ab6-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ab7-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ab8-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ab9-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aba-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002abb-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002abc-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002abd-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002abe-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002abf-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ac0-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ac1-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ac2-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ac3-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ac4-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ac5-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ac6-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ac7-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ac8-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ac9-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aca-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002acb-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002acc-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002acd-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ace-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002acf-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ad0-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ad1-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ad2-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ad3-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ad4-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ad5-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ad6-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ad7-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ad8-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ad9-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ada-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002adb-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002adc-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002add-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ade-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002adf-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ae0-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ae1-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ae2-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ae3-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ae4-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ae5-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ae6-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ae7-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002ae8-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002ae9-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aea-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aeb-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aec-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aed-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002aee-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aef-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002af0-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002af1-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002af2-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002af3-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002af4-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002af5-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002af6-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002af7-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002af8-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002af9-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002afa-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002afb-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002afc-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002afd-0000-1000-8000-00805f9b34fb': 'Battery Power State',
      '00002afe-0000-1000-8000-00805f9b34fb': 'Battery Level State',
      '00002aff-0000-1000-8000-00805f9b34fb': 'Battery Power State',
    };
    
    final uuidLower = uuid.toLowerCase();
    return standardCharacteristics[uuidLower] ?? '';
  }

  String _getCharacteristicProperties(BluetoothCharacteristic characteristic) {
    final properties = <String>[];
    
    if (characteristic.properties.read) properties.add('READ');
    if (characteristic.properties.write) properties.add('WRITE');
    if (characteristic.properties.writeWithoutResponse) properties.add('WRITE_NO_RESPONSE');
    if (characteristic.properties.notify) properties.add('NOTIFY');
    if (characteristic.properties.indicate) properties.add('INDICATE');
    if (characteristic.properties.broadcast) properties.add('BROADCAST');
    if (characteristic.properties.authenticatedSignedWrites) properties.add('AUTH_SIGNED_WRITES');
    if (characteristic.properties.extendedProperties) properties.add('EXTENDED_PROPERTIES');
    
    return properties.isEmpty ? 'НЕТ' : properties.join(', ');
  }

  Future<void> _readCharacteristicValue(BluetoothDevice device, BluetoothCharacteristic characteristic) async {
    try {
      // Проверяем, что устройство все еще подключено
      if (!device.isConnected) {
        _addLog(LogLevel.debug, '           • Устройство отключено, пропускаем чтение');
        return;
      }
      
      if (characteristic.properties.read) {
        // Добавляем таймаут для чтения
        final value = await characteristic.read().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw Exception('Таймаут чтения характеристики');
          },
        );
        
        if (value.isNotEmpty) {
          final hexValue = value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
          final stringValue = String.fromCharCodes(value.where((byte) => byte >= 32 && byte <= 126));
          
          _addLog(LogLevel.info, '           • Значение (HEX): $hexValue');
          if (stringValue.isNotEmpty) {
            _addLog(LogLevel.info, '           • Значение (TEXT): "$stringValue"');
          }
        } else {
          _addLog(LogLevel.info, '           • Значение: ПУСТОЕ');
        }
      }
    } catch (e) {
      // Более детальная обработка ошибок
      if (e.toString().contains('201') || e.toString().contains('WRITE_REQUEST_BUSY')) {
        _addLog(LogLevel.debug, '           • GATT занят, пропускаем чтение');
      } else if (e.toString().contains('timeout')) {
        _addLog(LogLevel.debug, '           • Таймаут чтения');
      } else {
        _addLog(LogLevel.debug, '           • Ошибка чтения: $e');
      }
    }
  }

  Future<void> _analyzeCharacteristicDescriptors(BluetoothDevice device, BluetoothCharacteristic characteristic) async {
    try {
      // Проверяем, что устройство все еще подключено
      if (!device.isConnected) {
        _addLog(LogLevel.debug, '           • Устройство отключено, пропускаем дескрипторы');
        return;
      }
      
      if (characteristic.descriptors.isNotEmpty) {
        _addLog(LogLevel.info, '           • Анализ дескрипторов:');
        
        for (int k = 0; k < characteristic.descriptors.length; k++) {
          final descriptor = characteristic.descriptors[k];
          _addLog(LogLevel.info, '             ${k + 1}. ${descriptor.uuid}');
          
          // Добавляем задержку между дескрипторами
          await Future.delayed(const Duration(milliseconds: 50));
          
          // Пытаемся прочитать значение дескриптора
          try {
            final descriptorValue = await descriptor.read().timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                throw Exception('Таймаут чтения дескриптора');
              },
            );
            
            if (descriptorValue.isNotEmpty) {
              final hexValue = descriptorValue.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
              final stringValue = String.fromCharCodes(descriptorValue.where((byte) => byte >= 32 && byte <= 126));
              
              _addLog(LogLevel.info, '               • Значение (HEX): $hexValue');
              if (stringValue.isNotEmpty) {
                _addLog(LogLevel.info, '               • Значение (TEXT): "$stringValue"');
              }
            } else {
              _addLog(LogLevel.info, '               • Значение: ПУСТОЕ');
            }
          } catch (e) {
            // Более детальная обработка ошибок дескрипторов
            if (e.toString().contains('201') || e.toString().contains('WRITE_REQUEST_BUSY')) {
              _addLog(LogLevel.debug, '               • GATT занят, пропускаем дескриптор');
            } else if (e.toString().contains('timeout')) {
              _addLog(LogLevel.debug, '               • Таймаут чтения дескриптора');
            } else if (e.toString().contains('false')) {
              _addLog(LogLevel.debug, '               • Дескриптор недоступен для чтения');
            } else {
              _addLog(LogLevel.debug, '               • Ошибка чтения дескриптора: $e');
            }
          }
        }
      }
    } catch (e) {
      _addLog(LogLevel.debug, '           • Ошибка анализа дескрипторов: $e');
    }
  }

  Future<void> _subscribeToCharacteristic(BluetoothDevice device, BluetoothCharacteristic characteristic) async {
    try {
      // Проверяем, что устройство все еще подключено
      if (!device.isConnected) {
        _addLog(LogLevel.debug, '           • Устройство отключено, пропускаем подписку');
        return;
      }
      
      if (characteristic.properties.notify || characteristic.properties.indicate) {
        // Добавляем таймаут для подписки
        await characteristic.setNotifyValue(true).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw Exception('Таймаут подписки на уведомления');
          },
        );
        
        _addLog(LogLevel.info, '           • Подписка на уведомления: АКТИВНА');
        
        // Слушаем уведомления с ограничением по времени
        characteristic.lastValueStream.listen((data) {
          if (data.isNotEmpty) {
            final hexValue = data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
            final stringValue = String.fromCharCodes(data.where((byte) => byte >= 32 && byte <= 126));
            
            _addLog(LogLevel.info, '           • Уведомление (HEX): $hexValue');
            if (stringValue.isNotEmpty) {
              _addLog(LogLevel.info, '           • Уведомление (TEXT): "$stringValue"');
            }
          }
        }).onError((error) {
          _addLog(LogLevel.warning, '           • Ошибка уведомлений: $error');
        });
      }
    } catch (e) {
      // Более детальная обработка ошибок подписки
      if (e.toString().contains('201') || e.toString().contains('WRITE_REQUEST_BUSY')) {
        _addLog(LogLevel.debug, '           • GATT занят, пропускаем подписку');
      } else if (e.toString().contains('timeout')) {
        _addLog(LogLevel.debug, '           • Таймаут подписки на уведомления');
      } else if (e.toString().contains('setNotifyValue')) {
        _addLog(LogLevel.debug, '           • Ошибка подписки: $e');
      } else {
        _addLog(LogLevel.debug, '           • Ошибка подписки: $e');
      }
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
      final deviceInfo = _discoveredDevicesMap[deviceId] ?? _classicDevicesMap[deviceId];
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
      final deviceInfo = _discoveredDevicesMap[deviceId] ?? _classicDevicesMap[deviceId];
      final deviceName = deviceInfo?.name ?? 'Неизвестное устройство';
      _addLog(LogLevel.error, '❌ Ошибка отключения от "$deviceName": $e');
    }
  }

  void _listenToDeviceData(BluetoothDevice device) {
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _addLog(
          LogLevel.warning, 
          'Устройство отключилось: ${device.platformName}',
          deviceId: device.remoteId.toString(),
          deviceName: device.platformName,
          additionalData: {
            'connection_state': 'disconnected',
            'device_id': device.remoteId.toString(),
          },
        );
        _connectedDevices.remove(device.remoteId.toString());
      } else if (state == BluetoothConnectionState.connected) {
        _addLog(
          LogLevel.info, 
          'Устройство подключено: ${device.platformName}',
          deviceId: device.remoteId.toString(),
          deviceName: device.platformName,
          additionalData: {
            'connection_state': 'connected',
            'device_id': device.remoteId.toString(),
          },
        );
      }
    });
    
    // Попытка получить сервисы и характеристики с задержкой
    Future.delayed(const Duration(seconds: 2), () {
      if (device.isConnected) {
        device.discoverServices().then((services) {
          _addLog(
            LogLevel.info, 
            'Найдено сервисов: ${services.length} для устройства ${device.platformName}',
            deviceId: device.remoteId.toString(),
            deviceName: device.platformName,
            additionalData: {
              'services_count': services.length,
              'device_id': device.remoteId.toString(),
            },
          );
          
          for (final service in services) {
            _addLog(
              LogLevel.debug, 
              'Сервис: ${service.uuid}',
              deviceId: device.remoteId.toString(),
              deviceName: device.platformName,
              additionalData: {
                'service_uuid': service.uuid.toString(),
                'characteristics_count': service.characteristics.length,
              },
            );
            
            for (final characteristic in service.characteristics) {
              _addLog(
                LogLevel.debug, 
                'Характеристика: ${characteristic.uuid}',
                deviceId: device.remoteId.toString(),
                deviceName: device.platformName,
                additionalData: {
                  'characteristic_uuid': characteristic.uuid.toString(),
                  'properties': {
                    'read': characteristic.properties.read,
                    'write': characteristic.properties.write,
                    'notify': characteristic.properties.notify,
                    'indicate': characteristic.properties.indicate,
                  },
                },
              );
              
              // Подписываемся на уведомления если возможно
              if (characteristic.properties.notify) {
                try {
                  characteristic.setNotifyValue(true);
                  characteristic.lastValueStream.listen((data) {
                    _addLog(
                      LogLevel.info, 
                      'Получены данные от ${device.platformName}',
                      deviceId: device.remoteId.toString(),
                      deviceName: device.platformName,
                      additionalData: {
                        'data_length': data.length,
                        'data_hex': data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' '),
                        'data_string': String.fromCharCodes(data.where((byte) => byte >= 32 && byte <= 126)),
                        'characteristic_uuid': characteristic.uuid.toString(),
                      },
                    );
                  });
                } catch (e) {
                  _addLog(
                    LogLevel.warning, 
                    'Не удалось подписаться на уведомления: $e',
                    deviceId: device.remoteId.toString(),
                    deviceName: device.platformName,
                    additionalData: {
                      'error': e.toString(),
                      'characteristic_uuid': characteristic.uuid.toString(),
                    },
                  );
                }
              }
            }
          }
        }).catchError((e) {
          _addLog(
            LogLevel.error, 
            'Ошибка получения сервисов: $e',
            deviceId: device.remoteId.toString(),
            deviceName: device.platformName,
            additionalData: {
              'error': e.toString(),
            },
          );
        });
      }
    });
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
  
  /// Проверяет, является ли имя сгенерированным нашим алгоритмом
  bool _isGeneratedName(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.contains('устройство') || 
           lowerName.contains('аудио') || 
           lowerName.contains('фитнес') || 
           lowerName.contains('ввод') ||
           lowerName.startsWith('bluetooth устройство');
  }
  
  /// Проверяет, является ли имя общим/неспецифичным
  bool _isGenericName(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.contains('неизвестное') ||
           lowerName.contains('unknown') ||
           lowerName == 'device' ||
           lowerName == 'bluetooth';
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
