import 'dart:typed_data';
import '../../../domain/entities/treadmill_data_entity.dart';

/// Протокол для работы с беговыми дорожками Technogym
class TechnogymProtocol {
  // UUID сервисов и характеристик Technogym (это примерные значения, нужно изучить документацию)
  static const String fitnessMachineServiceUuid = '00001826-0000-1000-8000-00805f9b34fb';
  static const String fitnessMachineFeatureCharUuid = '00002acc-0000-1000-8000-00805f9b34fb';
  static const String treadmillDataCharUuid = '00002acd-0000-1000-8000-00805f9b34fb';
  static const String fitnessMachineControlPointCharUuid = '00002ad9-0000-1000-8000-00805f9b34fb';

  /// Парсит данные от беговой дорожки Technogym
  static TreadmillDataEntity? parseTreadmillData(Uint8List data) {
    try {
      if (data.length < 2) return null;

      // Первые два байта содержат флаги
      final flags = (data[0] << 8) | data[1];
      
      int offset = 2;
      double? speed;
      double? distance;
      double? incline;
      int? heartRate;
      int? calories;
      Duration? elapsedTime;
      bool isRunning = false;

      // Скорость (если бит установлен)
      if ((flags & 0x01) != 0 && offset + 2 <= data.length) {
        final speedRaw = (data[offset] << 8) | data[offset + 1];
        speed = speedRaw / 100.0; // Обычно в 0.01 км/ч
        offset += 2;
      }

      // Дистанция (если бит установлен)
      if ((flags & 0x02) != 0 && offset + 3 <= data.length) {
        final distanceRaw = (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];
        distance = distanceRaw / 100.0; // Обычно в метрах
        offset += 3;
      }

      // Наклон (если бит установлен)
      if ((flags & 0x04) != 0 && offset + 2 <= data.length) {
        final inclineRaw = (data[offset] << 8) | data[offset + 1];
        incline = inclineRaw / 10.0; // Обычно в 0.1%
        offset += 2;
      }

      // Пульс (если бит установлен)
      if ((flags & 0x10) != 0 && offset + 1 <= data.length) {
        heartRate = data[offset];
        offset += 1;
      }

      // Время тренировки (если бит установлен)
      if ((flags & 0x08) != 0 && offset + 2 <= data.length) {
        final timeRaw = (data[offset] << 8) | data[offset + 1];
        elapsedTime = Duration(seconds: timeRaw);
        offset += 2;
      }

      // Определяем, бежит ли пользователь (скорость > 0.5 км/ч)
      isRunning = speed != null && speed > 0.5;

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
      // Логируем ошибку парсинга
      return null;
    }
  }

  /// Определяет, является ли устройство беговой дорожкой Technogym
  static bool isTechnogymTreadmill(String deviceName, List<String> serviceUuids) {
    final name = deviceName.toLowerCase();
    
    // Проверяем по названию устройства
    final isTechnogym = name.contains('technogym') || 
                       name.contains('run') ||
                       name.contains('treadmill');
    
    // Проверяем по UUID сервисов (Fitness Machine Service)
    final hasFitnessService = serviceUuids.any((uuid) => 
      uuid.toLowerCase().contains('1826') || // Fitness Machine Service
      uuid.toLowerCase().contains(fitnessMachineServiceUuid));

    return isTechnogym && hasFitnessService;
  }

}
