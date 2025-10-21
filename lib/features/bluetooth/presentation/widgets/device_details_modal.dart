import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/bluetooth_device_entity.dart';

class DeviceDetailsModal extends StatelessWidget {
  final BluetoothDeviceEntity device;
  final VoidCallback? onConnect;
  final VoidCallback? onReconnect;
  final bool isConnecting;

  const DeviceDetailsModal({
    super.key,
    required this.device,
    this.onConnect,
    this.onReconnect,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Заголовок модального окна
          _buildHeader(context),
          
          // Содержимое
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeviceInfo(),
                  const SizedBox(height: 24),
                  _buildBluetoothTypeInfo(),
                  const SizedBox(height: 24),
                  _buildTechnicalInfo(),
                  const SizedBox(height: 24),
                  _buildServicesInfo(),
                  const SizedBox(height: 24),
                  _buildConnectionActions(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Индикатор перетаскивания
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Иконка и название устройства
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: device.isConnected ? Colors.green.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  _getDeviceIcon(),
                  color: device.isConnected ? Colors.green.shade700 : Colors.blue.shade700,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.deviceType,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Статус подключения
              if (device.isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Подключено',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return _buildSection(
      'Информация об устройстве',
      Icons.info_outline,
      [
        _buildInfoRow('Название', device.name, copyable: true),
        _buildInfoRow('Тип устройства', device.deviceType),
        _buildInfoRow('Статус', device.isConnected ? 'Подключено' : 'Не подключено'),
        if (device.rssi != 0)
          _buildInfoRow('Сила сигнала', '${device.rssi} dBm (${_getSignalQuality(device.rssi)})'),
      ],
    );
  }

  Widget _buildBluetoothTypeInfo() {
    return _buildSection(
      'Тип Bluetooth',
      device.isClassicBluetooth ? Icons.bluetooth : Icons.bluetooth_connected,
      [
        _buildInfoRow(
          'Протокол', 
          device.isClassicBluetooth ? 'Classic Bluetooth' : 'Bluetooth Low Energy (BLE)'
        ),
        _buildInfoRow(
          'Версия', 
          device.isClassicBluetooth ? 'Bluetooth 2.0+' : 'Bluetooth 4.0+'
        ),
        if (device.isBonded)
          _buildInfoRow('Сопряжение', 'Устройство сопряжено'),
        _buildInfoRow(
          'Возможности', 
          device.isClassicBluetooth 
            ? 'Передача файлов, аудио, последовательная связь'
            : 'Низкое энергопотребление, датчики, уведомления'
        ),
        _buildInfoRow(
          'Дальность', 
          device.isClassicBluetooth ? 'До 10 метров' : 'До 50 метров'
        ),
        _buildInfoRow(
          'Энергопотребление', 
          device.isClassicBluetooth ? 'Высокое' : 'Очень низкое'
        ),
      ],
    );
  }

  String _getSignalQuality(int rssi) {
    if (rssi >= -30) return 'Отличный';
    if (rssi >= -50) return 'Хороший';
    if (rssi >= -70) return 'Средний';
    if (rssi >= -90) return 'Слабый';
    return 'Очень слабый';
  }

  Widget _buildTechnicalInfo() {
    return _buildSection(
      'Техническая информация',
      Icons.settings,
      [
        _buildInfoRow('ID устройства', device.id, copyable: true),
        _buildInfoRow('MAC-адрес', _formatMacAddress(device.id), copyable: true),
        _buildInfoRow('Количество сервисов', '${device.serviceUuids.length}'),
        if (device.rssi != 0) ...[
          _buildInfoRow('RSSI', '${device.rssi} dBm'),
          _buildInfoRow('Качество сигнала', _getSignalQuality(device.rssi)),
        ],
      ],
    );
  }

  Widget _buildServicesInfo() {
    return _buildSection(
      'Bluetooth сервисы',
      Icons.bluetooth,
      [
        if (device.serviceUuids.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Сервисы не обнаружены или устройство не подключено',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...device.serviceUuids.map((uuid) => _buildServiceItem(uuid)),
      ],
    );
  }

  Widget _buildConnectionActions(BuildContext context) {
    return _buildSection(
      'Действия',
      Icons.settings_remote,
      [
        const SizedBox(height: 8),
        if (device.isConnected)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Здесь можно добавить действие отключения
              },
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('Отключиться'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        else if (isConnecting)
           SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Подключение...'),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConnect?.call();
                  },
                  icon: const Icon(Icons.bluetooth_connected),
                  label: const Text('Подключиться'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (onReconnect != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onReconnect?.call();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Переподключиться'),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (copyable)
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Скопировано: $value'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(String uuid) {
    final serviceName = _getServiceName(uuid);
    final serviceDescription = _getServiceDescription(uuid);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              Icon(Icons.bluetooth_audio, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  serviceName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: uuid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('UUID скопирован: $uuid'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            serviceDescription,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'UUID: $uuid',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
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

  String _formatMacAddress(String deviceId) {
    // Форматируем MAC-адрес для лучшего отображения
    if (deviceId.length == 17 && deviceId.contains(':')) {
      return deviceId.toUpperCase();
    }
    return deviceId;
  }


  String _getServiceName(String uuid) {
    final uuidLower = uuid.toLowerCase();
    
    // Стандартные Bluetooth сервисы
    if (uuidLower.contains('110b')) return 'A2DP (Аудио)';
    if (uuidLower.contains('110e')) return 'AVRCP (Управление аудио)';
    if (uuidLower.contains('1108')) return 'Headset Profile';
    if (uuidLower.contains('111e')) return 'Handsfree Profile';
    if (uuidLower.contains('180f')) return 'Battery Service';
    if (uuidLower.contains('1812')) return 'HID over GATT';
    if (uuidLower.contains('1124')) return 'Human Interface Device';
    if (uuidLower.contains('180d')) return 'Heart Rate Service';
    if (uuidLower.contains('1816')) return 'Cycling Speed and Cadence';
    if (uuidLower.contains('1818')) return 'Cycling Power';
    if (uuidLower.contains('181c')) return 'User Data Service';
    if (uuidLower.contains('1800')) return 'Generic Access';
    if (uuidLower.contains('1801')) return 'Generic Attribute';
    if (uuidLower.contains('180a')) return 'Device Information';
    
    return 'Неизвестный сервис';
  }

  String _getServiceDescription(String uuid) {
    final uuidLower = uuid.toLowerCase();
    
    if (uuidLower.contains('110b')) return 'Передача аудио высокого качества';
    if (uuidLower.contains('110e')) return 'Управление воспроизведением аудио';
    if (uuidLower.contains('1108')) return 'Профиль гарнитуры';
    if (uuidLower.contains('111e')) return 'Профиль громкой связи';
    if (uuidLower.contains('180f')) return 'Информация о заряде батареи';
    if (uuidLower.contains('1812')) return 'Устройства ввода через GATT';
    if (uuidLower.contains('1124')) return 'Клавиатуры, мыши, геймпады';
    if (uuidLower.contains('180d')) return 'Мониторинг сердечного ритма';
    if (uuidLower.contains('1816')) return 'Скорость и каденс велосипеда';
    if (uuidLower.contains('1818')) return 'Мощность велосипеда';
    if (uuidLower.contains('181c')) return 'Пользовательские данные';
    if (uuidLower.contains('1800')) return 'Основные параметры устройства';
    if (uuidLower.contains('1801')) return 'Атрибуты GATT';
    if (uuidLower.contains('180a')) return 'Информация о производителе и модели';
    
    return 'Специфичный сервис устройства';
  }
}
