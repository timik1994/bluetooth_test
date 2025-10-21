import 'package:equatable/equatable.dart';

abstract class BluetoothEvent extends Equatable {
  const BluetoothEvent();

  @override
  List<Object?> get props => [];
}

class StartScanEvent extends BluetoothEvent {
  const StartScanEvent();
}

class StopScanEvent extends BluetoothEvent {
  const StopScanEvent();
}

class ConnectToDeviceEvent extends BluetoothEvent {
  final String deviceId;
  
  const ConnectToDeviceEvent(this.deviceId);
  
  @override
  List<Object> get props => [deviceId];
}

class ReconnectToDeviceEvent extends BluetoothEvent {
  final String deviceId;
  
  const ReconnectToDeviceEvent(this.deviceId);
  
  @override
  List<Object> get props => [deviceId];
}

class DisconnectFromDeviceEvent extends BluetoothEvent {
  final String deviceId;
  
  const DisconnectFromDeviceEvent(this.deviceId);
  
  @override
  List<Object> get props => [deviceId];
}

class ClearLogsEvent extends BluetoothEvent {
  const ClearLogsEvent();
}

class LoadLogsEvent extends BluetoothEvent {
  const LoadLogsEvent();
}
