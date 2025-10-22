import 'dart:io';
import '../../presentation/bloc/bluetooth_bloc.dart';
import '../../presentation/bloc/bluetooth_event.dart';
import '../../domain/entities/bluetooth_log_entity.dart';

class EmulationLogger {
  static final EmulationLogger _instance = EmulationLogger._internal();
  factory EmulationLogger() => _instance;
  EmulationLogger._internal();

  File? _logFile;
  bool _isInitialized = false;
  BluetoothBloc? _bluetoothBloc;

  /// Инициализация логгера
  Future<void> initialize({BluetoothBloc? bluetoothBloc}) async {
    if (_isInitialized) return;
    
    _bluetoothBloc = bluetoothBloc;
    
    try {
      // Используем папку Downloads для логов
      final directory = Directory('/storage/emulated/0/Download');
      final logDir = Directory('${directory.path}/BLE_Emulation_Logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      _logFile = File('${logDir.path}/emulation_$timestamp.log');
      
      await _logFile!.writeAsString('=== ЭМУЛЯЦИЯ BLE УСТРОЙСТВА ===\n');
      await _logFile!.writeAsString('Время запуска: ${DateTime.now()}\n');
      await _logFile!.writeAsString('Путь к логам: ${_logFile!.path}\n');
      await _logFile!.writeAsString('================================\n\n');
      
      _isInitialized = true;
      print('EmulationLogger: Логгер инициализирован: ${_logFile!.path}');
      
      // Добавляем лог в систему логов приложения
      _addToAppLogs('Эмуляция BLE устройства инициализирована. Логи: ${_logFile!.path}', LogLevel.info);
    } catch (e) {
      print('EmulationLogger: Ошибка инициализации: $e');
      _addToAppLogs('Ошибка инициализации эмуляции: $e', LogLevel.error);
    }
  }

  /// Добавление лога в систему приложения
  void _addToAppLogs(String message, LogLevel level, {String? deviceId, String? deviceName, Map<String, dynamic>? additionalData}) {
    if (_bluetoothBloc != null) {
      final logEntity = BluetoothLogEntity(
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

  /// Запись лога
  Future<void> log(String message, {String level = 'INFO'}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_logFile == null) return;
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] [$level] $message\n';
      await _logFile!.writeAsString(logEntry, mode: FileMode.append);
      print('EmulationLogger: $message');
      
      // Добавляем в систему логов приложения
      final logLevel = _convertStringToLogLevel(level);
      _addToAppLogs(message, logLevel);
    } catch (e) {
      print('EmulationLogger: Ошибка записи лога: $e');
    }
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

  /// Логирование подключения устройства
  Future<void> logDeviceConnected(String deviceName, String deviceAddress, Map<String, dynamic> details) async {
    await log('=== УСТРОЙСТВО ПОДКЛЮЧИЛОСЬ ===');
    await log('Имя: $deviceName');
    await log('Адрес: $deviceAddress');
    await log('Детали: $details');
    await log('================================');
    
    // Добавляем в систему логов приложения
    _addToAppLogs(
      'Устройство подключилось к эмулятору: $deviceName',
      LogLevel.info,
      deviceId: deviceAddress,
      deviceName: deviceName,
      additionalData: details,
    );
  }

  /// Логирование отключения устройства
  Future<void> logDeviceDisconnected(String deviceAddress) async {
    await log('=== УСТРОЙСТВО ОТКЛЮЧИЛОСЬ ===');
    await log('Адрес: $deviceAddress');
    await log('=============================');
    
    // Добавляем в систему логов приложения
    _addToAppLogs(
      'Устройство отключилось от эмулятора: $deviceAddress',
      LogLevel.warning,
      deviceId: deviceAddress,
    );
  }

         /// Логирование получения данных
         Future<void> logDataReceived(String deviceName, String deviceAddress, Map<String, dynamic> data) async {
           await log('=== ПОЛУЧЕНЫ ДАННЫЕ ===');
           await log('От: $deviceName ($deviceAddress)');
           await log('UUID характеристики: ${data['characteristicUuid']}');
           await log('UUID сервиса: ${data['serviceUuid']}');
           await log('HEX: ${data['hexData']}');
           await log('Строка: ${data['data']}');
           await log('Размер: ${data['dataSize']} байт');
           await log('Смещение: ${data['offset']}');
           await log('Подготовленная запись: ${data['preparedWrite']}');
           await log('Требуется ответ: ${data['responseNeeded']}');
           await log('======================');
           
           // Добавляем в систему логов приложения
           final hexData = data['hexData'] as String? ?? '';
           final dataSize = data['dataSize'] as int? ?? 0;
           _addToAppLogs(
             'Получены данные от $deviceName: ${hexData.length > 20 ? '${hexData.substring(0, 20)}...' : hexData} ($dataSize байт)',
             LogLevel.info,
             deviceId: deviceAddress,
             deviceName: deviceName,
             additionalData: data,
           );
         }

         /// Логирование анализа данных
         Future<void> logDataAnalysis(Map<String, dynamic> analysis) async {
           await log('=== АНАЛИЗ ДАННЫХ ===');
           await log('Интерпретация: ${analysis['interpretation']}');
           await log('HEX: ${analysis['hex']}');
           await log('Десятичное: ${analysis['decimal']}');
           await log('Двоичное: ${analysis['binary']}');
           
           if (analysis['utf8'] != null) {
             await log('UTF-8: ${analysis['utf8']}');
           }
           
           if (analysis['value'] != null) {
             await log('Значение: ${analysis['value']}');
           }
           
           if (analysis['littleEndian'] != null) {
             await log('Little Endian: ${analysis['littleEndian']}');
           }
           
           if (analysis['bigEndian'] != null) {
             await log('Big Endian: ${analysis['bigEndian']}');
           }
           
           if (analysis['type'] != null) {
             await log('Тип данных: ${analysis['type']}');
           }
           
           if (analysis['command'] != null) {
             await log('Команда: ${analysis['command']}');
           }
           
           await log('====================');
         }

  /// Логирование запуска/остановки эмуляции
  Future<void> logEmulationState(bool isStarted, {String? reason}) async {
    if (isStarted) {
      await log('=== ЭМУЛЯЦИЯ ЗАПУЩЕНА ===');
      await log('Время: ${DateTime.now()}');
      if (reason != null) await log('Причина: $reason');
      await log('========================');
      
      // Добавляем в систему логов приложения
      _addToAppLogs(
        'Эмуляция BLE устройства запущена${reason != null ? ': $reason' : ''}',
        LogLevel.info,
        additionalData: {'reason': reason, 'timestamp': DateTime.now().toIso8601String()},
      );
    } else {
      await log('=== ЭМУЛЯЦИЯ ОСТАНОВЛЕНА ===');
      await log('Время: ${DateTime.now()}');
      if (reason != null) await log('Причина: $reason');
      await log('============================');
      
      // Добавляем в систему логов приложения
      _addToAppLogs(
        'Эмуляция BLE устройства остановлена${reason != null ? ': $reason' : ''}',
        LogLevel.warning,
        additionalData: {'reason': reason, 'timestamp': DateTime.now().toIso8601String()},
      );
    }
  }

  /// Логирование ошибок
  Future<void> logError(String error, {String? context}) async {
    await log('=== ОШИБКА ===', level: 'ERROR');
    if (context != null) await log('Контекст: $context', level: 'ERROR');
    await log('Ошибка: $error', level: 'ERROR');
    await log('===============', level: 'ERROR');
    
    // Добавляем в систему логов приложения
    _addToAppLogs(
      'Ошибка эмуляции${context != null ? ' ($context)' : ''}: $error',
      LogLevel.error,
      additionalData: {'context': context, 'error': error},
    );
  }

  /// Получение пути к файлу лога
  String? get logFilePath => _logFile?.path;

  /// Очистка старых логов (старше 7 дней)
  Future<void> cleanupOldLogs() async {
    try {
      final logDir = Directory('/storage/emulated/0/Download/BLE_Emulation_Logs');
      
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
      print('EmulationLogger: Ошибка очистки логов: $e');
    }
  }
}
