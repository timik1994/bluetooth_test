import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/start_bluetooth_scan.dart';
import '../../domain/usecases/stop_bluetooth_scan.dart';
import '../../domain/usecases/connect_to_device.dart';
import '../../domain/usecases/get_bluetooth_logs.dart';
import '../../domain/usecases/clear_bluetooth_logs.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/entities/bluetooth_log_entity.dart';
import '../../data/services/app_logger.dart';
import '../../../../core/usecases/usecase.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  final StartBluetoothScan startBluetoothScan;
  final StopBluetoothScan stopBluetoothScan;
  final ConnectToDevice connectToDevice;
  final GetBluetoothLogs getBluetoothLogs;
  final ClearBluetoothLogs clearBluetoothLogs;
  final BluetoothRepository bluetoothRepository;
  final AppLogger _appLogger = AppLogger();

  StreamSubscription<List<BluetoothDeviceEntity>>? _devicesSubscription;
  StreamSubscription<BluetoothLogEntity>? _logsSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<bool>? _bluetoothEnabledSubscription;

  BluetoothBloc({
    required this.startBluetoothScan,
    required this.stopBluetoothScan,
    required this.connectToDevice,
    required this.getBluetoothLogs,
    required this.clearBluetoothLogs,
    required this.bluetoothRepository,
  }) : super(const BluetoothState()) {
    on<StartScanEvent>(_onStartScan);
    on<StopScanEvent>(_onStopScan);
    on<ConnectToDeviceEvent>(_onConnectToDevice);
    on<ReconnectToDeviceEvent>(_onReconnectToDevice);
    on<DisconnectFromDeviceEvent>(_onDisconnectFromDevice);
    on<ClearLogsEvent>(_onClearLogs);
    on<LoadLogsEvent>(_onLoadLogs);
    on<ToggleShowAllDevicesEvent>(_onToggleShowAllDevices);
    on<AddLogEvent>(_onAddLog);

    _initializeStreams();
    _initializeLogger();
  }

  /// Инициализация логгера
  void _initializeLogger() {
    _appLogger.initialize(bluetoothBloc: this);
  }

  void _initializeStreams() {
    try {
      // Слушаем найденные устройства
      _devicesSubscription = bluetoothRepository.discoveredDevices.listen(
        (devices) {
          if (!isClosed) {
            print('BLoC: Получено ${devices.length} устройств, обновляем UI');
            emit(state.copyWith(discoveredDevices: devices));
          }
        },
        onError: (error) {
          if (!isClosed) {
            print('BLoC: Ошибка получения устройств: $error');
            emit(state.copyWith(errorMessage: 'Ошибка получения устройств: $error'));
          }
        },
      );

      // Слушаем логи
      _logsSubscription = bluetoothRepository.logs.listen(
        (log) {
          if (!isClosed) {
            final updatedLogs = List<BluetoothLogEntity>.from(state.logs)..add(log);
            emit(state.copyWith(logs: updatedLogs));
          }
        },
        onError: (error) {
          if (!isClosed) {
            emit(state.copyWith(errorMessage: 'Ошибка получения логов: $error'));
          }
        },
      );

      // Слушаем состояние сканирования
      _scanningSubscription = bluetoothRepository.isScanning.listen(
        (isScanning) {
          if (!isClosed) {
            emit(state.copyWith(isScanning: isScanning));
          }
        },
        onError: (error) {
          if (!isClosed) {
            emit(state.copyWith(errorMessage: 'Ошибка состояния сканирования: $error'));
          }
        },
      );

      // Слушаем состояние Bluetooth
      _bluetoothEnabledSubscription = bluetoothRepository.isBluetoothEnabled.listen(
        (isEnabled) {
          if (!isClosed) {
            emit(state.copyWith(isBluetoothEnabled: isEnabled));
          }
        },
        onError: (error) {
          if (!isClosed) {
            emit(state.copyWith(errorMessage: 'Ошибка состояния Bluetooth: $error'));
          }
        },
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Ошибка инициализации потоков: $e'));
      }
    }
  }

  Future<void> _onStartScan(StartScanEvent event, Emitter<BluetoothState> emit) async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));
      await _appLogger.logScanning('Запуск сканирования Bluetooth устройств', additionalData: {
        'timestamp': DateTime.now().toIso8601String(),
        'scanType': 'discovery',
      });
      await startBluetoothScan(NoParams());
      emit(state.copyWith(isLoading: false, successMessage: 'Сканирование начато'));
      await _appLogger.logScanning('Сканирование успешно запущено', additionalData: {
        'status': 'started',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await _appLogger.logError('Ошибка начала сканирования: $e', context: 'StartScan', additionalData: {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Ошибка начала сканирования: $e',
      ));
    }
  }

  Future<void> _onStopScan(StopScanEvent event, Emitter<BluetoothState> emit) async {
    try {
      final discoveredCount = state.discoveredDevices.length;
      await _appLogger.logScanning('Остановка сканирования Bluetooth устройств', additionalData: {
        'discoveredDevices': discoveredCount,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await stopBluetoothScan(NoParams());
      emit(state.copyWith(successMessage: 'Сканирование остановлено'));
      await _appLogger.logScanning('Сканирование успешно остановлено', additionalData: {
        'status': 'stopped',
        'totalDiscovered': discoveredCount,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await _appLogger.logError('Ошибка остановки сканирования: $e', context: 'StopScan', additionalData: {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      emit(state.copyWith(errorMessage: 'Ошибка остановки сканирования: $e'));
    }
  }

  Future<void> _onConnectToDevice(ConnectToDeviceEvent event, Emitter<BluetoothState> emit) async {
    try {
      // Находим устройство для логирования
      final device = state.discoveredDevices.firstWhere(
        (d) => d.id == event.deviceId,
        orElse: () => BluetoothDeviceEntity(
          id: event.deviceId,
          name: 'Неизвестное устройство',
          isConnected: false,
          rssi: 0,
          serviceUuids: [],
          deviceType: '',
        ),
      );
      
      await _appLogger.logConnection(device.name, event.deviceId, isConnected: false, additionalData: {
        'action': 'attempting_connection',
        'deviceType': device.deviceType,
        'rssi': device.rssi,
        'serviceUuids': device.serviceUuids,
        'isConnectable': device.isConnectable,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Добавляем устройство в список подключающихся
      final updatedConnectingDevices = Set<String>.from(state.connectingDevices)
        ..add(event.deviceId);
      
      emit(state.copyWith(
        connectingDevices: updatedConnectingDevices,
        errorMessage: null,
      ));
      
      final success = await connectToDevice(event.deviceId);
      
      // Убираем устройство из списка подключающихся
      final finalConnectingDevices = Set<String>.from(state.connectingDevices)
        ..remove(event.deviceId);
      
      if (success) {
        await _appLogger.logConnection(device.name, event.deviceId, isConnected: true, additionalData: {
          'action': 'connection_successful',
          'deviceType': device.deviceType,
          'rssi': device.rssi,
          'serviceUuids': device.serviceUuids,
          'isConnectable': device.isConnectable,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Добавляем устройство в список подключенных и ранее подключенных
        final updatedConnectedDevices = Set<String>.from(state.connectedDevices)
          ..add(event.deviceId);
        final updatedPreviouslyConnectedDevices = Set<String>.from(state.previouslyConnectedDevices)
          ..add(event.deviceId);
        
        emit(state.copyWith(
          connectingDevices: finalConnectingDevices,
          connectedDevices: updatedConnectedDevices,
          previouslyConnectedDevices: updatedPreviouslyConnectedDevices,
          successMessage: 'Успешно подключено к устройству',
        ));
      } else {
        await _appLogger.logError('Не удалось подключиться к устройству ${device.name}', context: 'ConnectToDevice', deviceId: event.deviceId, deviceName: device.name);
        emit(state.copyWith(
          connectingDevices: finalConnectingDevices,
          errorMessage: 'Не удалось подключиться к устройству',
        ));
      }
    } catch (e) {
      await _appLogger.logError('Ошибка подключения: $e', context: 'ConnectToDevice', deviceId: event.deviceId);
      
      // Убираем устройство из списка подключающихся в случае ошибки
      final finalConnectingDevices = Set<String>.from(state.connectingDevices)
        ..remove(event.deviceId);
      
      emit(state.copyWith(
        connectingDevices: finalConnectingDevices,
        errorMessage: 'Ошибка подключения: $e',
      ));
    }
  }

  Future<void> _onReconnectToDevice(ReconnectToDeviceEvent event, Emitter<BluetoothState> emit) async {
    try {
      // Добавляем устройство в список подключающихся
      final updatedConnectingDevices = Set<String>.from(state.connectingDevices)
        ..add(event.deviceId);
      
      emit(state.copyWith(
        connectingDevices: updatedConnectingDevices,
        errorMessage: null,
      ));
      
      final success = await bluetoothRepository.reconnectToDevice(event.deviceId);
      
      // Убираем устройство из списка подключающихся
      final finalConnectingDevices = Set<String>.from(state.connectingDevices)
        ..remove(event.deviceId);
      
      if (success) {
        // Добавляем устройство в список подключенных и ранее подключенных
        final updatedConnectedDevices = Set<String>.from(state.connectedDevices)
          ..add(event.deviceId);
        final updatedPreviouslyConnectedDevices = Set<String>.from(state.previouslyConnectedDevices)
          ..add(event.deviceId);
        
        emit(state.copyWith(
          connectingDevices: finalConnectingDevices,
          connectedDevices: updatedConnectedDevices,
          previouslyConnectedDevices: updatedPreviouslyConnectedDevices,
          successMessage: 'Успешно переподключено к устройству',
        ));
      } else {
        emit(state.copyWith(
          connectingDevices: finalConnectingDevices,
          errorMessage: 'Не удалось переподключиться к устройству',
        ));
      }
    } catch (e) {
      // Убираем устройство из списка подключающихся в случае ошибки
      final finalConnectingDevices = Set<String>.from(state.connectingDevices)
        ..remove(event.deviceId);
      
      emit(state.copyWith(
        connectingDevices: finalConnectingDevices,
        errorMessage: 'Ошибка переподключения: $e',
      ));
    }
  }

  Future<void> _onDisconnectFromDevice(DisconnectFromDeviceEvent event, Emitter<BluetoothState> emit) async {
    try {
      await bluetoothRepository.disconnectFromDevice(event.deviceId);
      
      // Убираем устройство из списка подключенных
      final updatedConnectedDevices = Set<String>.from(state.connectedDevices)
        ..remove(event.deviceId);
      
      emit(state.copyWith(
        connectedDevices: updatedConnectedDevices,
        successMessage: 'Устройство отключено',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Ошибка отключения: $e',
      ));
    }
  }

  Future<void> _onClearLogs(ClearLogsEvent event, Emitter<BluetoothState> emit) async {
    try {
      await clearBluetoothLogs(NoParams());
      emit(state.copyWith(
        logs: [],
        successMessage: 'Логи очищены',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Ошибка очистки логов: $e'));
    }
  }

  Future<void> _onLoadLogs(LoadLogsEvent event, Emitter<BluetoothState> emit) async {
    try {
      final logs = await getBluetoothLogs(NoParams());
      emit(state.copyWith(logs: logs));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Ошибка загрузки логов: $e'));
    }
  }

  void _onToggleShowAllDevices(ToggleShowAllDevicesEvent event, Emitter<BluetoothState> emit) {
    emit(state.copyWith(showAllDevices: !state.showAllDevices));
  }

  void _onAddLog(AddLogEvent event, Emitter<BluetoothState> emit) {
    final updatedLogs = List<BluetoothLogEntity>.from(state.logs)..add(event.logEntity);
    emit(state.copyWith(logs: updatedLogs));
  }

  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _logsSubscription?.cancel();
    _scanningSubscription?.cancel();
    _bluetoothEnabledSubscription?.cancel();
    return super.close();
  }
}
