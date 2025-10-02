import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/entities/bluetooth_log_entity.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../datasources/bluetooth_simple_datasource.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final BluetoothSimpleDataSource localDataSource;

  BluetoothRepositoryImpl({required this.localDataSource});

  @override
  Stream<List<BluetoothDeviceEntity>> get discoveredDevices => 
      localDataSource.discoveredDevices;

  @override
  Stream<BluetoothLogEntity> get logs => localDataSource.logs;

  @override
  Stream<bool> get isScanning => localDataSource.isScanning;

  @override
  Stream<bool> get isBluetoothEnabled => localDataSource.isBluetoothEnabled;

  @override
  Future<bool> isBluetoothAvailable() => localDataSource.isBluetoothAvailable();

  @override
  Future<bool> requestPermissions() => localDataSource.requestPermissions();

  @override
  Future<void> startScan() => localDataSource.startScan();

  @override
  Future<void> stopScan() => localDataSource.stopScan();

  @override
  Future<bool> connectToDevice(String deviceId) => 
      localDataSource.connectToDevice(deviceId);

  @override
  Future<bool> reconnectToDevice(String deviceId) async {
    await localDataSource.disconnectFromDevice(deviceId);
    return localDataSource.connectToDevice(deviceId);
  }

  @override
  Future<void> disconnectFromDevice(String deviceId) => 
      localDataSource.disconnectFromDevice(deviceId);

  @override
  Future<void> clearLogs() => localDataSource.clearLogs();

  @override
  Future<List<BluetoothLogEntity>> getLogs() => localDataSource.getLogs();
}
