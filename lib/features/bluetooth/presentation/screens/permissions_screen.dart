import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart';
import '../../../../core/utils/permission_helper.dart';
import '../components/notification.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final statuses = await PermissionHelper.getAllPermissionStatuses();

    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
        _permissionsChecked = true;
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      setState(() {
        _permissionsChecked = false;
      });

      if (context.mounted) {
        MyToastNotification().showInfoToast(context, 'Запрашиваем разрешения...');
      }

      final currentStatuses = await PermissionHelper.getAllPermissionStatuses();
      
      final results = await PermissionHelper.requestRequiredPermissions();
      
      for (final entry in results.entries) {
        currentStatuses[entry.key] = entry.value;
      }

      try {
        final optionalResults = await PermissionHelper.requestOptionalPermissions();
        for (final entry in optionalResults.entries) {
          currentStatuses[entry.key] = entry.value;
        }
      } catch (e) {
        print('Ошибка запроса дополнительных разрешений: $e');
      }

      if (mounted) {
        setState(() {
          _permissionStatuses = currentStatuses;
          _permissionsChecked = true;
        });

        MyToastNotification().showSuccessToast(context, 'Разрешения обновлены!');
      }
    } catch (e) {
      print('Ошибка при запросе разрешений: $e');

      if (mounted) {
        setState(() {
          _permissionsChecked = true;
        });
        MyToastNotification().showErrorToast(context, 'Ошибка запроса разрешений: $e');
      }
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
      Future.delayed(const Duration(seconds: 1), () {
        _checkPermissions();
      });
    } catch (e) {
      if (mounted) {
        MyToastNotification().showErrorToast(context, 'Не удалось открыть настройки: $e');
      }
    }
  }

  Future<void> _forceRequestPermissions() async {
    try {
      setState(() {
        _permissionsChecked = false;
      });

      if (mounted) {
        MyToastNotification().showInfoToast(context, 'Принудительно запрашиваем все разрешения...');
      }

      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.locationAlways,
        Permission.notification,
      ];

      final results = await permissions.request();

      if (mounted) {
        setState(() {
          _permissionStatuses = results;
          _permissionsChecked = true;
        });

        final grantedCount = results.values.where((status) => status.isGranted).length;
        final totalCount = results.length;

        MyToastNotification().showSuccessToast(
          context, 
          'Получено $grantedCount из $totalCount разрешений'
        );
      }
    } catch (e) {
      print('Ошибка при принудительном запросе разрешений: $e');

      if (mounted) {
        setState(() {
          _permissionsChecked = true;
        });
        MyToastNotification().showErrorToast(context, 'Ошибка принудительного запроса: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final allRequiredGranted = PermissionHelper.requiredPermissions.every(
        (permission) => _permissionStatuses[permission]?.isGranted ?? false);
    final grantedCount =
        _permissionStatuses.values.where((status) => status.isGranted).length;
    final totalCount = _permissionStatuses.length;

    return Card(
      margin: const EdgeInsets.all(8),
      color: allRequiredGranted ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        allRequiredGranted
                            ? 'Все обязательные разрешения получены'
                            : 'Требуются разрешения',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: allRequiredGranted
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
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

            Text(
              'Детали разрешений:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 8),

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
                          color: isGranted
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
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
                      color: isGranted
                          ? Colors.green.shade600
                          : Colors.red.shade600,
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
                      state.isBluetoothEnabled
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: state.isBluetoothEnabled ? Colors.blue : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Статус Bluetooth',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: state.isBluetoothEnabled
                            ? Colors.blue.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusItem(
                        'Bluetooth',
                        state.isBluetoothEnabled ? 'Включен' : 'Выключен',
                        state.isBluetoothEnabled),
                    _buildStatusItem(
                        'Устройств', '${state.discoveredDevices.length}', true),
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
}
