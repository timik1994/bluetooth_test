import '../entities/bluetooth_device_entity.dart';
import '../entities/bluetooth_log_entity.dart';

abstract class BluetoothRepository {
  Stream<List<BluetoothDeviceEntity>> get discoveredDevices;
  Stream<BluetoothLogEntity> get logs;
  Stream<bool> get isScanning;
  Stream<bool> get isBluetoothEnabled;
  
  Future<bool> isBluetoothAvailable();
  Future<bool> requestPermissions();
  Future<void> startScan();
  Future<void> stopScan();
  Future<bool> connectToDevice(String deviceId);
  Future<bool> reconnectToDevice(String deviceId);
  Future<void> disconnectFromDevice(String deviceId);
  Future<void> clearLogs();
  Future<List<BluetoothLogEntity>> getLogs();
}
