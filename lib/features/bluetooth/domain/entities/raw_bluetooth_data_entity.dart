import 'package:equatable/equatable.dart';

/// Сущность для хранения сырых Bluetooth данных
class RawBluetoothDataEntity extends Equatable {
  final String id;
  final DateTime timestamp;
  final String deviceId;
  final String deviceName;
  final String eventType; // 'scan_result', 'service_discovered', 'characteristic_read', 'notification_received', etc.
  final Map<String, dynamic> rawData;
  final List<int>? bytesData;
  final String? serviceUuid;
  final String? characteristicUuid;
  final BluetoothEventType eventCategory;

  const RawBluetoothDataEntity({
    required this.id,
    required this.timestamp,
    required this.deviceId,
    required this.deviceName,
    required this.eventType,
    required this.rawData,
    this.bytesData,
    this.serviceUuid,
    this.characteristicUuid,
    required this.eventCategory,
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        deviceId,
        deviceName,
        eventType,
        rawData,
        bytesData,
        serviceUuid,
        characteristicUuid,
        eventCategory,
      ];

  /// Форматированные байты для отображения
  String get formattedBytes {
    if (bytesData == null || bytesData!.isEmpty) return 'Нет данных';
    return bytesData!.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  /// Форматированные байты в десятичном формате
  String get formattedBytesDecimal {
    if (bytesData == null || bytesData!.isEmpty) return 'Нет данных';
    return bytesData!.join(' ');
  }

  /// Попытка декодировать данные как UTF-8
  String get decodedString {
    if (bytesData == null || bytesData!.isEmpty) return '';
    try {
      return String.fromCharCodes(bytesData!);
    } catch (e) {
      return 'Не удалось декодировать';
    }
  }
}

enum BluetoothEventType {
  scanResult('Результат сканирования'),
  advertisement('Рекламные данные'),
  serviceDiscovered('Обнаружен сервис'),
  characteristicRead('Чтение характеристики'),
  characteristicWritten('Запись в характеристику'),
  notificationReceived('Получено уведомление'),
  indicationReceived('Получено указание'),
  connectionStateChanged('Изменение состояния подключения'),
  error('Ошибка'),
  other('Другое');

  const BluetoothEventType(this.displayName);
  final String displayName;
}
