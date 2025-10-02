import 'package:equatable/equatable.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/entities/bluetooth_log_entity.dart';

class BluetoothState extends Equatable {
  final bool isLoading;
  final bool isScanning;
  final bool isBluetoothEnabled;
  final List<BluetoothDeviceEntity> discoveredDevices;
  final List<BluetoothLogEntity> logs;
  final String? errorMessage;
  final String? successMessage;
  final Set<String> connectingDevices; // ID устройств, которые подключаются
  final Set<String> connectedDevices; // ID текущих подключенных устройств
  final Set<String> previouslyConnectedDevices; // ID ранее подключенных устройств

  const BluetoothState({
    this.isLoading = false,
    this.isScanning = false,
    this.isBluetoothEnabled = false,
    this.discoveredDevices = const [],
    this.logs = const [],
    this.errorMessage,
    this.successMessage,
    this.connectingDevices = const {},
    this.connectedDevices = const {},
    this.previouslyConnectedDevices = const {},
  });

  BluetoothState copyWith({
    bool? isLoading,
    bool? isScanning,
    bool? isBluetoothEnabled,
    List<BluetoothDeviceEntity>? discoveredDevices,
    List<BluetoothLogEntity>? logs,
    String? errorMessage,
    String? successMessage,
    Set<String>? connectingDevices,
    Set<String>? connectedDevices,
    Set<String>? previouslyConnectedDevices,
  }) {
    return BluetoothState(
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      logs: logs ?? this.logs,
      errorMessage: errorMessage,
      successMessage: successMessage,
      connectingDevices: connectingDevices ?? this.connectingDevices,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      previouslyConnectedDevices: previouslyConnectedDevices ?? this.previouslyConnectedDevices,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isScanning,
        isBluetoothEnabled,
        discoveredDevices,
        logs,
        errorMessage,
        successMessage,
        connectingDevices,
        connectedDevices,
        previouslyConnectedDevices,
      ];
}
