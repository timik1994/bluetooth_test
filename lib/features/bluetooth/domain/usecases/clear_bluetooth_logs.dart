import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

class ClearBluetoothLogs implements UseCase<void, NoParams> {
  final BluetoothRepository repository;

  ClearBluetoothLogs(this.repository);

  @override
  Future<void> call(NoParams params) async {
    await repository.clearLogs();
  }
}
