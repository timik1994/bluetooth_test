import 'package:flutter/material.dart';
import '../../data/services/ble_peripheral_service.dart';

class TreadmillDataScreen extends StatefulWidget {
  final String deviceName;
  final String deviceAddress;

  const TreadmillDataScreen({
    super.key,
    required this.deviceName,
    required this.deviceAddress,
  });

  @override
  State<TreadmillDataScreen> createState() => _TreadmillDataScreenState();
}

class _TreadmillDataScreenState extends State<TreadmillDataScreen> {
  final BlePeripheralService _bleService = BlePeripheralService();
  List<Map<String, dynamic>> _receivedData = [];
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _setupDataListeners();
  }

  void _setupDataListeners() {
    // Слушаем данные от дорожки
    _bleService.dataReceivedStream.listen((data) {
      if (mounted) {
        setState(() {
          _receivedData.insert(0, {
            'timestamp': DateTime.now(),
            'data': data,
          });
          // Ограничиваем количество записей
          if (_receivedData.length > 100) {
            _receivedData.removeLast();
          }
        });
      }
    });

    // Слушаем отключение устройства
    _bleService.deviceDisconnectedStream.listen((address) {
      if (address == widget.deviceAddress && mounted) {
        setState(() {
          _isConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Дорожка отключилась: ${widget.deviceName}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Данные от дорожки'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          Icon(
            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Информация о подключении
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
            child: Row(
              children: [
                Icon(
                  Icons.directions_run,
                  color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.deviceName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'MAC: ${widget.deviceAddress}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isConnected ? 'Подключено' : 'Отключено',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Счетчик данных
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCounterCard(
                  'Получено данных',
                  _receivedData.length.toString(),
                  Icons.data_usage,
                  Colors.blue,
                ),
                _buildCounterCard(
                  'Последнее обновление',
                  _receivedData.isNotEmpty 
                    ? '${DateTime.now().difference(_receivedData.first['timestamp'] as DateTime).inSeconds}с назад'
                    : 'Нет данных',
                  Icons.update,
                  Colors.orange,
                ),
              ],
            ),
          ),
          
          // Список полученных данных
          Expanded(
            child: _receivedData.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.bluetooth_connected,
                                  size: 64,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Устройство успешно подключено!',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${widget.deviceName} сопряжен и готов к передаче данных',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.green.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.data_usage, color: Colors.blue.shade600),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ожидание данных от дорожки...',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _receivedData.length,
                    itemBuilder: (context, index) {
                      final item = _receivedData[index];
                      final data = item['data'] as Map<String, dynamic>;
                      final timestamp = item['timestamp'] as DateTime;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Данные #${_receivedData.length - index}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // UUID характеристики
                              _buildDataRow('UUID:', data['characteristicUuid'] ?? 'Неизвестно'),
                              
                              // Данные в HEX
                              if (data['hexData'] != null)
                                _buildDataRow('HEX:', data['hexData'].toString()),
                              
                              // Данные как строка
                              if (data['data'] != null && data['data'].toString().isNotEmpty)
                                _buildDataRow('Строка:', data['data'].toString()),
                              
                              // Сырые данные
                              if (data['rawData'] != null)
                                _buildDataRow('Сырые данные:', data['rawData'].toString()),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
