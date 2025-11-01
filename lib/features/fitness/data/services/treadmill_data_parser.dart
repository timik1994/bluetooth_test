import 'dart:typed_data';
import '../../domain/entities/treadmill_data_entity.dart';
import 'treadmill_protocols/technogym_protocol.dart';

/// Универсальный парсер данных беговых дорожек
/// Поддерживает различные протоколы и форматы данных
class TreadmillDataParser {
  /// Парсит данные от беговой дорожки из различных форматов
  /// 
  /// [data] - может быть Uint8List, List<int>, Map<String, dynamic> с hexData или rawData
  /// [deviceName] - имя устройства для определения протокола
  /// [characteristicUuid] - UUID характеристики для определения типа данных
  /// 
  /// Возвращает null если данные не могут быть распарсены
  /// Бросает исключение только при критических ошибках
  static TreadmillDataEntity? parseData(
    dynamic data, {
    String? deviceName,
    String? characteristicUuid,
  }) {
    try {
      Uint8List? bytesData;
      
      // Конвертируем различные форматы данных в Uint8List
      if (data is Uint8List) {
        bytesData = data;
      } else if (data is List<int>) {
        bytesData = Uint8List.fromList(data);
      } else if (data is Map<String, dynamic>) {
        // Пытаемся извлечь данные из Map
        if (data['rawData'] is List<int>) {
          bytesData = Uint8List.fromList(data['rawData'] as List<int>);
        } else if (data['hexData'] is String) {
          // Конвертируем HEX строку в байты
          bytesData = _hexStringToBytes(data['hexData'] as String);
        } else if (data['data'] is List<int>) {
          bytesData = Uint8List.fromList(data['data'] as List<int>);
        } else if (data['bytes'] is List<int>) {
          bytesData = Uint8List.fromList(data['bytes'] as List<int>);
        }
      } else if (data is String) {
        // Пытаемся интерпретировать строку как HEX
        bytesData = _hexStringToBytes(data);
      }
      
      if (bytesData == null || bytesData.isEmpty) {
        return null;
      }
      
      // Определяем протокол по имени устройства или UUID
      final protocol = _detectProtocol(deviceName, characteristicUuid);
      
      // Парсим данные в зависимости от протокола
      try {
        switch (protocol) {
          case TreadmillProtocol.technogym:
            return TechnogymProtocol.parseTreadmillData(bytesData);
          case TreadmillProtocol.genericFitnessMachine:
            return _parseGenericFitnessMachine(bytesData);
          case TreadmillProtocol.unknown:
          default:
            // Пытаемся определить формат данных автоматически
            return _parseGenericFormat(bytesData);
        }
      } catch (e) {
        print('TreadmillDataParser: Ошибка парсинга протокола $protocol: $e');
        // Пытаемся использовать универсальный парсер
        return _parseGenericFormat(bytesData);
      }
    } catch (e) {
      print('TreadmillDataParser: Критическая ошибка парсинга данных: $e');
      return null;
    }
  }
  
  /// Конвертирует HEX строку в Uint8List
  static Uint8List? _hexStringToBytes(String hexString) {
    try {
      // Убираем пробелы и разделители
      final cleanHex = hexString.replaceAll(RegExp(r'[\s\-:]'), '').toUpperCase();
      
      // Проверяем, что строка содержит только HEX символы
      if (!RegExp(r'^[0-9A-F]+$').hasMatch(cleanHex)) {
        return null;
      }
      
      // Конвертируем по два символа в байт
      final bytes = <int>[];
      for (int i = 0; i < cleanHex.length; i += 2) {
        if (i + 1 < cleanHex.length) {
          final byteValue = int.parse(cleanHex.substring(i, i + 2), radix: 16);
          bytes.add(byteValue);
        }
      }
      
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('TreadmillDataParser: Ошибка конвертации HEX: $e');
      return null;
    }
  }
  
  /// Определяет протокол по имени устройства или UUID
  static TreadmillProtocol _detectProtocol(String? deviceName, String? characteristicUuid) {
    if (deviceName != null) {
      final name = deviceName.toLowerCase();
      if (name.contains('technogym') || name.contains('run')) {
        return TreadmillProtocol.technogym;
      }
    }
    
    if (characteristicUuid != null) {
      final uuid = characteristicUuid.toLowerCase();
      // Fitness Machine Service UUID содержит 1826
      if (uuid.contains('1826') || uuid.contains('2acd') || uuid.contains('2acc')) {
        return TreadmillProtocol.genericFitnessMachine;
      }
    }
    
    return TreadmillProtocol.unknown;
  }
  
  /// Парсит данные по стандарту Generic Fitness Machine Service
  static TreadmillDataEntity? _parseGenericFitnessMachine(Uint8List data) {
    try {
      if (data.length < 2) {
        print('TreadmillDataParser: Данные слишком короткие (${data.length} байт)');
        return null;
      }
      
      // Читаем флаги (первые 2 байта, little-endian)
      final flags = data[0] | (data[1] << 8);
      
      int offset = 2;
      double? speed;
      double? distance;
      double? incline;
      int? heartRate;
      int? calories;
      Duration? elapsedTime;
      bool isRunning = false;
      
      // Бит 0: More Data
      // Бит 1: Average Speed present
      // Бит 2: Instantaneous Speed present
      if ((flags & 0x04) != 0 && offset + 2 <= data.length) {
        try {
          // Instantaneous Speed (uint16, 0.01 km/h, little-endian)
          final speedRaw = data[offset] | (data[offset + 1] << 8);
          speed = speedRaw / 100.0;
          // Валидация: скорость должна быть в разумных пределах
          if (speed! < 0 || speed > 30) {
            print('TreadmillDataParser: Подозрительная скорость: $speed км/ч');
            speed = null;
          } else {
            offset += 2;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга скорости: $e');
        }
      }
      
      // Бит 3: Average Distance present
      // Бит 4: Instantaneous Distance present
      if ((flags & 0x10) != 0 && offset + 2 <= data.length) {
        try {
          // Instantaneous Distance (uint16, meters, little-endian)
          final distanceRaw = data[offset] | (data[offset + 1] << 8);
          distance = distanceRaw / 1.0; // метры
          // Валидация: дистанция должна быть положительной
          if (distance! < 0 || distance > 100000) {
            print('TreadmillDataParser: Подозрительная дистанция: $distance м');
            distance = null;
          } else {
            offset += 2;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга дистанции: $e');
        }
      }
      
      // Бит 5: Total Distance present
      if ((flags & 0x20) != 0 && offset + 3 <= data.length) {
        try {
          // Total Distance (uint24, meters, little-endian)
          final distanceRaw = data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16);
          final totalDistance = distanceRaw / 1.0; // метры
          // Используем общую дистанцию если она больше текущей
          if (distance == null || totalDistance > distance) {
            distance = totalDistance;
          }
          // Валидация
          if (distance! < 0 || distance > 100000) {
            print('TreadmillDataParser: Подозрительная общая дистанция: $distance м');
            distance = null;
          } else {
            offset += 3;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга общей дистанции: $e');
        }
      }
      
      // Бит 6: Elevation Gain present
      // Бит 7: Inclination and Ramp Angle present
      if ((flags & 0x80) != 0 && offset + 2 <= data.length) {
        try {
          // Inclination (sint16, 0.1%, little-endian)
          final inclineRaw = data[offset] | (data[offset + 1] << 8);
          if (inclineRaw > 32767) {
            incline = (inclineRaw - 65536) / 10.0; // Отрицательное значение
          } else {
            incline = inclineRaw / 10.0;
          }
          // Валидация: наклон должен быть в разумных пределах
          if (incline! < -30 || incline > 30) {
            print('TreadmillDataParser: Подозрительный наклон: $incline%');
            incline = null;
          } else {
            offset += 2;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга наклона: $e');
        }
      }
      
      // Бит 8: Resistance Level present
      // Бит 9: Instantaneous Pace present
      // Бит 10: Average Pace present
      // Бит 11: Expended Energy present
      if ((flags & 0x800) != 0 && offset + 2 <= data.length) {
        try {
          // Total Energy (uint16, kcal, little-endian)
          final caloriesRaw = data[offset] | (data[offset + 1] << 8);
          calories = caloriesRaw;
          // Валидация: калории должны быть положительными
          if (calories! < 0 || calories > 10000) {
            print('TreadmillDataParser: Подозрительное количество калорий: $calories');
            calories = null;
          } else {
            offset += 2;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга калорий: $e');
        }
      }
      
      // Бит 12: Heart Rate present
      if ((flags & 0x1000) != 0 && offset + 1 <= data.length) {
        try {
          heartRate = data[offset];
          // Валидация: пульс должен быть в разумных пределах
          if (heartRate! < 30 || heartRate > 250) {
            print('TreadmillDataParser: Подозрительный пульс: $heartRate уд/мин');
            heartRate = null;
          } else {
            offset += 1;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга пульса: $e');
        }
      }
      
      // Бит 13: Elapsed Time present
      if ((flags & 0x2000) != 0 && offset + 2 <= data.length) {
        try {
          // Elapsed Time (uint16, seconds, little-endian)
          final timeRaw = data[offset] | (data[offset + 1] << 8);
          elapsedTime = Duration(seconds: timeRaw);
          // Валидация: время должно быть разумным
          if (elapsedTime!.inHours > 24) {
            print('TreadmillDataParser: Подозрительное время тренировки: ${elapsedTime.inHours}ч');
            elapsedTime = null;
          } else {
            offset += 2;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга времени: $e');
        }
      }
      
      // Определяем, бежит ли пользователь
      isRunning = speed != null && speed > 0.5;
      
      // Проверяем, что хотя бы одно поле было успешно распарсено
      if (speed == null && distance == null && incline == null && 
          heartRate == null && calories == null && elapsedTime == null) {
        print('TreadmillDataParser: Не удалось распарсить ни одно поле из данных');
        return null;
      }
      
      return TreadmillDataEntity(
        speed: speed,
        distance: distance,
        incline: incline,
        heartRate: heartRate,
        calories: calories,
        elapsedTime: elapsedTime,
        isRunning: isRunning,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('TreadmillDataParser: Критическая ошибка парсинга Generic Fitness Machine: $e');
      print('TreadmillDataParser: Данные (HEX): ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return null;
    }
  }
  
  /// Универсальный парсер для неизвестных форматов
  /// Пытается извлечь данные из различных позиций байтов
  static TreadmillDataEntity? _parseGenericFormat(Uint8List data) {
    try {
      if (data.length < 2) {
        print('TreadmillDataParser: Данные слишком короткие для универсального парсинга');
        return null;
      }
      
      double? speed;
      double? distance;
      int? heartRate;
      double? incline;
      int? calories;
      Duration? elapsedTime;
      bool isRunning = false;
      
      // Попытка 1: Первые байты могут быть скоростью (little-endian)
      if (data.length >= 2) {
        try {
          final speedRaw = data[0] | (data[1] << 8);
          // Пробуем разные масштабы
          final speed1 = speedRaw / 100.0; // 0.01 км/ч
          final speed2 = speedRaw / 10.0;  // 0.1 км/ч
          final speed3 = speedRaw / 1.0;    // 1 км/ч
          
          // Выбираем наиболее правдоподобное значение
          if (speed1 > 0 && speed1 <= 30) {
            speed = speed1;
          } else if (speed2 > 0 && speed2 <= 30) {
            speed = speed2;
          } else if (speed3 > 0 && speed3 <= 30) {
            speed = speed3;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга скорости в универсальном формате: $e');
        }
      }
      
      // Попытка 2: Средние байты могут быть дистанцией
      if (data.length >= 5) {
        try {
          // Little-endian
          final distanceRaw = data[2] | (data[3] << 8) | (data[4] << 16);
          // Пробуем разные масштабы
          final dist1 = distanceRaw / 1.0;   // метры
          final dist2 = distanceRaw / 100.0; // км
          final dist3 = distanceRaw / 10.0;   // дециметры
          
          if (dist1 >= 0 && dist1 < 100000) {
            distance = dist1;
          } else if (dist2 >= 0 && dist2 < 100) {
            distance = dist2 * 1000; // конвертируем в метры
          } else if (dist3 >= 0 && dist3 < 10000) {
            distance = dist3 / 10.0; // конвертируем в метры
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга дистанции в универсальном формате: $e');
        }
      }
      
      // Попытка 3: Байты могут быть наклоном
      if (data.length >= 4) {
        try {
          final inclineRaw = data[2] | (data[3] << 8);
          if (inclineRaw > 32767) {
            incline = (inclineRaw - 65536) / 10.0;
          } else {
            incline = inclineRaw / 10.0;
          }
          // Валидация
          if (incline! < -30 || incline > 30) {
            incline = null;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга наклона в универсальном формате: $e');
        }
      }
      
      // Попытка 4: Последний байт может быть пульсом
      if (data.length >= 1) {
        try {
          final hr = data[data.length - 1];
          if (hr >= 50 && hr <= 220) {
            heartRate = hr;
          }
        } catch (e) {
          print('TreadmillDataParser: Ошибка парсинга пульса в универсальном формате: $e');
        }
      }
      
      // Попытка 5: Средние байты могут быть калориями
      if (data.length >= 4) {
        try {
          final caloriesRaw = data[data.length - 2] | (data[data.length - 1] << 8);
          if (caloriesRaw >= 0 && caloriesRaw < 10000) {
            calories = caloriesRaw;
          }
        } catch (e) {
          // Игнорируем ошибки для калорий
        }
      }
      
      // Попытка 6: Время может быть в средних байтах
      if (data.length >= 4) {
        try {
          final timeRaw = data[0] | (data[1] << 8);
          if (timeRaw > 0 && timeRaw < 86400) { // меньше суток
            elapsedTime = Duration(seconds: timeRaw);
          }
        } catch (e) {
          // Игнорируем ошибки для времени
        }
      }
      
      isRunning = speed != null && speed > 0.5;
      
      // Проверяем, что хотя бы одно поле было успешно распарсено
      if (speed == null && distance == null && incline == null && 
          heartRate == null && calories == null && elapsedTime == null) {
        print('TreadmillDataParser: Не удалось распарсить данные в универсальном формате');
        print('TreadmillDataParser: Данные (HEX): ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        return null;
      }
      
      return TreadmillDataEntity(
        speed: speed,
        distance: distance,
        incline: incline,
        heartRate: heartRate,
        calories: calories,
        elapsedTime: elapsedTime,
        isRunning: isRunning,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('TreadmillDataParser: Критическая ошибка парсинга Generic Format: $e');
      print('TreadmillDataParser: Данные (HEX): ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return null;
    }
  }
}

/// Типы протоколов беговых дорожек
enum TreadmillProtocol {
  technogym,
  genericFitnessMachine,
  unknown,
}

