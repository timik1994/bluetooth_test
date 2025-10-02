import 'package:equatable/equatable.dart';

class BluetoothDeviceEntity extends Equatable {
  final String id;
  final String name;
  final bool isConnected;
  final int rssi;
  final List<String> serviceUuids;
  final String deviceType;
  final bool isClassicBluetooth;
  final bool isBonded;

  const BluetoothDeviceEntity({
    required this.id,
    required this.name,
    required this.isConnected,
    required this.rssi,
    required this.serviceUuids,
    required this.deviceType,
    this.isClassicBluetooth = false,
    this.isBonded = false,
  });

  @override
  List<Object> get props => [id, name, isConnected, rssi, serviceUuids, deviceType, isClassicBluetooth, isBonded];
}
