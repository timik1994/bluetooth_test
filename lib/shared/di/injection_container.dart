import 'package:get_it/get_it.dart';
import '../../features/bluetooth/data/datasources/bluetooth_simple_datasource.dart';
import '../../features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import '../../features/bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../features/bluetooth/domain/usecases/start_bluetooth_scan.dart';
import '../../features/bluetooth/domain/usecases/stop_bluetooth_scan.dart';
import '../../features/bluetooth/domain/usecases/connect_to_device.dart';
import '../../features/bluetooth/domain/usecases/get_bluetooth_logs.dart';
import '../../features/bluetooth/domain/usecases/clear_bluetooth_logs.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_bloc.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // BLoC
  sl.registerFactory(
    () => BluetoothBloc(
      startBluetoothScan: sl(),
      stopBluetoothScan: sl(),
      connectToDevice: sl(),
      getBluetoothLogs: sl(),
      clearBluetoothLogs: sl(),
      bluetoothRepository: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => StartBluetoothScan(sl()));
  sl.registerLazySingleton(() => StopBluetoothScan(sl()));
  sl.registerLazySingleton(() => ConnectToDevice(sl()));
  sl.registerLazySingleton(() => GetBluetoothLogs(sl()));
  sl.registerLazySingleton(() => ClearBluetoothLogs(sl()));

  // Repository
  sl.registerLazySingleton<BluetoothRepository>(
    () => BluetoothRepositoryImpl(localDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<BluetoothSimpleDataSource>(
    () => BluetoothSimpleDataSourceImpl(),
  );
}
