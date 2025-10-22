import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../domain/entities/bluetooth_device_entity.dart';
import 'device_details_modal.dart';

class DeviceItemWidget extends StatelessWidget {
  final BluetoothDeviceEntity device;
  final VoidCallback? onConnect;
  final VoidCallback? onReconnect;
  final VoidCallback? onDisconnect;
  final bool isConnecting;
  final bool isConnected;
  final bool wasPreviouslyConnected;

  const DeviceItemWidget({
    super.key,
    required this.device,
    this.onConnect,
    this.onReconnect,
    this.onDisconnect,
    this.isConnecting = false,
    this.isConnected = false,
    this.wasPreviouslyConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      elevation: _getCardElevation(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _getCardBorder(),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _getCardGradient(),
        ),
        child: InkWell(
          onTap: () => _showDeviceDetails(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Иконка устройства с индикатором статуса
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getIconBackgroundColor(),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _getIconBorderColor(),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getDeviceIcon(),
                        color: _getIconColor(),
                        size: 24,
                      ),
                    ),
                    // Индикатор статуса подключения
                    if (isConnected || wasPreviouslyConnected)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            isConnected ? Icons.check : Icons.history,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Информация об устройстве
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.name,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (wasPreviouslyConnected && !isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Ранее подключен',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_shouldShowDeviceType(device.deviceType))
                        Text(
                          device.deviceType,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey.shade400 
                              : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      if (device.rssi != 0) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Tooltip(
                              message: _getRssiTooltip(device.rssi),
                              child: Icon(
                                _getSignalIcon(device.rssi),
                                color: _getSignalColor(device.rssi),
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'RSSI: ${device.rssi} dBm',
                              style: TextStyle(
                                color: _getSignalColor(device.rssi),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Tooltip(
                              message: _getDistanceTooltip(device.rssi),
                              child: Icon(
                                _distanceIcon(device.rssi),
                                size: 16,
                                color: _distanceColor(device.rssi),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '≈ ${_estimateDistanceMeters(device.rssi)}',
                              style: TextStyle(
                                color: _distanceColor(device.rssi),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Кнопка действия
                _buildActionButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isConnecting) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (isConnected) {
      return GestureDetector(
        onTap: () {
          onDisconnect?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.red.shade700, size: 16),
              const SizedBox(width: 4),
              Text(
                'Отключить',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Если устройство не подключаемое, показываем неактивную кнопку
    if (device.isConnectable != true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              color: Colors.grey.shade500,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Недоступно',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Если нет обработчика подключения, показываем неактивную кнопку
    if (onConnect == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              color: Colors.grey.shade500,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Отключено',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        onConnect?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: wasPreviouslyConnected ? Colors.orange.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: wasPreviouslyConnected ? Colors.orange.shade200 : Colors.blue.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              wasPreviouslyConnected ? Icons.refresh : Icons.bluetooth_connected,
              color: wasPreviouslyConnected ? Colors.orange.shade700 : Colors.blue.shade700,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              wasPreviouslyConnected ? 'Переподключить' : 'Подключить',
              style: TextStyle(
                color: wasPreviouslyConnected ? Colors.orange.shade700 : Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DeviceDetailsModal(
        device: device,
        onConnect: onConnect,
        onReconnect: onReconnect,
        isConnecting: isConnecting,
      ),
    );
  }

  // Методы для стилизации карточки
  double _getCardElevation() {
    if (isConnected) return 4;
    if (wasPreviouslyConnected) return 2;
    return 1;
  }

  BorderSide _getCardBorder() {
    if (isConnected) {
      return BorderSide(color: Colors.green.shade300, width: 1);
    }
    if (wasPreviouslyConnected) {
      return BorderSide(color: Colors.orange.shade300, width: 1);
    }
    return BorderSide.none;
  }

  LinearGradient? _getCardGradient() {
    if (isConnected) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.green.shade50,
          Colors.white,
        ],
      );
    }
    if (wasPreviouslyConnected) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.orange.shade50,
          Colors.white,
        ],
      );
    }
    return null;
  }

  Color _getIconBackgroundColor() {
    if (isConnected) return Colors.green.shade100;
    if (wasPreviouslyConnected) return Colors.orange.shade100;
    return Colors.blue.shade100;
  }

  Color _getIconBorderColor() {
    if (isConnected) return Colors.green.shade300;
    if (wasPreviouslyConnected) return Colors.orange.shade300;
    return Colors.blue.shade300;
  }

  Color _getIconColor() {
    if (isConnected) return Colors.green.shade700;
    if (wasPreviouslyConnected) return Colors.orange.shade700;
    return Colors.blue.shade700;
  }


  IconData _getSignalIcon(int rssi) {
    if (rssi >= -50) return Icons.signal_wifi_4_bar;
    if (rssi >= -60) return Icons.network_wifi_3_bar;
    if (rssi >= -70) return Icons.network_wifi_2_bar;
    if (rssi >= -80) return Icons.network_wifi_1_bar;
    return Icons.signal_wifi_0_bar;
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lightGreen;
    if (rssi >= -70) return Colors.orange;
    if (rssi >= -80) return Colors.deepOrange;
    return Colors.red;
  }

  bool _shouldShowDeviceType(String type) {
    final t = type.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (t == 'bluetooth устройство' || t == 'bluetooth-устройство' || t == 'неизвестное устройство') return false;
    return true;
  }

  String _estimateDistanceMeters(int rssi) {
    // Простая оценка дистанции по RSSI.
    // Используем стандартные значения: TxPower = -59 dBm, коэффициент распространения n = 2.0 (помещение)
    const txPower = -59; // dBm
    const pathLossExponent = 2.0;
    final ratio = (txPower - rssi) / (10 * pathLossExponent);
    final distance = math.pow(10, ratio).toDouble();
    // Ограничим до 2 знаков после запятой и добавим единицы измерения
    final meters = distance.isFinite ? distance : double.infinity;
    if (!meters.isFinite) return '—';
    if (meters < 1) {
      return '${meters.toStringAsFixed(2)} м';
    } else if (meters < 10) {
      return '${meters.toStringAsFixed(1)} м';
    }
    return '${meters.toStringAsFixed(0)} м';
  }

  IconData _distanceIcon(int rssi) {
    if (rssi >= -50) return Icons.podcasts; // очень близко
    if (rssi >= -65) return Icons.wifi_tethering; // близко
    if (rssi >= -75) return Icons.wifi_tethering_error; // средне
    if (rssi >= -85) return Icons.wifi_tethering_off; // далеко
    return Icons.satellite_alt; // очень далеко/слабый
  }

  Color _distanceColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -65) return Colors.lightGreen;
    if (rssi >= -75) return Colors.orange;
    if (rssi >= -85) return Colors.deepOrange;
    return Colors.red;
  }

  String _getRssiTooltip(int rssi) {
    if (rssi >= -50) return 'Отличный сигнал\n(-30 до -50 dBm)';
    if (rssi >= -60) return 'Хороший сигнал\n(-50 до -60 dBm)';
    if (rssi >= -70) return 'Удовлетворительный сигнал\n(-60 до -70 dBm)';
    if (rssi >= -80) return 'Слабый сигнал\n(-70 до -80 dBm)';
    return 'Очень слабый сигнал\n(ниже -80 dBm)';
  }

  String _getDistanceTooltip(int rssi) {
    final distance = _estimateDistanceMeters(rssi);
    if (rssi >= -50) return 'Очень близко\n≈ $distance';
    if (rssi >= -65) return 'Близко\n≈ $distance';
    if (rssi >= -75) return 'Среднее расстояние\n≈ $distance';
    if (rssi >= -85) return 'Далеко\n≈ $distance';
    return 'Очень далеко\n≈ $distance';
  }


  IconData _getDeviceIcon() {
    switch (device.deviceType) {
      case 'Телефон/Планшет':
        return Icons.phone_android;
      case 'Умные часы':
        return Icons.watch;
      case 'Фитнес устройство':
        return Icons.fitness_center;
      case 'Аудио устройство':
        return Icons.headphones;
      case 'Компьютер':
        return Icons.laptop;
      case 'Игровое устройство':
        return Icons.sports_esports;
      case 'Автомобиль':
        return Icons.directions_car;
      case 'Умный дом':
        return Icons.home;
      case 'Принтер':
        return Icons.print;
      case 'Медицинское устройство':
        return Icons.medical_services;
      case 'Устройство ввода':
        return Icons.keyboard;
      case 'Неизвестное устройство':
        return Icons.device_unknown;
      default:
        return Icons.bluetooth;
    }
  }
}
