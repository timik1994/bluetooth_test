import 'package:equatable/equatable.dart';
import '../../../bluetooth/domain/entities/bluetooth_device_entity.dart';

/// Расширенная сущность для фитнес-оборудования
class FitnessDeviceEntity extends Equatable {
  final BluetoothDeviceEntity bluetoothDevice;
  final FitnessDeviceType deviceType;
  final String manufacturer; // Technogym, Precor, etc.
  final List<String> supportedMetrics; // Поддерживаемые метрики
  final bool isConnected;
  final DateTime? lastDataReceived;

  const FitnessDeviceEntity({
    required this.bluetoothDevice,
    required this.deviceType,
    required this.manufacturer,
    required this.supportedMetrics,
    required this.isConnected,
    this.lastDataReceived,
  });

  @override
  List<Object?> get props => [
        bluetoothDevice,
        deviceType,
        manufacturer,
        supportedMetrics,
        isConnected,
        lastDataReceived,
      ];

  String get id => bluetoothDevice.id;
  String get name => bluetoothDevice.name;
  String get deviceTypeName => deviceType.displayName;
}

enum FitnessDeviceType {
  treadmill('Беговая дорожка'),
  bike('Велотренажер'),
  elliptical('Эллиптический тренажер'),
  rowingMachine('Гребной тренажер'),
  stepper('Степпер'),
  unknown('Неизвестный тренажер');

  const FitnessDeviceType(this.displayName);
  final String displayName;
}
