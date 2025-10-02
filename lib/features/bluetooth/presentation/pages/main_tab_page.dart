import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../../domain/entities/bluetooth_log_entity.dart';
import '../widgets/device_item_widget.dart';
import '../../../../core/utils/permission_helper.dart';

class MainTabPage extends StatefulWidget {
  MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final statuses = await PermissionHelper.getAllPermissionStatuses();

    setState(() {
      _permissionStatuses = statuses;
      _permissionsChecked = true;
    });
  }

  Future<void> _requestPermissions() async {
    try {
      print('Запрос разрешений начат...');
      
      // Показываем индикатор загрузки
      setState(() {
        _permissionsChecked = false;
      });

      // Показываем уведомление о начале запроса
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запрашиваем разрешения...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Проверяем текущие статусы
      print('Проверяем текущие статусы разрешений...');
      final currentStatuses = await PermissionHelper.getAllPermissionStatuses();
      for (final entry in currentStatuses.entries) {
        print('${PermissionHelper.getPermissionDisplayName(entry.key)}: ${PermissionHelper.getPermissionStatusText(entry.value)}');
      }

      // Запрашиваем основные разрешения
      print('Запрашиваем основные разрешения...');
      final results = await PermissionHelper.requestRequiredPermissions();
      print('Результат запроса основных разрешений: ${results.map((k, v) => MapEntry(PermissionHelper.getPermissionDisplayName(k), PermissionHelper.getPermissionStatusText(v)))}');
      
      // Обновляем статусы
      for (final entry in results.entries) {
        currentStatuses[entry.key] = entry.value;
      }
      
      // Запрашиваем дополнительные разрешения
      try {
        final optionalResults = await PermissionHelper.requestOptionalPermissions();
        for (final entry in optionalResults.entries) {
          currentStatuses[entry.key] = entry.value;
        }
        print('Результат запроса дополнительных разрешений: ${optionalResults.map((k, v) => MapEntry(PermissionHelper.getPermissionDisplayName(k), PermissionHelper.getPermissionStatusText(v)))}');
      } catch (e) {
        print('Ошибка запроса дополнительных разрешений: $e');
      }
      
      // Обновляем статусы
      setState(() {
        _permissionStatuses = currentStatuses;
        _permissionsChecked = true;
      });

      // Показываем результат
      final grantedCount = currentStatuses.values.where((status) => status.isGranted).length;
      final totalCount = currentStatuses.length;
      final requiredGranted = PermissionHelper.requiredPermissions.every((permission) => 
        currentStatuses[permission]?.isGranted ?? false);
      
      print('Получено $grantedCount из $totalCount разрешений');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requiredGranted 
                ? 'Все необходимые разрешения получены!' 
                : 'Получено $grantedCount из $totalCount разрешений',
            ),
            backgroundColor: requiredGranted ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Ошибка при запросе разрешений: $e');
      
      setState(() {
        _permissionsChecked = true;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка запроса разрешений: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
      
      // Обновляем статусы разрешений после возврата из настроек
      Future.delayed(const Duration(seconds: 1), () {
        _checkPermissions();
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть настройки: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _forceRequestPermissions() async {
    try {
      print('Принудительный запрос всех разрешений...');
      
      // Показываем индикатор загрузки
      setState(() {
        _permissionsChecked = false;
      });

    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
        Permission.locationAlways,
      Permission.notification,
    ];

      // Показываем уведомление
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Принудительно запрашиваем все разрешения...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Принудительно запрашиваем все разрешения
      print('Отправляем принудительный запрос всех разрешений...');
    final results = await permissions.request();
      print('Результат принудительного запроса: $results');
      
      // Обновляем статусы
    setState(() {
      _permissionStatuses = results;
        _permissionsChecked = true;
      });

      // Показываем результат
      final grantedCount = results.values.where((status) => status.isGranted).length;
      final totalCount = results.length;
      
      print('После принудительного запроса: $grantedCount из $totalCount разрешений');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              grantedCount == totalCount 
                ? 'Все разрешения получены!' 
                : 'Получено $grantedCount из $totalCount разрешений',
            ),
            backgroundColor: grantedCount == totalCount ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Ошибка при принудительном запросе разрешений: $e');
      
      setState(() {
        _permissionsChecked = true;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка принудительного запроса: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Тестер'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildPermissionsTab(),
            _buildDevicesTab(),
            _buildLogsTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Разрешения',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Устройства',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Логи',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1 ? _buildFloatingActionButton() : null,
    );
  }

  Widget _buildFloatingActionButton() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        if (state.isScanning) {
          return FloatingActionButton(
            onPressed: () => context.read<BluetoothBloc>().add(const StopScanEvent()),
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop),
          );
        } else {
          return FloatingActionButton(
            onPressed: () => context.read<BluetoothBloc>().add(const StartScanEvent()),
            backgroundColor: Colors.blue,
            child: const Icon(Icons.search),
          );
        }
      },
    );
  }

  Widget _buildPermissionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Карточка разрешений
          _buildPermissionsCard(),
          
          const SizedBox(height: 16),
          
          // Информация о статусе Bluetooth
          _buildBluetoothStatusCard(),
          
          const SizedBox(height: 16),
          
          // Инструкции по настройке
          _buildInstructionsCard(),
        ],
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Column(
      children: [
        // Статус
        _buildStatusInfo(),
        
        // Список устройств
        Expanded(
          child: _buildDevicesList(),
        ),
      ],
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        // Кнопки управления логами
        _buildLogsControls(),
        
        // Логи
        Expanded(
          child: _buildLogsList(),
        ),
      ],
    );
  }

  Widget _buildPermissionsCard() {
    if (!_permissionsChecked) {
      return const Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Считаем только обязательные разрешения для определения "все ли получены"
    final allRequiredGranted = PermissionHelper.requiredPermissions.every((permission) => 
      _permissionStatuses[permission]?.isGranted ?? false);
    final grantedCount = _permissionStatuses.values.where((status) => status.isGranted).length;
    final totalCount = _permissionStatuses.length;
    
    return Card(
      margin: const EdgeInsets.all(8),
      color: allRequiredGranted ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Icon(
                  allRequiredGranted ? Icons.check_circle : Icons.warning,
                  color: allRequiredGranted ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                        allRequiredGranted ? 'Все обязательные разрешения получены' : 'Требуются разрешения',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: allRequiredGranted ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        '$grantedCount из $totalCount разрешений получено',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                    onPressed: _requestPermissions,
                  icon: const Icon(Icons.security, size: 16),
                  label: const Text('Запросить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allRequiredGranted ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Детальная информация о разрешениях
            Text(
              'Детали разрешений:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Список разрешений
            ..._buildPermissionItems(),
            
            if (!allRequiredGranted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                        child: Text(
                          'Для работы с Bluetooth устройствами необходимо предоставить все обязательные разрешения (отмечены как "ОБЯЗАТЕЛЬНО")',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _requestPermissions,
                                icon: const Icon(Icons.security, size: 16),
                                label: const Text('Запросить'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openAppSettings,
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Настройки'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
              const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _forceRequestPermissions,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Принудительно запросить все'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            // Информация о статусе разрешений
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Статус разрешений',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Зеленые разрешения - получены\n'
                    '• Красные разрешения - отклонены\n'
                    '• "ОБЯЗАТЕЛЬНО" - критичны для работы\n'
                    '• Остальные - опциональны, но рекомендуются',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPermissionItems() {
    return PermissionHelper.allPermissions.map((permission) {
      final status = _permissionStatuses[permission] ?? PermissionStatus.denied;
      final isGranted = status.isGranted;
      final isRequired = PermissionHelper.isRequiredPermission(permission);
      
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isGranted ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isGranted ? Colors.green.shade300 : Colors.red.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isGranted ? Icons.check_circle : Icons.cancel,
              color: isGranted ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        PermissionHelper.getPermissionDisplayName(permission),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isGranted ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ОБЯЗАТЕЛЬНО',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PermissionHelper.getPermissionDescription(permission),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Статус: ${PermissionHelper.getPermissionStatusText(status)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isGranted ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }


  Widget _buildBluetoothStatusCard() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.isBluetoothEnabled ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: state.isBluetoothEnabled ? Colors.blue : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Статус Bluetooth',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: state.isBluetoothEnabled ? Colors.blue.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusItem('Bluetooth', state.isBluetoothEnabled ? 'Включен' : 'Выключен', state.isBluetoothEnabled),
                    _buildStatusItem('Устройств', '${state.discoveredDevices.length}', true),
                    _buildStatusItem('Логов', '${state.logs.length}', true),
                  ],
                ),
                if (!state.isBluetoothEnabled) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Включите Bluetooth в настройках устройства для работы с приложением',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(String label, String value, bool isPositive) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isPositive ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Инструкции по настройке',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '1',
              'Включите Bluetooth',
              'Перейдите в настройки устройства и включите Bluetooth',
            ),
            _buildInstructionStep(
              '2',
              'Предоставьте разрешения',
              'Нажмите "Запросить" для получения всех необходимых разрешений',
            ),
            _buildInstructionStep(
              '3',
              'Найдите устройства',
              'Перейдите на вкладку "Устройства" и нажмите кнопку поиска',
            ),
            _buildInstructionStep(
              '4',
              'Подключитесь к устройству',
              'Нажмите "Подключить" на нужном устройстве',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('Bluetooth: ${state.isBluetoothEnabled ? "Включен" : "Выключен"}'),
              Text('Устройств: ${state.discoveredDevices.length}'),
              Text('Логов: ${state.logs.length}'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDevicesList() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        if (state.isScanning) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Поиск устройств...',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Найдено: ${state.discoveredDevices.length}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (state.discoveredDevices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_searching,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Устройства не найдены',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Нажмите кнопку поиска для сканирования',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Заголовок с количеством устройств
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Доступные устройства (${state.discoveredDevices.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            // Список устройств
            Expanded(
              child: ListView.builder(
                itemCount: state.discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = state.discoveredDevices[index];
                  final isConnected = state.connectedDevices.contains(device.id);
                  final wasPreviouslyConnected = state.previouslyConnectedDevices.contains(device.id);
                  
                  return DeviceItemWidget(
                    device: device,
                    isConnecting: state.connectingDevices.contains(device.id),
                    isConnected: isConnected,
                    wasPreviouslyConnected: wasPreviouslyConnected,
                    onConnect: () {
                      if (wasPreviouslyConnected && !isConnected) {
                        context.read<BluetoothBloc>().add(
                          ReconnectToDeviceEvent(device.id),
                        );
                      } else {
                        context.read<BluetoothBloc>().add(
                          ConnectToDeviceEvent(device.id),
                        );
                      }
                    },
                    onReconnect: () {
                      context.read<BluetoothBloc>().add(
                        ReconnectToDeviceEvent(device.id),
                      );
                    },
                    onDisconnect: () {
                      context.read<BluetoothBloc>().add(
                        DisconnectFromDeviceEvent(device.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogsControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => context.read<BluetoothBloc>().add(const ClearLogsEvent()),
            icon: const Icon(Icons.clear_all),
            label: const Text('Очистить логи'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        if (state.logs.isEmpty) {
          return const Center(
            child: Text(
              'Логи пусты',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: state.logs.length,
          itemBuilder: (context, index) {
            final log = state.logs.reversed.toList()[index];
            return _buildLogCard(log);
          },
        );
      },
    );
  }

  Widget _buildLogCard(BluetoothLogEntity log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок лога
            Row(
              children: [
                Icon(
                  _getLogIcon(log.level),
                  color: _getLogColor(log.level),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _getLogColor(log.level),
                    ),
                  ),
                ),
                Text(
                  '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            // Информация об устройстве
            if (log.deviceName != null || log.deviceId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.deviceName != null) ...[
                      Row(
                        children: [
                          Icon(Icons.device_hub, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Устройство: ${log.deviceName}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (log.deviceId != null) ...[
                      Row(
                        children: [
                          Icon(Icons.fingerprint, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'ID: ${log.deviceId}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            // Дополнительные данные
            if (log.additionalData != null && log.additionalData!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.data_object, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Дополнительные данные:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...log.additionalData!.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(left: 20, bottom: 2),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.debug:
        return Icons.bug_report;
    }
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.debug:
        return Colors.grey;
    }
  }
}
