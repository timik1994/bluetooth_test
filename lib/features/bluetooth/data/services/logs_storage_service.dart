import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/bluetooth_log_entity.dart';

/// Сервис для локального сохранения и загрузки логов
class LogsStorageService {
  static final LogsStorageService _instance = LogsStorageService._internal();
  factory LogsStorageService() => _instance;
  LogsStorageService._internal();

  static const String _logsKey = 'bluetooth_logs';
  static const String _previouslyConnectedDevicesKey = 'previously_connected_devices';
  static const int _maxLogsToStore = 1000; // Максимальное количество логов для хранения

  /// Сохранение логов локально
  Future<void> saveLogs(List<BluetoothLogEntity> logs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Ограничиваем количество логов для хранения (оставляем последние N)
      final logsToSave = logs.length > _maxLogsToStore 
          ? logs.sublist(logs.length - _maxLogsToStore) 
          : logs;
      
      // Преобразуем логи в JSON
      final logsJson = logsToSave.map((log) => _logEntityToJson(log)).toList();
      
      // Сохраняем как строку JSON
      await prefs.setString(_logsKey, jsonEncode(logsJson));
      
      print('LogsStorageService: Сохранено ${logsToSave.length} логов');
    } catch (e) {
      print('LogsStorageService: Ошибка сохранения логов: $e');
    }
  }

  /// Загрузка логов из локального хранилища
  Future<List<BluetoothLogEntity>> loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJsonString = prefs.getString(_logsKey);
      
      if (logsJsonString == null || logsJsonString.isEmpty) {
        return [];
      }
      
      // Парсим JSON
      final logsJson = jsonDecode(logsJsonString) as List<dynamic>;
      
      // Преобразуем обратно в BluetoothLogEntity
      final logs = logsJson.map((json) => _logEntityFromJson(json as Map<String, dynamic>)).toList();
      
      print('LogsStorageService: Загружено ${logs.length} логов');
      return logs;
    } catch (e) {
      print('LogsStorageService: Ошибка загрузки логов: $e');
      return [];
    }
  }

  /// Очистка сохраненных логов
  Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logsKey);
      print('LogsStorageService: Логи очищены');
    } catch (e) {
      print('LogsStorageService: Ошибка очистки логов: $e');
    }
  }

  /// Сохранение списка ранее подключенных устройств
  Future<void> savePreviouslyConnectedDevices(Set<String> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_previouslyConnectedDevicesKey, devices.toList());
      print('LogsStorageService: Сохранено ${devices.length} ранее подключенных устройств');
    } catch (e) {
      print('LogsStorageService: Ошибка сохранения устройств: $e');
    }
  }

  /// Загрузка списка ранее подключенных устройств
  Future<Set<String>> loadPreviouslyConnectedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesList = prefs.getStringList(_previouslyConnectedDevicesKey);
      return devicesList?.toSet() ?? <String>{};
    } catch (e) {
      print('LogsStorageService: Ошибка загрузки устройств: $e');
      return <String>{};
    }
  }

  /// Преобразование BluetoothLogEntity в JSON
  Map<String, dynamic> _logEntityToJson(BluetoothLogEntity log) {
    return {
      'id': log.id,
      'timestamp': log.timestamp.toIso8601String(),
      'level': log.level.toString().split('.').last, // Преобразуем enum в строку
      'message': log.message,
      'deviceId': log.deviceId,
      'deviceName': log.deviceName,
      'additionalData': log.additionalData,
    };
  }

  /// Преобразование JSON в BluetoothLogEntity
  BluetoothLogEntity _logEntityFromJson(Map<String, dynamic> json) {
    return BluetoothLogEntity(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: _parseLogLevel(json['level'] as String),
      message: json['message'] as String,
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  /// Парсинг строки уровня лога в LogLevel enum
  LogLevel _parseLogLevel(String levelString) {
    switch (levelString.toLowerCase()) {
      case 'error':
        return LogLevel.error;
      case 'warning':
        return LogLevel.warning;
      case 'debug':
        return LogLevel.debug;
      case 'info':
      default:
        return LogLevel.info;
    }
  }
}

