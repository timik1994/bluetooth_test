import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'emulation_logger.dart';
import '../../presentation/bloc/bluetooth_bloc.dart';

/// UUID для стандартных BLE сервисов
class BleServiceUuids {
  static const String heartRate = '0000180D-0000-1000-8000-00805F9B34FB';
  static const String battery = '0000180F-0000-1000-8000-00805F9B34FB';
  static const String deviceInfo = '0000180A-0000-1000-8000-00805F9B34FB';
}

/// UUID для характеристик
class BleCharacteristicUuids {
  static const String heartRateMeasurement = '00002A37-0000-1000-8000-00805F9B34FB';
  static const String batteryLevel = '00002A19-0000-1000-8000-00805F9B34FB';
  static const String deviceName = '00002A00-0000-1000-8000-00805F9B34FB';
  static const String manufacturerName = '00002A29-0000-1000-8000-00805F9B34FB';
  static const String modelNumber = '00002A24-0000-1000-8000-00805F9B34FB';
}

class BlePeripheralService {
  static final BlePeripheralService _instance = BlePeripheralService._internal();
  factory BlePeripheralService() => _instance;
  BlePeripheralService._internal() {
    print('BLE Service: Инициализация BlePeripheralService...');
    _setupChannelHandlers();
    _initializeLogger();
    print('BLE Service: BlePeripheralService инициализирован');
  }

  final EmulationLogger _logger = EmulationLogger();

  /// Инициализация логгера
  void _initializeLogger({BluetoothBloc? bluetoothBloc}) {
    _logger.initialize(bluetoothBloc: bluetoothBloc);
  }

  /// Установка BluetoothBloc для логирования
  void setBluetoothBloc(BluetoothBloc bluetoothBloc) {
    _logger.initialize(bluetoothBloc: bluetoothBloc);
  }

  static const MethodChannel _channel = MethodChannel('ble_peripheral');
  bool _isAdvertising = false;
  Timer? _heartRateTimer;
  int _currentHeartRate = 75;
  int _currentBatteryLevel = 85;
  
  // Храним информацию о последнем подключенном устройстве
  Map<String, dynamic>? _lastConnectedDevice;

  // Потоки для уведомлений о изменениях
  final StreamController<int> _heartRateController = StreamController<int>.broadcast();
  final StreamController<int> _batteryController = StreamController<int>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _deviceConnectedController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _deviceDisconnectedController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _dataReceivedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<int> get batteryStream => _batteryController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get deviceConnectedStream => _deviceConnectedController.stream;
  Stream<String> get deviceDisconnectedStream => _deviceDisconnectedController.stream;
  Stream<Map<String, dynamic>> get dataReceivedStream => _dataReceivedController.stream;

  bool get isAdvertising => _isAdvertising;
  int get currentHeartRate => _currentHeartRate;
  int get currentBatteryLevel => _currentBatteryLevel;
  Map<String, dynamic>? get lastConnectedDevice => _lastConnectedDevice;

  /// Настройка обработчиков событий от Android
  void _setupChannelHandlers() {
    print('BLE Service: Настройка обработчиков channel...');
    _channel.setMethodCallHandler((call) async {
      print('BLE Service: ===== ПОЛУЧЕНО СОБЫТИЕ ОТ ANDROID =====');
      print('BLE Service: Метод: ${call.method}');
      print('BLE Service: Аргументы: ${call.arguments}');
      
      switch (call.method) {
        case 'onDeviceConnected':
          final data = Map<String, dynamic>.from(call.arguments);
          print('BLE Service: ===== УСТРОЙСТВО ПОДКЛЮЧИЛОСЬ =====');
          print('BLE Service: Имя: ${data['deviceName']}');
          print('BLE Service: Адрес: ${data['deviceAddress']}');
          print('BLE Service: Тип: ${data['deviceType']}');
          print('BLE Service: Bond: ${data['bondState']}');
          print('BLE Service: Все данные: $data');
          print('BLE Service: Device Connected Controller: ${_deviceConnectedController}');
          print('BLE Service: Controller is closed: ${_deviceConnectedController.isClosed}');
          
          // Логирование подключения
          _logger.logDeviceConnected(
            data['deviceName'] ?? 'Неизвестное устройство',
            data['deviceAddress'] ?? 'Неизвестный адрес',
            data,
          );
          
          // Сохраняем информацию о подключенном устройстве
          _lastConnectedDevice = data;
          
          _deviceConnectedController.add(data);
          print('BLE Service: Данные добавлены в поток');
          print('BLE Service: Количество слушателей: ${_deviceConnectedController.hasListener}');
          break;
        case 'onDeviceDisconnected':
          final data = Map<String, dynamic>.from(call.arguments);
          final address = data['deviceAddress'] as String;
          print('BLE Service: ===== УСТРОЙСТВО ОТКЛЮЧИЛОСЬ =====');
          print('BLE Service: Адрес: $address');
          
          // Логирование отключения
          _logger.logDeviceDisconnected(address);
          
          // Очищаем информацию о подключенном устройстве при отключении
          if (_lastConnectedDevice != null && 
              _lastConnectedDevice!['deviceAddress'] == address) {
            _lastConnectedDevice = null;
          }
          
          _deviceDisconnectedController.add(address);
          break;
        case 'onDataReceived':
          final data = Map<String, dynamic>.from(call.arguments);
          print('BLE Service: ===== ПОЛУЧЕНЫ ДАННЫЕ =====');
          print('BLE Service: От: ${data['deviceName']}');
          print('BLE Service: HEX: ${data['hexData']}');
          
                 // Логирование данных с расширенной информацией
                 _logger.logDataReceived(
                   data['deviceName'] ?? 'Неизвестное устройство',
                   data['deviceAddress'] ?? 'Неизвестный адрес',
                   data,
                 );
                 
                 // Логируем детальный анализ данных
                 if (data['analysis'] != null) {
                   _logger.logDataAnalysis(data['analysis']);
                 }
          
          _dataReceivedController.add(data);
          break;
        case 'onAdvertisingStarted':
          final data = Map<String, dynamic>.from(call.arguments);
          print('BLE Service: ===== РЕКЛАМАЦИЯ ЗАПУЩЕНА =====');
          print('BLE Service: Сообщение: ${data['message']}');
          break;
        default:
          print('BLE Service: Неизвестный метод channel: ${call.method}');
      }
    });
    print('BLE Service: Обработчики channel настроены');
  }

  /// Запрос необходимых разрешений
  Future<bool> _requestPermissions() async {
    try {
      // Запрашиваем все необходимые разрешения
      Map<Permission, PermissionStatus> permissions = await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.locationWhenInUse,
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();

      // Проверяем статус каждого разрешения
      bool allGranted = true;
      permissions.forEach((permission, status) {
        if (status != PermissionStatus.granted) {
          print('Разрешение ${permission.toString()} не предоставлено: $status');
          allGranted = false;
        } else {
          print('Разрешение ${permission.toString()} предоставлено');
        }
      });

      return allGranted;
    } catch (e) {
      print('Ошибка запроса разрешений: $e');
      return false;
    }
  }

  /// Инициализация периферийного сервиса
  Future<bool> initialize() async {
    try {
      // Проверяем доступность Bluetooth
      if (!await FlutterBluePlus.isAvailable) {
        return false;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return false;
      }

      return true;
    } catch (e) {
      print('Ошибка инициализации BLE периферийного сервиса: $e');
      return false;
    }
  }

  /// Запуск рекламации как фитнес-устройство
  Future<bool> startAdvertising({
    required String deviceName,
    required int heartRate,
    required int batteryLevel,
  }) async {
    try {
      if (_isAdvertising) {
        return true;
      }

      _currentHeartRate = heartRate;
      _currentBatteryLevel = batteryLevel;

      final initialized = await initialize();
      if (!initialized) {
        return false;
      }

      // Запрашиваем разрешения перед запуском рекламации
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        print('Не все разрешения предоставлены, но продолжаем попытку запуска...');
      }

      // Попробуем использовать нативную реализацию через platform channel
      try {
        final result = await _channel.invokeMethod('startAdvertising', {
          'deviceName': deviceName,
          'heartRateService': BleServiceUuids.heartRate,
          'batteryService': BleServiceUuids.battery,
          'deviceInfoService': BleServiceUuids.deviceInfo,
          'heartRate': heartRate,
          'batteryLevel': batteryLevel,
        });
        
        if (result == true) {
          _isAdvertising = true;
          _startHeartRateUpdates();
          print('BLE рекламация запущена нативно как: $deviceName');
          
          // Логирование успешного запуска
          _logger.logEmulationState(true, reason: 'Нативная BLE рекламация запущена');
        } else {
          throw Exception('Native advertising failed');
        }
      } catch (e) {
        print('Ошибка запуска нативной рекламации: $e');
        
        // Проверяем тип ошибки для более информативного сообщения
        if (e.toString().contains('PERMISSIONS_REQUIRED') || 
            e.toString().contains('PERMISSION_DENIED')) {
          print('Ошибка разрешений: требуется предоставить разрешения Bluetooth в настройках приложения');
        }
        
        // Fallback: если нативная реализация недоступна
        _isAdvertising = true;
        _startHeartRateUpdates();
        print('Используется режим симуляции - нативная реализация недоступна: $e');
      }

      return true;
    } catch (e) {
      print('Ошибка запуска рекламации: $e');
      return false;
    }
  }

  /// Остановка рекламации
  Future<void> stopAdvertising() async {
    try {
      if (!_isAdvertising) {
        return;
      }

      _heartRateTimer?.cancel();
      _heartRateTimer = null;

      // Останавливаем нативную рекламацию если она была запущена
      try {
        await _channel.invokeMethod('stopAdvertising');
      } catch (e) {
        print('Ошибка остановки нативной рекламации: $e');
      }

      _isAdvertising = false;
      
      // Логирование остановки
      _logger.logEmulationState(false, reason: 'Пользователь остановил эмуляцию');
    } catch (e) {
      print('Ошибка остановки рекламации: $e');
      _logger.logError('Ошибка остановки рекламации: $e', context: 'stopAdvertising');
    }
  }

  /// Запуск периодического обновления пульса
  void _startHeartRateUpdates() {
    _heartRateTimer?.cancel();
    _heartRateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isAdvertising) {
        timer.cancel();
        return;
      }

      // Обновляем пульс (имитируем естественные колебания)
      _updateHeartRate(_currentHeartRate);
    });
  }

  /// Обновление значения пульса и отправка уведомления
  void updateHeartRate(int heartRate) {
    _currentHeartRate = heartRate;
    _updateHeartRate(heartRate);
  }

  void _updateHeartRate(int heartRate) {
    try {
      if (_isAdvertising && !_heartRateController.isClosed) {
        // Обновляем данные через нативный channel
        _channel.invokeMethod('updateHeartRate', {'heartRate': heartRate});
        _heartRateController.add(heartRate);
      }
    } catch (e) {
      print('Ошибка обновления пульса: $e');
    }
  }

  /// Обновление уровня батареи
  void updateBatteryLevel(int batteryLevel) {
    _currentBatteryLevel = batteryLevel.clamp(0, 100);
    
    try {
      if (_isAdvertising && !_batteryController.isClosed) {
        // Обновляем данные через нативный channel
        _channel.invokeMethod('updateBatteryLevel', {'batteryLevel': _currentBatteryLevel});
        _batteryController.add(_currentBatteryLevel);
      }
    } catch (e) {
      print('Ошибка обновления батареи: $e');
    }
  }

  // Методы кодирования данных для будущей нативной реализации
  // Uint8List _encodeHeartRateMeasurement(int heartRate, bool hasSensorContact) { ... }
  // Uint8List _encodeBatteryLevel(int batteryLevel) { ... }

  /// Освобождение ресурсов
  Future<void> dispose() async {
    await stopAdvertising();
    await _heartRateController.close();
    await _batteryController.close();
    await _connectionController.close();
    await _deviceConnectedController.close();
    await _deviceDisconnectedController.close();
    await _dataReceivedController.close();
  }
}