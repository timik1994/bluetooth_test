import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

class StartBluetoothScan implements UseCase<void, NoParams> {
  final BluetoothRepository repository;

  StartBluetoothScan(this.repository);

  @override
  Future<void> call(NoParams params) async {
    final isAvailable = await repository.isBluetoothAvailable();
    if (!isAvailable) {
      throw const BluetoothFailure('Bluetooth недоступен');
    }

    final hasPermissions = await repository.requestPermissions();
    if (!hasPermissions) {
      throw const PermissionFailure('Нет разрешений для работы с Bluetooth');
    }

    await repository.startScan();
  }
}
