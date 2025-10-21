import '../../../../core/usecases/usecase.dart';
import '../repositories/bluetooth_repository.dart';

class StopBluetoothScan implements UseCase<void, NoParams> {
  final BluetoothRepository repository;

  StopBluetoothScan(this.repository);

  @override
  Future<void> call(NoParams params) async {
    await repository.stopScan();
  }
}
