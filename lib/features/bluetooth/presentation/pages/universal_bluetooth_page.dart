import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../../domain/entities/bluetooth_log_entity.dart';
import '../widgets/device_item_widget.dart';

class UniversalBluetoothPage extends StatefulWidget {
  UniversalBluetoothPage({super.key});

  @override
  State<UniversalBluetoothPage> createState() => _UniversalBluetoothPageState();
}

class _UniversalBluetoothPageState extends State<UniversalBluetoothPage> {
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.notification,
    ];

    final statuses = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }

    setState(() {
      _permissionStatuses = statuses;
      _permissionsChecked = true;
    });
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.notification,
    ];

    final results = await permissions.request();
    setState(() {
      _permissionStatuses = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Тестер'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BluetoothBloc>().add(const LoadLogsEvent());
            },
          ),
        ],
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
        child: Column(
          children: [
            // Карточка разрешений (компактная)
            _buildPermissionsCard(),
            
            // Кнопки управления
            _buildControlButtons(),
            
            // Статус
            _buildStatusInfo(),
            
            // Список устройств
            _buildDevicesSection(),
            
            // Логи
            _buildLogsSection(),
          ],
        ),
      ),
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

    final allGranted = _permissionStatuses.values.every((status) => status.isGranted);
    
    return Card(
      margin: const EdgeInsets.all(8),
      color: allGranted ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allGranted ? Icons.check_circle : Icons.warning,
                  color: allGranted ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  allGranted ? 'Все разрешения получены' : 'Требуются разрешения',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: allGranted ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                if (!allGranted)
                  TextButton(
                    onPressed: _requestPermissions,
                    child: const Text('Запросить'),
                  ),
              ],
            ),
            if (!allGranted) ...[
              const SizedBox(height: 8),
              Text(
                'Отклонены: ${_permissionStatuses.entries.where((e) => !e.value.isGranted).map((e) => e.key.toString().split('.').last).join(', ')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            BlocBuilder<BluetoothBloc, BluetoothState>(
              builder: (context, state) {
                return ElevatedButton.icon(
                  onPressed: state.isScanning
                      ? null
                      : () => context.read<BluetoothBloc>().add(const StartScanEvent()),
                  icon: const Icon(Icons.search),
                  label: const Text('Начать сканирование'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            BlocBuilder<BluetoothBloc, BluetoothState>(
              builder: (context, state) {
                return ElevatedButton.icon(
                  onPressed: state.isScanning
                      ? () => context.read<BluetoothBloc>().add(const StopScanEvent())
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Остановить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
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

  Widget _buildDevicesSection() {
    return Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Найденные устройства',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: BlocBuilder<BluetoothBloc, BluetoothState>(
              builder: (context, state) {
                if (state.isScanning) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Поиск устройств...'),
                      ],
                    ),
                  );
                }

                if (state.discoveredDevices.isEmpty) {
                  return const Center(
                    child: Text(
                      'Устройства не найдены.\nНажмите "Начать сканирование"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: state.discoveredDevices.length,
                  itemBuilder: (context, index) {
                    final device = state.discoveredDevices[index];
                    return DeviceItemWidget(
                      device: device,
                      onConnect: () {
                        context.read<BluetoothBloc>().add(
                          ConnectToDeviceEvent(device.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Логи',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: BlocBuilder<BluetoothBloc, BluetoothState>(
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
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      child: ListTile(
                        leading: Icon(
                          _getLogIcon(log.level),
                          color: _getLogColor(log.level),
                          size: 16,
                        ),
                        title: Text(
                          log.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: false,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
