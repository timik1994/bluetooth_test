import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

class ConnectToDevice implements UseCase<bool, String> {
  final BluetoothRepository repository;

  ConnectToDevice(this.repository);

  @override
  Future<bool> call(String deviceId) async {
    if (deviceId.isEmpty) {
      throw const ConnectionFailure('ID устройства не может быть пустым');
    }

    return await repository.connectToDevice(deviceId);
  }
}
