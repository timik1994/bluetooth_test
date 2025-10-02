import '../../../../core/usecases/usecase.dart';
import '../entities/bluetooth_log_entity.dart';
import '../repositories/bluetooth_repository.dart';

class GetBluetoothLogs implements UseCase<List<BluetoothLogEntity>, NoParams> {
  final BluetoothRepository repository;

  GetBluetoothLogs(this.repository);

  @override
  Future<List<BluetoothLogEntity>> call(NoParams params) async {
    return await repository.getLogs();
  }
}
