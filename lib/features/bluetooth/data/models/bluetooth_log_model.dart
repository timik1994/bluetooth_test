import '../../domain/entities/bluetooth_log_entity.dart';

class BluetoothLogModel extends BluetoothLogEntity {
  const BluetoothLogModel({
    required super.id,
    required super.timestamp,
    required super.level,
    required super.message,
    super.deviceId,
    super.deviceName,
    super.additionalData,
  });

  factory BluetoothLogModel.create({
    required LogLevel level,
    required String message,
    String? deviceId,
    String? deviceName,
    Map<String, dynamic>? additionalData,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return BluetoothLogModel(
      id: now.millisecondsSinceEpoch.toString(),
      timestamp: now,
      level: level,
      message: message,
      deviceId: deviceId,
      deviceName: deviceName,
      additionalData: additionalData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'additionalData': additionalData,
    };
  }

  factory BluetoothLogModel.fromJson(Map<String, dynamic> json) {
    return BluetoothLogModel(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      message: json['message'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      additionalData: json['additionalData'],
    );
  }
}
