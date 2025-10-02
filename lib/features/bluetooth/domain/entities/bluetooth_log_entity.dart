import 'package:equatable/equatable.dart';

enum LogLevel {
  info,
  warning,
  error,
  debug,
}

class BluetoothLogEntity extends Equatable {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? deviceId;
  final String? deviceName;
  final Map<String, dynamic>? additionalData;

  const BluetoothLogEntity({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.deviceId,
    this.deviceName,
    this.additionalData,
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        level,
        message,
        deviceId,
        deviceName,
        additionalData,
      ];
}
