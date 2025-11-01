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
import '../../data/services/logs_storage_service.dart';
import '../../data/services/native_bluetooth_connection_service.dart';
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
  final LogsStorageService _logsStorageService = LogsStorageService();
  final NativeBluetoothConnectionService _nativeConnectionService = NativeBluetoothConnectionService();

  StreamSubscription<List<BluetoothDeviceEntity>>? _devicesSubscription;
  StreamSubscription<BluetoothLogEntity>? _logsSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<bool>? _bluetoothEnabledSubscription;
  StreamSubscription<Map<String, dynamic>>? _nativeConnectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _nativeDisconnectionSubscription;

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
    on<ConnectToDeviceNativeEvent>(_onConnectToDeviceNative);
    on<DisconnectFromDeviceNativeEvent>(_onDisconnectFromDeviceNative);
    on<CheckConnectionTimeoutEvent>(_onCheckConnectionTimeout);

    _initializeStreams();
    _initializeLogger();
    // Загружаем сохраненные данные после инициализации блока
    Future.microtask(() => _loadSavedData());
  }

  /// Инициализация логгера
  void _initializeLogger() {
    _appLogger.initialize(bluetoothBloc: this);
  }

  /// Загрузка сохраненных данных при инициализации
  Future<void> _loadSavedData() async {
    try {
      // Загружаем логи из локального хранилища
      final savedLogs = await _logsStorageService.loadLogs();
      
      // Загружаем ранее подключенные устройства
      final savedDevices = await _logsStorageService.loadPreviouslyConnectedDevices();
      
      // Обновляем состояние только если есть данные для загрузки
      if (savedLogs.isNotEmpty || savedDevices.isNotEmpty) {
        if (!isClosed) {
          emit(state.copyWith(
            logs: savedLogs.isNotEmpty ? savedLogs : state.logs,
            previouslyConnectedDevices: savedDevices.isNotEmpty ? savedDevices : state.previouslyConnectedDevices,
          ));
        }
        
        if (savedLogs.isNotEmpty) {
          print('BluetoothBloc: Загружено ${savedLogs.length} сохраненных логов');
        }
        if (savedDevices.isNotEmpty) {
          print('BluetoothBloc: Загружено ${savedDevices.length} ранее подключенных устройств');
        }
      }
    } catch (e) {
      print('BluetoothBloc: Ошибка загрузки сохраненных данных: $e');
    }
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
            // Сохраняем логи локально
            _logsStorageService.saveLogs(updatedLogs);
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
      
      // Слушаем нативные подключения
      _nativeConnectionSubscription = _nativeConnectionService.connectionStream.listen(
        (connectionData) {
          if (!isClosed) {
            final deviceAddress = connectionData['deviceAddress'] as String?;
            final deviceName = connectionData['deviceName'] as String? ?? 'Неизвестное устройство';
            
            if (deviceAddress != null) {
              // Обновляем устройство в списке найденных устройств
              final updatedDevices = state.discoveredDevices.map((d) {
                if (d.id == deviceAddress) {
                  return BluetoothDeviceEntity(
                    id: d.id,
                    name: d.name,
                    isConnected: true,
                    rssi: d.rssi,
                    serviceUuids: d.serviceUuids,
                    deviceType: d.deviceType,
                    isConnectable: d.isConnectable,
                  );
                }
                return d;
              }).toList();
              
              // Если устройства нет в списке, добавляем его
              if (!updatedDevices.any((d) => d.id == deviceAddress)) {
                updatedDevices.add(BluetoothDeviceEntity(
                  id: deviceAddress,
                  name: deviceName,
                  isConnected: true,
                  rssi: 0,
                  serviceUuids: [],
                  deviceType: '',
                  isConnectable: true,
                ));
              } else {
                // Обновляем имя устройства если оно изменилось
                final deviceIndex = updatedDevices.indexWhere((d) => d.id == deviceAddress);
                if (deviceIndex != -1 && updatedDevices[deviceIndex].name != deviceName) {
                  final existingDevice = updatedDevices[deviceIndex];
                  updatedDevices[deviceIndex] = BluetoothDeviceEntity(
                    id: existingDevice.id,
                    name: deviceName,
                    isConnected: existingDevice.isConnected,
                    rssi: existingDevice.rssi,
                    serviceUuids: existingDevice.serviceUuids,
                    deviceType: existingDevice.deviceType,
                    isConnectable: existingDevice.isConnectable,
                  );
                }
              }
              
              // Убираем устройство из списка подключающихся (теперь оно подключено)
              final updatedConnectingDevices = Set<String>.from(state.connectingDevices)
                ..remove(deviceAddress);
              
              final updatedConnectedDevices = Set<String>.from(state.connectedDevices)
                ..add(deviceAddress);
              final updatedPreviouslyConnectedDevices = Set<String>.from(state.previouslyConnectedDevices)
                ..add(deviceAddress);
              
              emit(state.copyWith(
                discoveredDevices: updatedDevices,
                connectingDevices: updatedConnectingDevices,
                connectedDevices: updatedConnectedDevices,
                previouslyConnectedDevices: updatedPreviouslyConnectedDevices,
                successMessage: 'Нативное подключение: $deviceName',
              ));
              
              _logsStorageService.savePreviouslyConnectedDevices(updatedPreviouslyConnectedDevices);
            }
          }
        },
      );
      
      // Слушаем нативные отключения
      _nativeDisconnectionSubscription = _nativeConnectionService.disconnectionStream.listen(
        (disconnectionData) {
          if (!isClosed) {
            final deviceAddress = disconnectionData['deviceAddress'] as String?;
            final errorStatus = disconnectionData['errorStatus'] as int?;
            final errorMessage = disconnectionData['errorMessage'] as String?;
            
            if (deviceAddress != null) {
              // Убираем устройство из списка подключающихся (если оно там было)
              final updatedConnectingDevices = Set<String>.from(state.connectingDevices)
                ..remove(deviceAddress);
              
              final updatedConnectedDevices = Set<String>.from(state.connectedDevices)
                ..remove(deviceAddress);
              
              // Если есть ошибка статуса, показываем сообщение об ошибке
              String? message;
              if (errorStatus != null && errorStatus != 0) {
                message = errorMessage?.isNotEmpty == true 
                    ? 'Ошибка подключения: $errorMessage' 
                    : 'Устройство отключено (статус: $errorStatus)';
              } else {
                message = 'Устройство отключено (нативное)';
              }
              
              emit(state.copyWith(
                connectingDevices: updatedConnectingDevices,
                connectedDevices: updatedConnectedDevices,
                errorMessage: errorStatus != null && errorStatus != 0 ? message : null,
                successMessage: errorStatus == null || errorStatus == 0 ? message : null,
              ));
            }
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
      emit(state.copyWith(isLoading: true, errorMessage: null, showAllDevices: false));
      await _appLogger.logScanning('Запуск сканирования Bluetooth устройств', additionalData: {
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
        'scanType': 'discovery',
      });
      await startBluetoothScan(NoParams());
      emit(state.copyWith(isLoading: false, successMessage: 'Сканирование начато', showAllDevices: false));
      await _appLogger.logScanning('Сканирование успешно запущено', additionalData: {
        'status': 'started',
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
      });
    } catch (e) {
      await _appLogger.logError('Ошибка начала сканирования: $e', context: 'StartScan', additionalData: {
        'error': e.toString(),
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
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
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
      });
      await stopBluetoothScan(NoParams());
      emit(state.copyWith(successMessage: 'Сканирование остановлено'));
      await _appLogger.logScanning('Сканирование успешно остановлено', additionalData: {
        'status': 'stopped',
        'totalDiscovered': discoveredCount,
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
      });
    } catch (e) {
      await _appLogger.logError('Ошибка остановки сканирования: $e', context: 'StopScan', additionalData: {
        'error': e.toString(),
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
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
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
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
          'timestamp': AppLogger.formatTimestamp(DateTime.now()),
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
        // Сохраняем обновленный список ранее подключенных устройств
        _logsStorageService.savePreviouslyConnectedDevices(updatedPreviouslyConnectedDevices);
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
        // Сохраняем обновленный список ранее подключенных устройств
        _logsStorageService.savePreviouslyConnectedDevices(updatedPreviouslyConnectedDevices);
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
      // Очищаем логи из локального хранилища
      await _logsStorageService.clearLogs();
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
    
    // Записываем лог в файл с полной детализацией
    // Это нужно для логов, которые добавляются напрямую через AddLogEvent (например, из EmulationLogger)
    // Логи, созданные через AppLogger.log(), уже записаны в файл, но logFromEntity проверяет ID
    // и не будет дублировать уже записанные логи
    _appLogger.logFromEntity(event.logEntity);
    
    // Сохраняем логи локально
    _logsStorageService.saveLogs(updatedLogs);
  }
  
  Future<void> _onConnectToDeviceNative(ConnectToDeviceNativeEvent event, Emitter<BluetoothState> emit) async {
    try {
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
        'action': 'attempting_native_connection',
        'deviceType': device.deviceType,
        'rssi': device.rssi,
        'timestamp': AppLogger.formatTimestamp(DateTime.now()),
      });
      
      // Добавляем устройство в список подключающихся
      final updatedConnectingDevices = Set<String>.from(state.connectingDevices)
        ..add(event.deviceId);
      
      emit(state.copyWith(
        connectingDevices: updatedConnectingDevices,
        errorMessage: null,
      ));
      
      // Подключаемся через нативный сервис
      final success = await _nativeConnectionService.connectToDevice(event.deviceId);
      
      if (!success) {
        // Если подключение не удалось инициировать, сразу убираем из списка подключающихся
        final finalConnectingDevices = Set<String>.from(state.connectingDevices)
          ..remove(event.deviceId);
        
        await _appLogger.logError('Не удалось подключиться через нативный метод к устройству ${device.name}', 
            context: 'ConnectToDeviceNative', deviceId: event.deviceId, deviceName: device.name);
        emit(state.copyWith(
          connectingDevices: finalConnectingDevices,
          errorMessage: 'Не удалось инициировать нативное подключение',
        ));
      } else {
        // Подключение инициировано успешно - устройство остается в connectingDevices
        // и будет удалено из него только когда придет событие onDeviceConnected или onDeviceDisconnected
        // Добавляем таймаут на случай, если событие не придет
        final deviceIdForTimeout = event.deviceId;
        final deviceNameForTimeout = device.name;
        Future.delayed(const Duration(seconds: 30), () async {
          if (!isClosed) {
            // Проверяем, что обработчик события еще активен перед вызовом emit
            // Используем add для отправки события вместо прямого emit
            add(CheckConnectionTimeoutEvent(deviceIdForTimeout, deviceNameForTimeout));
          }
        });
        
        await _appLogger.logConnection(device.name, event.deviceId, isConnected: false, additionalData: {
          'action': 'native_connection_initiated',
          'deviceType': device.deviceType,
          'rssi': device.rssi,
          'timestamp': AppLogger.formatTimestamp(DateTime.now()),
        });
        
        // Обнаружение сервисов будет вызвано автоматически в Kotlin после успешного подключения
        emit(state.copyWith(
          successMessage: 'Нативное подключение инициировано',
        ));
      }
    } catch (e) {
      await _appLogger.logError('Ошибка нативного подключения: $e', context: 'ConnectToDeviceNative', deviceId: event.deviceId);
      
      final finalConnectingDevices = Set<String>.from(state.connectingDevices)
        ..remove(event.deviceId);
      
      emit(state.copyWith(
        connectingDevices: finalConnectingDevices,
        errorMessage: 'Ошибка нативного подключения: $e',
      ));
    }
  }
  
  Future<void> _onDisconnectFromDeviceNative(DisconnectFromDeviceNativeEvent event, Emitter<BluetoothState> emit) async {
    try {
      final success = await _nativeConnectionService.disconnectFromDevice(event.deviceId);
      
      if (success) {
        final updatedConnectedDevices = Set<String>.from(state.connectedDevices)
          ..remove(event.deviceId);
        
        emit(state.copyWith(
          connectedDevices: updatedConnectedDevices,
          successMessage: 'Устройство отключено (нативное)',
        ));
      } else {
        emit(state.copyWith(
          errorMessage: 'Не удалось отключить устройство',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Ошибка отключения: $e',
      ));
    }
  }
  
  Future<void> _onCheckConnectionTimeout(CheckConnectionTimeoutEvent event, Emitter<BluetoothState> emit) async {
    try {
      // Проверяем, что устройство все еще в connectingDevices и не подключено
      if (state.connectingDevices.contains(event.deviceId) && 
          !state.connectedDevices.contains(event.deviceId)) {
        // Если через 30 секунд устройство все еще в connectingDevices и не подключено, убираем его
        final timeoutConnectingDevices = Set<String>.from(state.connectingDevices)
          ..remove(event.deviceId);
        
        await _appLogger.logError('Таймаут нативного подключения к устройству ${event.deviceName}', 
            context: 'ConnectToDeviceNative', deviceId: event.deviceId, deviceName: event.deviceName);
        
        emit(state.copyWith(
          connectingDevices: timeoutConnectingDevices,
          errorMessage: 'Таймаут нативного подключения к ${event.deviceName}',
        ));
      }
    } catch (e) {
      // Игнорируем ошибки проверки таймаута
      print('BluetoothBloc: Ошибка проверки таймаута: $e');
    }
  }

  @override
  Future<void> close() {
    // Сохраняем данные перед закрытием
    _saveDataBeforeClose();
    
    _devicesSubscription?.cancel();
    _logsSubscription?.cancel();
    _scanningSubscription?.cancel();
    _bluetoothEnabledSubscription?.cancel();
    _nativeConnectionSubscription?.cancel();
    _nativeDisconnectionSubscription?.cancel();
    _nativeConnectionService.dispose();
    return super.close();
  }

  /// Сохранение данных перед закрытием блока
  void _saveDataBeforeClose() {
    try {
      // Сохраняем текущие логи
      if (state.logs.isNotEmpty) {
        _logsStorageService.saveLogs(state.logs);
      }
      
      // Сохраняем ранее подключенные устройства
      if (state.previouslyConnectedDevices.isNotEmpty) {
        _logsStorageService.savePreviouslyConnectedDevices(state.previouslyConnectedDevices);
      }
      
      print('BluetoothBloc: Данные сохранены перед закрытием');
    } catch (e) {
      print('BluetoothBloc: Ошибка сохранения данных перед закрытием: $e');
    }
  }
}
