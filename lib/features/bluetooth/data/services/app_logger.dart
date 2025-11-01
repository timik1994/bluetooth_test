import 'dart:io';
import '../../presentation/bloc/bluetooth_bloc.dart';
import '../../presentation/bloc/bluetooth_event.dart';
import '../../domain/entities/bluetooth_log_entity.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  File? _logFile;
  bool _isInitialized = false;
  BluetoothBloc? _bluetoothBloc;
  final Set<String> _loggedIds = {}; // Для отслеживания уже записанных логов

  /// Форматирование таймштампа для имени файла (безопасный формат без пробелов и двоеточий)
  String _formatTimestampForFilename(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}.'
        '${timestamp.month.toString().padLeft(2, '0')}.'
        '${timestamp.year}_'
        '${timestamp.hour.toString().padLeft(2, '0')}-'
        '${timestamp.minute.toString().padLeft(2, '0')}-'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Инициализация логгера
  Future<void> initialize({BluetoothBloc? bluetoothBloc}) async {
    if (_isInitialized) return;
    
    _bluetoothBloc = bluetoothBloc;
    
    try {
      // Используем папку Downloads для всех логов приложения
      final directory = Directory('/storage/emulated/0/Download');
      final logDir = Directory('${directory.path}/Bluetooth_App_Logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      final timestamp = _formatTimestampForFilename(DateTime.now());
      _logFile = File('${logDir.path}/bluetooth_app_$timestamp.log');
      
      await _logFile!.writeAsString('=== ЛОГИ BLUETOOTH ПРИЛОЖЕНИЯ ===\n');
      await _logFile!.writeAsString('Время запуска: ${DateTime.now()}\n');
      await _logFile!.writeAsString('Путь к логам: ${_logFile!.path}\n');
      await _logFile!.writeAsString('=====================================\n\n');
      
      _isInitialized = true;
      print('AppLogger: Логгер инициализирован: ${_logFile!.path}');
      
      // Добавляем лог в систему логов приложения
      _addToAppLogs('Система логирования приложения инициализирована. Логи: ${_logFile!.path}', LogLevel.info);
    } catch (e) {
      print('AppLogger: Ошибка инициализации: $e');
      _addToAppLogs('Ошибка инициализации системы логирования: $e', LogLevel.error);
    }
  }

  /// Установка BluetoothBloc для логирования
  void setBluetoothBloc(BluetoothBloc bluetoothBloc) {
    _bluetoothBloc = bluetoothBloc;
  }

  /// Добавление лога в систему приложения
  void _addToAppLogs(String message, LogLevel level, {String? deviceId, String? deviceName, Map<String, dynamic>? additionalData, BluetoothLogEntity? existingEntity}) {
    if (_bluetoothBloc != null) {
      final logEntity = existingEntity ?? BluetoothLogEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        level: level,
        message: message,
        deviceId: deviceId,
        deviceName: deviceName,
        additionalData: additionalData,
      );
      
      _bluetoothBloc!.add(AddLogEvent(logEntity));
    }
  }

  /// Запись лога в файл
  Future<void> log(String message, {String level = 'INFO', String? deviceId, String? deviceName, Map<String, dynamic>? additionalData}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Создаем полный лог-entity для записи в файл с детализацией
    final logLevel = _convertStringToLogLevel(level);
    final logEntity = BluetoothLogEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      level: logLevel,
      message: message,
      deviceId: deviceId,
      deviceName: deviceName,
      additionalData: additionalData,
    );
    
    // Записываем в файл с полной детализацией
    await logFromEntity(logEntity);
    
    // Добавляем в систему логов приложения, передавая существующий entity (чтобы не дублировать запись в файл)
    _addToAppLogs(message, logLevel, deviceId: deviceId, deviceName: deviceName, additionalData: additionalData, existingEntity: logEntity);
  }

  /// Конвертация строкового уровня в LogLevel
  LogLevel _convertStringToLogLevel(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR':
        return LogLevel.error;
      case 'WARNING':
        return LogLevel.warning;
      case 'DEBUG':
        return LogLevel.debug;
      default:
        return LogLevel.info;
    }
  }

  /// Форматирование таймштампа в формат DD.MM.YYYY HH:MM:SS
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}.'
        '${timestamp.month.toString().padLeft(2, '0')}.'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Статический метод для форматирования timestamp (для использования в других классах)
  static String formatTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}.'
        '${timestamp.month.toString().padLeft(2, '0')}.'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Конвертация LogLevel в строку
  String _convertLogLevelToString(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.debug:
        return 'DEBUG';
      default:
        return 'INFO';
    }
  }

  /// Запись лога из BluetoothLogEntity в файл с полной детализацией
  Future<void> logFromEntity(BluetoothLogEntity logEntity) async {
    // Проверяем, не был ли уже записан этот лог
    if (_loggedIds.contains(logEntity.id)) {
      return; // Лог уже был записан
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_logFile == null) return;
    
    try {
      final timestamp = _formatTimestamp(logEntity.timestamp);
      final level = _convertLogLevelToString(logEntity.level);
      
      // Формируем базовую строку лога
      final buffer = StringBuffer();
      buffer.writeln('[$timestamp] [$level] ${logEntity.message}');
      
      // Добавляем информацию об устройстве
      if (logEntity.deviceName != null || logEntity.deviceId != null) {
        buffer.writeln('  Устройство: ${logEntity.deviceName ?? 'Неизвестно'} (${logEntity.deviceId ?? 'Неизвестный адрес'})');
      }
      
      // Добавляем дополнительные данные, если они есть
      if (logEntity.additionalData != null && logEntity.additionalData!.isNotEmpty) {
        buffer.writeln('  Дополнительные данные:');
        try {
          // Безопасно преобразуем Map в Map<String, dynamic>
          // Используем явное приведение через as Map для обработки разных типов Map
          final data = logEntity.additionalData! as Map;
          final safeData = _convertToSafeMap(data);
          _formatAdditionalData(buffer, safeData, indent: '    ');
        } catch (e) {
          // Если произошла ошибка при форматировании, выводим как строку
          buffer.writeln('    Ошибка форматирования данных: $e');
          buffer.writeln('    Данные: ${logEntity.additionalData}');
        }
      }
      
      buffer.writeln(); // Пустая строка для разделения
      
      await _logFile!.writeAsString(buffer.toString(), mode: FileMode.append);
      
      // Помечаем лог как записанный
      _loggedIds.add(logEntity.id);
      
      // Очищаем старые ID (оставляем только последние 1000 для экономии памяти)
      if (_loggedIds.length > 1000) {
        final idsToRemove = _loggedIds.take(_loggedIds.length - 1000).toList();
        _loggedIds.removeAll(idsToRemove);
      }
    } catch (e) {
      print('AppLogger: Ошибка записи лога из entity: $e');
    }
  }

  /// Безопасное преобразование Map в Map<String, dynamic>
  Map<String, dynamic> _convertToSafeMap(Map map) {
    return Map<String, dynamic>.from(
      map.map((key, value) => MapEntry(key.toString(), _convertValue(value)))
    );
  }

  /// Преобразование значения (рекурсивно для вложенных структур)
  dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return _convertToSafeMap(value);
    } else if (value is List) {
      return value.map((item) => _convertValue(item)).toList();
    } else {
      return value;
    }
  }

  /// Форматирование дополнительных данных для файла
  void _formatAdditionalData(StringBuffer buffer, Map<String, dynamic> data, {String indent = ''}) {
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is Map) {
        buffer.writeln('$indent$key:');
        // Данные уже преобразованы в Map<String, dynamic> в _convertToSafeMap
        _formatAdditionalData(buffer, Map<String, dynamic>.from(value), indent: '$indent  ');
      } else if (value is List) {
        buffer.writeln('$indent$key:');
        for (int i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is Map) {
            buffer.writeln('$indent  [$i]:');
            // Данные уже преобразованы в Map<String, dynamic> в _convertToSafeMap
            _formatAdditionalData(buffer, Map<String, dynamic>.from(item), indent: '$indent    ');
          } else {
            buffer.writeln('$indent  [$i]: $item');
          }
        }
      } else {
        buffer.writeln('$indent$key: $value');
      }
    }
  }

  /// Логирование сканирования устройств
  Future<void> logScanning(String message, {String? deviceId, String? deviceName, Map<String, dynamic>? additionalData}) async {
    await log('🔍 СКАНИРОВАНИЕ: $message', level: 'INFO', deviceId: deviceId, deviceName: deviceName, additionalData: additionalData);
  }

  /// Логирование обнаружения устройства при сканировании
  Future<void> logDeviceDiscovered(String deviceName, String deviceAddress, int rssi, List<String> serviceUuids, {Map<String, dynamic>? additionalData}) async {
    final servicesCount = serviceUuids.length;
    final servicesInfo = serviceUuids.isNotEmpty ? serviceUuids.take(3).join(', ') + (serviceUuids.length > 3 ? '...' : '') : 'Нет сервисов';
    
    await log('📡 ОБНАРУЖЕНО: $deviceName ($deviceAddress) - RSSI: $rssi, Сервисы: $servicesCount', 
        level: 'INFO', 
        deviceId: deviceAddress, 
        deviceName: deviceName, 
        additionalData: {
          'rssi': rssi,
          'serviceUuids': serviceUuids,
          'servicesCount': servicesCount,
          'servicesInfo': servicesInfo,
          ...?additionalData,
        });
  }

  /// Логирование подключения к устройству
  Future<void> logConnection(String deviceName, String deviceAddress, {bool isConnected = true, Map<String, dynamic>? additionalData}) async {
    final status = isConnected ? 'ПОДКЛЮЧЕНИЕ' : 'ОТКЛЮЧЕНИЕ';
    final emoji = isConnected ? '🔗' : '🔌';
    await log('$emoji $status: $deviceName ($deviceAddress)', 
        level: isConnected ? 'INFO' : 'WARNING', 
        deviceId: deviceAddress, 
        deviceName: deviceName, 
        additionalData: additionalData);
  }

  /// Логирование получения данных от обычного Bluetooth устройства
  Future<void> logDataReceived(String deviceName, String deviceAddress, Map<String, dynamic> data) async {
    final hexData = data['hexData'] as String? ?? '';
    final dataSize = data['dataSize'] as int? ?? 0;
    final characteristicUuid = data['characteristicUuid'] as String? ?? 'Неизвестно';
    final serviceUuid = data['serviceUuid'] as String? ?? 'Неизвестно';
    
    await log('📊 ДАННЫЕ: От $deviceName - ${hexData.length > 20 ? '${hexData.substring(0, 20)}...' : hexData} ($dataSize байт)', 
        level: 'INFO', 
        deviceId: deviceAddress, 
        deviceName: deviceName, 
        additionalData: {
          'characteristicUuid': characteristicUuid,
          'serviceUuid': serviceUuid,
          'hexData': hexData,
          'dataSize': dataSize,
          'rawData': data['rawData'],
          'data': data['data'],
          'analysis': _analyzeBluetoothData(data),
          ...data,
        });
  }

  /// Анализ Bluetooth данных
  Map<String, dynamic> _analyzeBluetoothData(Map<String, dynamic> data) {
    final analysis = <String, dynamic>{};
    
    // Получаем сырые данные
    final rawData = data['rawData'] as List<int>?;
    if (rawData != null && rawData.isNotEmpty) {
      analysis['size'] = rawData.length;
      analysis['hex'] = rawData.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      analysis['decimal'] = rawData.join(' ');
      analysis['binary'] = rawData.map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');
      
      // Попытка декодирования как строка
      try {
        final stringValue = String.fromCharCodes(rawData);
        if (RegExp(r'^[\x20-\x7E\x0A\x0D\x09]*$').hasMatch(stringValue) && stringValue.trim().isNotEmpty) {
          analysis['utf8'] = stringValue;
        }
      } catch (e) {
        analysis['utf8'] = 'Ошибка декодирования UTF-8';
      }
      
      // Анализ по размеру
      switch (rawData.length) {
        case 1:
          analysis['interpretation'] = 'Однобайтовое значение';
          analysis['value'] = rawData[0];
          analysis['signed'] = rawData[0] > 127 ? rawData[0] - 256 : rawData[0];
          break;
        case 2:
          analysis['interpretation'] = '16-битное значение';
          analysis['littleEndian'] = (rawData[1] << 8) | rawData[0];
          analysis['bigEndian'] = (rawData[0] << 8) | rawData[1];
          break;
        case 4:
          analysis['interpretation'] = '32-битное значение';
          analysis['littleEndian'] = (rawData[3] << 24) | (rawData[2] << 16) | (rawData[1] << 8) | rawData[0];
          analysis['bigEndian'] = (rawData[0] << 24) | (rawData[1] << 16) | (rawData[2] << 8) | rawData[3];
          break;
        default:
          analysis['interpretation'] = 'Многобайтовые данные';
      }
    }
    
    return analysis;
  }

  /// Логирование ошибок
  Future<void> logError(String error, {String? context, String? deviceId, String? deviceName, Map<String, dynamic>? additionalData}) async {
    await log('❌ ОШИБКА${context != null ? ' ($context)' : ''}: $error', 
        level: 'ERROR', 
        deviceId: deviceId, 
        deviceName: deviceName, 
        additionalData: additionalData);
  }

  /// Логирование эмуляции
  Future<void> logEmulation(String message, {String level = 'INFO', Map<String, dynamic>? additionalData}) async {
    await log('🎭 ЭМУЛЯЦИЯ: $message', level: level, additionalData: additionalData);
  }

  /// Логирование состояния Bluetooth
  Future<void> logBluetoothState(String message, {String level = 'INFO', Map<String, dynamic>? additionalData}) async {
    await log('📡 BLUETOOTH: $message', level: level, additionalData: additionalData);
  }

  /// Логирование информации о сервисах устройства
  Future<void> logDeviceServices(String deviceName, String deviceAddress, List<Map<String, dynamic>> services) async {
    await log('🔍 СЕРВИСЫ: Найдено ${services.length} сервисов на $deviceName', 
        level: 'INFO', 
        deviceId: deviceAddress, 
        deviceName: deviceName,
        additionalData: {
          'services': services,
          'servicesCount': services.length,
          'servicesDetails': _formatServicesDetails(services),
        });
  }

  /// Форматирование детальной информации о сервисах для файла
  String _formatServicesDetails(List<Map<String, dynamic>> services) {
    final buffer = StringBuffer();
    buffer.writeln('=== ДЕТАЛЬНАЯ ИНФОРМАЦИЯ О СЕРВИСАХ ===');
    
    for (int i = 0; i < services.length; i++) {
      final service = services[i];
      buffer.writeln('Сервис ${i + 1}:');
      buffer.writeln('  UUID: ${service['uuid']}');
      buffer.writeln('  Тип: ${service['type'] ?? 'null'}');
      
      final characteristics = service['characteristics'] as List<Map<String, dynamic>>? ?? [];
      buffer.writeln('  Характеристики (${characteristics.length}):');
      
      for (int j = 0; j < characteristics.length; j++) {
        final char = characteristics[j];
        buffer.writeln('    ${j + 1}. UUID: ${char['uuid']}');
        buffer.writeln('       Свойства: ${char['properties']}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('==========================================');
    return buffer.toString();
  }

  /// Получение пути к файлу лога
  String? get logFilePath => _logFile?.path;

  /// Очистка старых логов (старше 7 дней)
  Future<void> cleanupOldLogs() async {
    try {
      final logDir = Directory('/storage/emulated/0/Download/Bluetooth_App_Logs');
      
      if (await logDir.exists()) {
        final files = await logDir.list().toList();
        final now = DateTime.now();
        
        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final age = now.difference(stat.modified);
            
            if (age.inDays > 7) {
              await file.delete();
              await log('Удален старый лог: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      print('AppLogger: Ошибка очистки логов: $e');
    }
  }
}
