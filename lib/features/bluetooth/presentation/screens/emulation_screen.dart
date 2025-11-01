import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'dart:async';
import 'dart:math';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart' as app_state;
import '../../data/services/ble_peripheral_service.dart';
import '../widgets/treadmill_data_modal.dart';
import '../components/notification.dart';
import '../theme/navigate_to_emulation_notification.dart';

class EmulationScreen extends StatefulWidget {
  const EmulationScreen({super.key});

  @override
  State<EmulationScreen> createState() => _EmulationScreenState();
}

class _EmulationScreenState extends State<EmulationScreen> with WidgetsBindingObserver {
  bool _isEmulating = false;
  int _heartRate = 75;
  int _batteryLevel = 85;
  Timer? _heartRateTimer;
  final BlePeripheralService _bleService = BlePeripheralService();
  StreamSubscription? _heartRateSubscription;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _deviceConnectedSubscription;
  StreamSubscription? _dataReceivedSubscription;
  bool _isDataModalOpen = false; // Флаг, чтобы не открывать модалку повторно
  bool _hasShownModalOnReturn = false; // Флаг для показа модалки при возврате
  bool _isDeviceConnected = false; // Флаг подключения устройства
  String? _connectedDeviceName; // Имя подключенного устройства
  String? _connectedDeviceAddress; // Адрес подключенного устройства

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Не останавливаем эмуляцию при dispose - она должна продолжаться при навигации назад
    // Останавливаем только подписки и таймер UI, но не саму BLE рекламацию
    _stopHeartRateSimulation(); // Останавливаем таймер UI, но BLE сервис продолжит работать
    _heartRateSubscription?.cancel();
    _batterySubscription?.cancel();
    _connectionSubscription?.cancel();
    _deviceConnectedSubscription?.cancel();
    _dataReceivedSubscription?.cancel();
    // Не вызываем _bleService.dispose() - сервис синглтон и должен продолжать работать
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Восстанавливаем состояние эмуляции, если она уже запущена
    _isEmulating = _bleService.isAdvertising;
    if (_isEmulating) {
      // Если эмуляция активна, восстанавливаем значения из сервиса
      _heartRate = _bleService.currentHeartRate;
      _batteryLevel = _bleService.currentBatteryLevel;
      
      // Проверяем состояние подключения устройства
      final connectedDevice = _bleService.lastConnectedDevice;
      if (connectedDevice != null) {
        final isConnected = connectedDevice['isConnected'] as bool? ?? false;
        if (isConnected) {
          _isDeviceConnected = true;
          _connectedDeviceName = connectedDevice['deviceName'] as String?;
          _connectedDeviceAddress = connectedDevice['deviceAddress'] as String?;
        }
      }
      
      // Перезапускаем симуляцию пульса для UI, если эмуляция активна
      // (таймер был остановлен в dispose при предыдущем закрытии экрана)
      _startHeartRateSimulation();
      
      // Проверяем, есть ли подключенное устройство при возврате на экран
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowModalOnReturn();
      });
    }
    _setupBleServiceListeners();
    _setupBluetoothBloc();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // При возврате приложения в активное состояние проверяем подключенное устройство
    if (state == AppLifecycleState.resumed && _isEmulating && mounted) {
      _checkAndShowModalOnReturn();
    }
  }
  
  void _checkAndShowModalOnReturn() {
    if (_isEmulating && !_isDataModalOpen && !_hasShownModalOnReturn) {
      final connectedDevice = _bleService.lastConnectedDevice;
      if (connectedDevice != null) {
        final deviceName = connectedDevice['deviceName'] as String? ?? 'Неизвестное устройство';
        final deviceAddress = connectedDevice['deviceAddress'] as String? ?? 'Неизвестный адрес';
        final isConnected = connectedDevice['isConnected'] as bool? ?? false;
        
        if (isConnected) {
          _hasShownModalOnReturn = true;
          // Небольшая задержка для стабильности UI
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isDataModalOpen) {
              _openTreadmillDataModal(deviceName, deviceAddress);
            }
          });
        }
      }
    }
  }

  void _setupBluetoothBloc() {
    // Передаем BluetoothBloc в BLE сервис для логирования
    final bluetoothBloc = context.read<BluetoothBloc>();
    _bleService.setBluetoothBloc(bluetoothBloc);
  }

  void _setupBleServiceListeners() {
    // Слушаем изменения пульса от BLE сервиса
    _heartRateSubscription = _bleService.heartRateStream.listen((heartRate) {
      if (mounted) {
        setState(() {
          _heartRate = heartRate;
        });
      }
    });

    // Слушаем изменения батареи от BLE сервиса
    _batterySubscription = _bleService.batteryStream.listen((battery) {
      if (mounted) {
        setState(() {
          _batteryLevel = battery;
        });
      }
    });

    // Слушаем изменения состояния подключения (только реальные подключения)
    _connectionSubscription = _bleService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isDeviceConnected = isConnected;
          if (isConnected) {
            final connectedDevice = _bleService.lastConnectedDevice;
            if (connectedDevice != null) {
              _connectedDeviceName = connectedDevice['deviceName'] as String?;
              _connectedDeviceAddress = connectedDevice['deviceAddress'] as String?;
            }
          } else {
            _connectedDeviceName = null;
            _connectedDeviceAddress = null;
          }
        });
        
        if (isConnected) {
          // Показываем уведомление с возможностью перехода на экран эмуляции
          // Это уведомление будет показываться на любом экране приложения
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('🎉 Устройство подключилось к эмулятору!'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Открыть эмуляцию',
                    textColor: Colors.white,
                    onPressed: () {
                      NavigateToEmulationNotification().dispatch(context);
                    },
                  ),
                ),
              );
            }
          });
        } else {
          // При отключении показываем простое уведомление
          MyToastNotification().showInfoToast(context, 'Устройство отключилось');
        }
      }
    });

    // Слушаем подключения устройств для открытия экрана данных
    print('EmulationScreen: Настройка слушателя подключений устройств...');
    print('EmulationScreen: BLE Service: ${_bleService.runtimeType}');
    print('EmulationScreen: Device Connected Stream: ${_bleService.deviceConnectedStream}');
    
    _deviceConnectedSubscription = _bleService.deviceConnectedStream.listen((deviceData) {
      print('EmulationScreen: ===== ПОЛУЧЕНО СОБЫТИЕ ПОДКЛЮЧЕНИЯ =====');
      print('EmulationScreen: Данные: $deviceData');
      print('EmulationScreen: Тип данных: ${deviceData.runtimeType}');
      print('EmulationScreen: Ключи: ${deviceData.keys.toList()}');
      print('EmulationScreen: Widget mounted: $mounted');
      
        if (mounted) {
        final deviceName = deviceData['deviceName'] as String? ?? 'Неизвестное устройство';
        final deviceAddress = deviceData['deviceAddress'] as String? ?? 'Неизвестный адрес';
        final bondState = deviceData['bondState'] as int? ?? 0;
        final isConnected = deviceData['isConnected'] as bool? ?? false;
        
        setState(() {
          _isDeviceConnected = isConnected;
          if (isConnected) {
            _connectedDeviceName = deviceName;
            _connectedDeviceAddress = deviceAddress;
          } else {
            _connectedDeviceName = null;
            _connectedDeviceAddress = null;
          }
        });
        
        print('EmulationScreen: ===== ОБРАБОТКА ПОДКЛЮЧЕНИЯ =====');
        print('EmulationScreen: Имя: $deviceName');
        print('EmulationScreen: Адрес: $deviceAddress');
        print('EmulationScreen: Bond: $bondState, Connected: $isConnected');
        
        // Показываем уведомление о подключении (без авто-действия)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎉 Устройство подключилось!'),
                Text('$deviceName', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('MAC: $deviceAddress', style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Открыть',
              textColor: Colors.white,
              onPressed: () {
                // Навигация уже на экране эмуляции, но можно показать модалку
                if (!_isDataModalOpen) {
                  _openTreadmillDataModal(deviceName, deviceAddress);
                }
              },
            ),
          ),
        );
        
        // Открываем модалку сразу при подключении (один раз)
        if (!_isDataModalOpen) {
          print('EmulationScreen: Открываем модальное окно данных для $deviceName');
          _hasShownModalOnReturn = true; // Помечаем, что модалка уже показана
          _openTreadmillDataModal(deviceName, deviceAddress);
        }
      }
    });

    // Слушаем данные от дорожки для логирования и уведомлений
    _dataReceivedSubscription = _bleService.dataReceivedStream.listen((data) {
      if (mounted) {
        final deviceName = data['deviceName'] as String? ?? 'Неизвестное устройство';
        final hexData = data['hexData'] as String? ?? '';
        
        print('EmulationScreen: Получены данные от $deviceName: $hexData');
        
        // Показываем краткое уведомление о получении данных
        MyToastNotification().showInfoToast(context, '📊 Данные от $deviceName: ${hexData.length > 20 ? '${hexData.substring(0, 20)}...' : hexData}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isEmulating, // Не позволяем выйти, если эмуляция запущена
      onPopInvoked: (didPop) {
        if (_isEmulating && !didPop) {
          // Показываем уведомление, что эмуляция запущена
          MyToastNotification().showWarningToast(
            context, 
            'Эмуляция запущена!\nДля остановки используйте кнопку "Остановить эмуляцию"',
            duration: const Duration(seconds: 4),
          );
        }
      },
      child: BlocBuilder<BluetoothBloc, app_state.BluetoothState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Статус эмуляции
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isEmulating ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                              color: _isEmulating ? Colors.green : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isEmulating ? 'Эмуляция активна' : 'Эмуляция остановлена',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: _isEmulating ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _isEmulating 
                                      ? 'Устройство видимо как фитнес-часы'
                                      : 'Нажмите кнопку для начала эмуляции',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Настройки эмуляции
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Настройки эмуляции',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Настройка пульса
                        Row(
                          children: [
                            Icon(Icons.favorite, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('Пульс:', style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Slider(
                                value: _heartRate.toDouble(),
                                min: 60,
                                max: 180,
                                divisions: 120,
                                label: '$_heartRate уд/мин',
                                onChanged: _isEmulating ? null : (value) {
                                  final newHeartRate = value.round();
                                  setState(() {
                                    _heartRate = newHeartRate;
                                  });
                                  // Обновляем в BLE сервисе если он активен
                                  if (_bleService.isAdvertising) {
                                    _bleService.updateHeartRate(newHeartRate);
                                  }
                                },
                              ),
                            ),
                            Text(
                              '$_heartRate',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Настройка уровня батареи
                        Row(
                          children: [
                            Icon(Icons.battery_std, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('Батарея:', style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Slider(
                                value: _batteryLevel.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 100,
                                label: '$_batteryLevel%',
                                onChanged: _isEmulating ? null : (value) {
                                  final newBatteryLevel = value.round();
                                  setState(() {
                                    _batteryLevel = newBatteryLevel;
                                  });
                                  // Обновляем в BLE сервисе если он активен
                                  if (_bleService.isAdvertising) {
                                    _bleService.updateBatteryLevel(newBatteryLevel);
                                  }
                                },
                              ),
                            ),
                            Text(
                              '$_batteryLevel%',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Кнопка управления
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isEmulating ? _stopEmulation : _startEmulation,
                    icon: Icon(_isEmulating ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isEmulating ? 'Остановить эмуляцию' : 'Запустить эмуляцию',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEmulating ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Кнопка просмотра данных устройства
                if (_isEmulating)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isDeviceConnected && _connectedDeviceName != null && _connectedDeviceAddress != null
                          ? () {
                              _openTreadmillDataModal(
                                _connectedDeviceName!,
                                _connectedDeviceAddress!,
                              );
                            }
                          : null,
                      icon: Icon(_isDeviceConnected ? Icons.data_usage : Icons.bluetooth_disabled),
                      label: Text(
                        _isDeviceConnected
                            ? 'Просмотр данных от устройства'
                            : 'Ожидание подключения устройства',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDeviceConnected ? Colors.blue : Colors.grey,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Совместимость с дорожками
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.directions_run, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Совместимость с дорожками',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Многие беговые дорожки требуют подключения фитнес-устройств для:\n'
                          '• Отображения пульса на экране\n'
                          '• Адаптации интенсивности тренировки\n'
                          '• Сохранения данных в профиле пользователя\n\n'
                          'Доступные бренды: Technogym, Life Fitness, Precor, Matrix и другие.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Проблемы тестирования
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Почему не видно устройство?',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '❌ Android устройства НЕ МОГУТ видеть сами себя в Bluetooth сканировании.\n\n'
                          '✅ Для проверки работы нужны:\n'
                          '• Беговая дорожка с Bluetooth\n'
                          '• Другой телефон/планшет\n'
                          '• Компьютер с Bluetooth адаптером\n'
                          '• Bluetooth сканер приложение\n\n'
                          'Проверьте работу на одной из этих устройств!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Информация
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Информация',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'При включенной эмуляции ваше устройство будет отображаться в списке доступных Bluetooth-устройств как фитнес-часы или пульсометр. Это позволит подключиться к дорожкам, которые принимают только такие устройства.\n\n'
                          'Функция включает в себя:\n'
                          '• Heart Rate Service (0x180D) - для передачи данных о пульсе\n'
                          '• Battery Service (0x180F) - для индикации заряда батареи\n'
                          '• Device Information Service (0x180A) - информация об устройстве\n\n'
                          '✅ ПОЛНАЯ РЕАЛИЗАЦИЯ: Нативная BLE рекламация + GATT сервер для Android.\n\n'
                          '⚠️ ВАЖНО: Android устройства не могут видеть сами себя в BLE сканировании. Для тестирования нужны другие устройства (дорожка, другой телефон, компьютер с Bluetooth).',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startEmulation() async {
    try {
      // Проверяем доступность Bluetooth
      if (!await ble.FlutterBluePlus.isAvailable) {
        if(mounted) {
          MyToastNotification().showErrorToast(context, 'Bluetooth недоступен на этом устройстве');
        }
        return;
      }

      if (await ble.FlutterBluePlus.adapterState.first != ble.BluetoothAdapterState.on) {
        if(mounted) {
          MyToastNotification().showErrorToast(context, 'Включите Bluetooth для эмуляции');
        }
        return;
      }

      // Инициализируем BLE периферийный сервис
      final initialized = await _bleService.initialize();
      if (!initialized) {
        if(mounted) {
          MyToastNotification().showErrorToast(context, 'Ошибка инициализации BLE сервиса');
        }
        return;
      }

      // Начинаем рекламацию как фитнес-устройство
      final advertisingStarted = await _bleService.startAdvertising(
        deviceName: 'Fitness Watch',
        heartRate: _heartRate,
        batteryLevel: _batteryLevel,
      );

      if (!advertisingStarted) {
        if(mounted) {
          MyToastNotification().showErrorToast(context, 'Не удалось запустить рекламацию');
        }
        return;
      }
      
      // Запускаем таймер для изменения пульса
      _startHeartRateSimulation();

      setState(() {
        _isEmulating = true;
      });

      if(mounted) {
        MyToastNotification().showSuccessToast(context, '✅ BLE рекламация запущена!\n📱 Устройство видимо как "Fitness Watch"');
      }
      
    } catch (e) {
      String errorMessage = 'Ошибка запуска эмуляции: $e';
      
      if (e.toString().contains('PERMISSIONS_REQUIRED') || 
          e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('BLUETOOTH_ADVERTISE')) {
        errorMessage = '❌ Недостаточно разрешений для BLE рекламации!';
      }
      if(mounted) {
        MyToastNotification().showErrorToast(context, errorMessage);
      }
    }
  }

  Future<void> _stopEmulation() async {
    try {
      _stopHeartRateSimulation();
      await _bleService.stopAdvertising();
      
      setState(() {
        _isEmulating = false;
        _hasShownModalOnReturn = false; // Сбрасываем флаг при остановке
        _isDeviceConnected = false;
        _connectedDeviceName = null;
        _connectedDeviceAddress = null;
      });
      if(mounted) {
      MyToastNotification().showSuccessToast(context, 'Эмуляция остановлена!');
      }
    } catch (e) {
      if(mounted) {
        MyToastNotification().showErrorToast(context, 'Ошибка остановки эмуляции: $e');
      }
    }
  }

  void _startHeartRateSimulation() {
    // Убеждаемся, что старый таймер остановлен перед созданием нового
    _stopHeartRateSimulation();
    _heartRateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _bleService.isAdvertising) {
        // Имитируем естественные колебания пульса
        final random = Random();
        final variation = random.nextInt(10) - 5; // ±5 от базового значения
        final newHeartRate = (_heartRate + variation).clamp(60, 180);
        
        // Обновляем через BLE сервис
        _bleService.updateHeartRate(newHeartRate);
        
        setState(() {
          _heartRate = newHeartRate;
        });
      }
    });
  }

  void _stopHeartRateSimulation() {
    _heartRateTimer?.cancel();
    _heartRateTimer = null;
  }

  void _openTreadmillDataModal(String deviceName, String deviceAddress) {
    if (_isDataModalOpen) return;
    _isDataModalOpen = true;
    _hasShownModalOnReturn = true; // Помечаем, что модалка показана
    showDialog(
      context: context,
      barrierDismissible: false, // Нельзя закрыть случайно
      builder: (context) => TreadmillDataModal(
        deviceName: deviceName,
        deviceAddress: deviceAddress,
      ),
    ).whenComplete(() {
      // Сбрасываем флаг, когда модалка закрыта
      _isDataModalOpen = false;
      // Не сбрасываем _hasShownModalOnReturn здесь, чтобы модалка не показывалась повторно при возврате
    });
  }

}
