import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/ble_peripheral_service.dart';
import '../../data/services/native_bluetooth_connection_service.dart';
import '../../data/services/app_logger.dart';
import '../../../fitness/presentation/screens/treadmill_hud_screen.dart';
import '../../../fitness/data/services/treadmill_data_parser.dart';
import '../../../fitness/domain/entities/treadmill_data_entity.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Расшифровка стандартных UUID сервисов BLE
String _getServiceName(String uuid) {
  final uuidLower = uuid.toLowerCase().replaceAll('-', '');
  
  // Стандартные GATT сервисы
  if (uuidLower.contains('1800')) return 'Generic Access Profile (GAP)';
  if (uuidLower.contains('1801')) return 'Generic Attribute Profile (GATT)';
  if (uuidLower.contains('180a')) return 'Device Information';
  if (uuidLower.contains('180f')) return 'Battery Service';
  if (uuidLower.contains('180d')) return 'Heart Rate Service';
  if (uuidLower.contains('1826')) return 'Fitness Machine Service';
  if (uuidLower.contains('1816')) return 'Cycling Speed and Cadence';
  if (uuidLower.contains('1818')) return 'Cycling Power';
  if (uuidLower.contains('1812')) return 'HID over GATT';
  if (uuidLower.contains('181c')) return 'User Data Service';
  
  return 'Пользовательский сервис';
}

/// Расшифровка стандартных UUID характеристик BLE
String _getCharacteristicName(String uuid) {
  final uuidLower = uuid.toLowerCase().replaceAll('-', '');
  
  // Стандартные GATT характеристики
  if (uuidLower.contains('2a00')) return 'Device Name';
  if (uuidLower.contains('2a01')) return 'Appearance';
  if (uuidLower.contains('2a02')) return 'Peripheral Privacy Flag';
  if (uuidLower.contains('2a03')) return 'Reconnection Address';
  if (uuidLower.contains('2a04')) return 'Peripheral Preferred Connection Parameters';
  if (uuidLower.contains('2a05')) return 'Service Changed';
  if (uuidLower.contains('2a19')) return 'Battery Level';
  if (uuidLower.contains('2a29')) return 'Manufacturer Name String';
  if (uuidLower.contains('2a24')) return 'Model Number String';
  if (uuidLower.contains('2a25')) return 'Serial Number String';
  if (uuidLower.contains('2a27')) return 'Hardware Revision String';
  if (uuidLower.contains('2a26')) return 'Firmware Revision String';
  if (uuidLower.contains('2a28')) return 'Software Revision String';
  if (uuidLower.contains('2a37')) return 'Heart Rate Measurement';
  if (uuidLower.contains('2a38')) return 'Body Sensor Location';
  if (uuidLower.contains('2ad9')) return 'Fitness Machine Control Point';
  if (uuidLower.contains('2ada')) return 'Fitness Machine Status';
  if (uuidLower.contains('2acd')) return 'Treadmill Data';
  if (uuidLower.contains('2aa6')) return 'Central Address Resolution';
  
  return 'Пользовательская характеристика';
}

/// Описание сервиса
String _getServiceDescription(String uuid) {
  final uuidLower = uuid.toLowerCase().replaceAll('-', '');
  
  if (uuidLower.contains('1800')) return 'Основные параметры устройства (имя, внешний вид)';
  if (uuidLower.contains('1801')) return 'Управление атрибутами GATT сервера';
  if (uuidLower.contains('180a')) return 'Информация о производителе и модели устройства';
  if (uuidLower.contains('180f')) return 'Информация о заряде батареи';
  if (uuidLower.contains('180d')) return 'Мониторинг сердечного ритма';
  if (uuidLower.contains('1826')) return 'Данные от фитнес-оборудования (дорожки, велотренажеры)';
  
  return 'Специфичный сервис устройства';
}

class TreadmillDataModal extends StatefulWidget {
  final String deviceName;
  final String deviceAddress;

  const TreadmillDataModal({
    super.key,
    required this.deviceName,
    required this.deviceAddress,
  });

  @override
  State<TreadmillDataModal> createState() => _TreadmillDataModalState();
}

class _TreadmillDataModalState extends State<TreadmillDataModal> with SingleTickerProviderStateMixin {
  final BlePeripheralService _bleService = BlePeripheralService();
  final NativeBluetoothConnectionService _nativeConnectionService = NativeBluetoothConnectionService();
  final AppLogger _appLogger = AppLogger();
  List<Map<String, dynamic>> _receivedData = [];
  bool _isConnected = true;
  TreadmillDataEntity? _parsedData;
  
  // Вкладки
  late TabController _tabController;
  
  // Информация о сервисах
  List<Map<String, dynamic>> _services = [];
  int _subscribedCount = 0;
  int _readCharacteristicsCount = 0;
  
  StreamSubscription? _dataSubscription;
  StreamSubscription? _servicesSubscription;
  StreamSubscription? _nativeDataSubscription;
  StreamSubscription? _nativeServicesSubscription;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupDataListeners();
    _setupServicesListeners();
    _loadServicesInfo();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _dataSubscription?.cancel();
    _servicesSubscription?.cancel();
    _nativeDataSubscription?.cancel();
    _nativeServicesSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _loadServicesInfo() async {
    try {
      // Пробуем получить информацию о сервисах через FlutterBluePlus
      final device = BluetoothDevice.fromId(widget.deviceAddress);
      if (device.isConnected) {
        final services = await device.discoverServices();
        setState(() {
          _services = services.map((service) {
            final characteristics = service.characteristics.map((char) {
              final hasNotify = char.properties.notify;
              final hasIndicate = char.properties.indicate;
              final hasRead = char.properties.read;
              final hasWrite = char.properties.write;
              
              return {
                'uuid': char.uuid.toString(),
                'properties': {
                  'read': hasRead,
                  'write': hasWrite,
                  'writeWithoutResponse': char.properties.writeWithoutResponse,
                  'notify': hasNotify,
                  'indicate': hasIndicate,
                },
                'hasNotify': hasNotify,
                'hasIndicate': hasIndicate,
                'hasRead': hasRead,
                'hasWrite': hasWrite,
              };
            }).toList();
            
            return {
              'uuid': service.uuid.toString(),
              'type': 'primary',
              'characteristics': characteristics,
            };
          }).toList();
          
          // Подсчитываем подписки
          _subscribedCount = _services.expand((s) => s['characteristics'] as List)
              .where((char) => char['hasNotify'] == true || char['hasIndicate'] == true)
              .length;
          
          _readCharacteristicsCount = _services.expand((s) => s['characteristics'] as List)
              .where((char) => char['hasRead'] == true && char['hasNotify'] != true && char['hasIndicate'] != true)
              .length;
        });
      }
    } catch (e) {
      print('TreadmillDataModal: Ошибка загрузки сервисов: $e');
    }
  }
  
  void _setupServicesListeners() {
    // Слушаем обнаружение сервисов через нативное подключение
    _nativeServicesSubscription = _nativeConnectionService.servicesStream.listen(
      (servicesData) {
        if (mounted && servicesData['deviceAddress'] == widget.deviceAddress) {
          final services = servicesData['services'] as List<dynamic>?;
          if (services != null) {
            setState(() {
              _services = services.map((s) => Map<String, dynamic>.from(s)).toList();
              _subscribedCount = servicesData['subscribedCount'] as int? ?? 0;
              _readCharacteristicsCount = servicesData['readCharacteristicsCount'] as int? ?? 0;
            });
          }
        }
      },
    );
  }

  void _setupDataListeners() {
    // Слушаем данные от дорожки (эмуляция)
    _dataSubscription = _bleService.dataReceivedStream.listen(
      (data) {
        print('TreadmillDataModal: Получены данные от BLE сервиса (эмуляция)');
        print('TreadmillDataModal: deviceAddress в данных: ${data['deviceAddress']}');
        print('TreadmillDataModal: widget.deviceAddress: ${widget.deviceAddress}');
        if (mounted) {
          _processReceivedData(data);
        }
      },
      onError: (error) {
        print('TreadmillDataModal: Ошибка получения данных: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка получения данных: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
    
    // Слушаем данные от нативного подключения
    _nativeDataSubscription = _nativeConnectionService.dataStream.listen(
      (data) {
        print('TreadmillDataModal: ===== ПОЛУЧЕНЫ ДАННЫЕ ОТ НАТИВНОГО ПОДКЛЮЧЕНИЯ =====');
        print('TreadmillDataModal: Все данные: $data');
        print('TreadmillDataModal: deviceAddress в данных: ${data['deviceAddress']}');
        print('TreadmillDataModal: widget.deviceAddress: ${widget.deviceAddress}');
        print('TreadmillDataModal: hexData: ${data['hexData']}');
        print('TreadmillDataModal: dataSize: ${data['dataSize']}');
        
        if (mounted) {
          // Проверяем совпадение адресов (без учета регистра и разделителей)
          final dataAddress = (data['deviceAddress'] as String?)?.toUpperCase().replaceAll(':', '').replaceAll('-', '');
          final widgetAddress = widget.deviceAddress.toUpperCase().replaceAll(':', '').replaceAll('-', '');
          
          print('TreadmillDataModal: dataAddress (нормализованный): $dataAddress');
          print('TreadmillDataModal: widgetAddress (нормализованный): $widgetAddress');
          print('TreadmillDataModal: Совпадение: ${dataAddress == widgetAddress}');
          
          if (dataAddress == widgetAddress || dataAddress == null || dataAddress.isEmpty) {
            print('TreadmillDataModal: Адреса совпадают или адрес пустой, обрабатываем данные');
            _processReceivedData(data);
          } else {
            print('TreadmillDataModal: Адреса не совпадают, НО ОБРАБАТЫВАЕМ ДАННЫЕ ДЛЯ ДИАГНОСТИКИ');
            // Временно обрабатываем все данные для диагностики
            _processReceivedData(data);
          }
        }
      },
      onError: (error) {
        print('TreadmillDataModal: Ошибка получения данных от нативного подключения: $error');
      },
    );

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
    
    print('TreadmillDataModal: Слушатели данных настроены для устройства: ${widget.deviceAddress}');
  }
  
  void _processReceivedData(Map<String, dynamic> data) {
    try {
      print('TreadmillDataModal: Обработка полученных данных');
      print('TreadmillDataModal: Данные: ${data.keys}');
      print('TreadmillDataModal: hexData: ${data['hexData']}');
      print('TreadmillDataModal: dataSize: ${data['dataSize']}');
      
      // Логируем данные через AppLogger для отображения в логах
      final deviceAddress = data['deviceAddress'] as String? ?? widget.deviceAddress;
      final deviceName = data['deviceName'] as String? ?? widget.deviceName;
      _appLogger.logDataReceived(deviceName, deviceAddress, data);
      
      // Парсим данные
      final parsed = TreadmillDataParser.parseData(
        data,
        deviceName: widget.deviceName,
        characteristicUuid: data['characteristicUuid'] as String?,
      );
      
      print('TreadmillDataModal: Распарсенные данные: $parsed');
      
      setState(() {
        _receivedData.insert(0, {
          'timestamp': DateTime.now(),
          'data': data,
        });
        // Ограничиваем количество записей
        if (_receivedData.length > 50) {
          _receivedData.removeLast();
        }
        
        // Обновляем распарсенные данные
        if (parsed != null) {
          _parsedData = parsed;
        }
      });
      
      print('TreadmillDataModal: Данные добавлены в список, всего: ${_receivedData.length}');
    } catch (e) {
      print('TreadmillDataModal: Ошибка парсинга данных: $e');
      print('TreadmillDataModal: Stack trace: ${StackTrace.current}');
      // Продолжаем показывать сырые данные даже если парсинг не удался
      setState(() {
        _receivedData.insert(0, {
          'timestamp': DateTime.now(),
          'data': data,
        });
        if (_receivedData.length > 50) {
          _receivedData.removeLast();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            // Минимальный заголовок
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade800,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_run,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Данные от ${widget.deviceName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // Кнопка открытия HUD если есть распарсенные данные
                  if (_parsedData != null)
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TreadmillHudScreen(
                              deviceName: widget.deviceName,
                              deviceAddress: widget.deviceAddress,
                              useTestData: false,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.speed, color: Colors.white, size: 20),
                      tooltip: 'Открыть HUD',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ),
            
            // Статус подключения под заголовком
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isConnected ? Colors.green : Colors.red).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? 'Подключено' : 'Отключено',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Вкладки
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue.shade600,
              labelColor: Colors.blue.shade800,
              unselectedLabelColor: Colors.grey.shade600,
              tabs: const [
                Tab(
                  icon: Icon(Icons.data_usage, size: 20),
                  text: 'Данные',
                ),
                Tab(
                  icon: Icon(Icons.bluetooth_searching, size: 20),
                  text: 'Сервисы',
                ),
                Tab(
                  icon: Icon(Icons.code, size: 20),
                  text: 'Сырые данные',
                ),
              ],
            ),
            
            // Компактные счетчики (только для вкладки данных)
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                if (_tabController.index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSimpleCounterCard(
                            'Данных получено',
                            _receivedData.length.toString(),
                            Icons.analytics,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSimpleCounterCard(
                            'Последнее обновление',
                            _receivedData.isNotEmpty 
                              ? '${DateTime.now().difference(_receivedData.first['timestamp'] as DateTime).inSeconds}с'
                              : 'Нет данных',
                            Icons.schedule,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            // Содержимое вкладок
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Вкладка данных
                  _buildDataTab(),
                  // Вкладка сервисов
                  _buildServicesTab(),
                  // Вкладка сырых данных
                  _buildRawDataTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _receivedData.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.bluetooth_connected,
                          size: 48,
                          color: Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Устройство подключено!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ожидание данных от ${widget.deviceName}...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Данные появятся автоматически',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _receivedData.length,
              itemBuilder: (context, index) {
                final item = _receivedData[index];
                final data = item['data'] as Map<String, dynamic>;
                final timestamp = item['timestamp'] as DateTime;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.grey.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Данные #${_receivedData.length - index}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // UUID характеристики
                        _buildDataRow('UUID:', data['characteristicUuid'] ?? 'Неизвестно'),
                        
                        // Данные в HEX
                        if (data['hexData'] != null)
                          _buildDataRow('HEX:', data['hexData'].toString()),
                        
                        // Данные как строка
                        if (data['data'] != null && data['data'].toString().isNotEmpty)
                          _buildDataRow('Строка:', data['data'].toString()),
                        
                        // Размер данных
                        if (data['dataSize'] != null)
                          _buildDataRow('Размер:', '${data['dataSize']} байт'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
  
  Widget _buildServicesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _services.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Загрузка сервисов...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Подключение к устройству и обнаружение сервисов',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Статистика
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Сервисов', _services.length.toString(), Icons.dns, Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('Подписок', _subscribedCount.toString(), Icons.notifications_active, Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('READ', _readCharacteristicsCount.toString(), Icons.read_more, Colors.orange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Список сервисов
                Expanded(
                  child: ListView.builder(
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      final service = _services[index];
                      final characteristics = service['characteristics'] as List<dynamic>? ?? [];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          leading: Icon(Icons.dns, color: Colors.blue.shade600),
                          title: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getServiceName(service['uuid'] ?? ''),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      service['uuid'] ?? 'Неизвестно',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        color: Colors.grey.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Кнопка "Подписаться" на все характеристики сервиса
                              IconButton(
                                icon: Icon(Icons.notifications_active, size: 20),
                                color: Colors.green.shade600,
                                tooltip: 'Подписаться на все уведомления',
                                onPressed: () => _subscribeToServiceCharacteristics(service),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            _getServiceDescription(service['uuid'] ?? ''),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Характеристики (${characteristics.length}):',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...characteristics.map((char) => _buildCharacteristicItem(char)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildCharacteristicItem(Map<String, dynamic> characteristic) {
    final uuid = characteristic['uuid'] ?? 'Неизвестно';
    final hasNotify = characteristic['hasNotify'] == true;
    final hasIndicate = characteristic['hasIndicate'] == true;
    final hasRead = characteristic['hasRead'] == true;
    final hasWrite = characteristic['hasWrite'] == true;
    final charName = _getCharacteristicName(uuid);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_input_component, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      charName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      uuid,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (hasRead)
                _buildPropertyChip('READ', Colors.blue),
              if (hasWrite)
                _buildPropertyChip('WRITE', Colors.green),
              if (hasNotify)
                _buildPropertyChip('NOTIFY', Colors.orange),
              if (hasIndicate)
                _buildPropertyChip('INDICATE', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Подписаться на все характеристики с NOTIFY/INDICATE в сервисе
  Future<void> _subscribeToServiceCharacteristics(Map<String, dynamic> service) async {
    try {
      final characteristics = service['characteristics'] as List<dynamic>? ?? [];
      final serviceUuid = service['uuid'] as String?;
      
      if (serviceUuid == null || characteristics.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Нет характеристик для подписки'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Пробуем подключиться через FlutterBluePlus
      try {
        final device = BluetoothDevice.fromId(widget.deviceAddress);
        if (device.isConnected) {
          final services = await device.discoverServices();
          final targetService = services.firstWhere(
            (s) => s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase(),
            orElse: () => throw Exception('Сервис не найден'),
          );
          
          int subscribedCount = 0;
          for (final char in targetService.characteristics) {
            if (char.properties.notify || char.properties.indicate) {
              try {
                await char.setNotifyValue(true);
                subscribedCount++;
              } catch (e) {
                print('Ошибка подписки на ${char.uuid}: $e');
              }
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Подписано на $subscribedCount характеристик'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Перезагружаем информацию о сервисах
          await _loadServicesInfo();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подписки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildPropertyChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
  
  Widget _buildSimpleCounterCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRawDataTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          // Информация об устройстве
          _buildRawDataSection(
            'Информация об устройстве',
            Icons.devices,
            [
              _buildRawDataItem('Имя устройства', widget.deviceName),
              _buildRawDataItem('Адрес устройства', widget.deviceAddress),
              _buildRawDataItem('Статус подключения', _isConnected ? 'Подключено' : 'Отключено'),
              _buildRawDataItem('Всего данных получено', '${_receivedData.length}'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Информация о сервисах
          _buildRawDataSection(
            'Сервисы и характеристики',
            Icons.bluetooth_searching,
            [
              _buildRawDataItem('Количество сервисов', '${_services.length}'),
              _buildRawDataItem('Подписок на уведомления', '$_subscribedCount'),
              _buildRawDataItem('READ характеристик', '$_readCharacteristicsCount'),
            ],
          ),
          
          // Детальная информация о сервисах
          if (_services.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._services.map((service) => _buildRawServiceSection(service)),
          ],
          
          const SizedBox(height: 16),
          
          // Все полученные данные
          _buildRawDataSection(
            'Полученные данные (${_receivedData.length})',
            Icons.data_usage,
            _receivedData.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Данные еще не получены',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ]
                : _receivedData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final data = item['data'] as Map<String, dynamic>;
                    final timestamp = item['timestamp'] as DateTime;
                    
                    return _buildRawDataCard(
                      'Данные #${_receivedData.length - index}',
                      timestamp,
                      data,
                    );
                  }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRawDataSection(String title, IconData icon, List<Widget> children) {
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
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
  
  Widget _buildRawDataItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRawServiceSection(Map<String, dynamic> service) {
    final characteristics = service['characteristics'] as List<dynamic>? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Icon(Icons.dns, color: Colors.blue.shade600, size: 20),
        title: Text(
          _getServiceName(service['uuid'] ?? ''),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          service['uuid'] ?? 'Неизвестно',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: Colors.grey.shade600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRawDataItem('UUID сервиса', service['uuid'] ?? 'Неизвестно'),
                _buildRawDataItem('Тип', service['type'] ?? 'Неизвестно'),
                _buildRawDataItem('Количество характеристик', '${characteristics.length}'),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                ...characteristics.map((char) => _buildRawCharacteristicItem(char)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRawCharacteristicItem(Map<String, dynamic> char) {
    final properties = char['properties'] as Map<String, dynamic>? ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getCharacteristicName(char['uuid'] ?? ''),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildRawDataItem('UUID', char['uuid'] ?? 'Неизвестно'),
          const SizedBox(height: 4),
          Text(
            'Свойства:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (properties['read'] == true)
                _buildPropertyChip('READ', Colors.blue),
              if (properties['write'] == true)
                _buildPropertyChip('WRITE', Colors.green),
              if (properties['writeWithoutResponse'] == true)
                _buildPropertyChip('WRITE_NO_RESPONSE', Colors.lightGreen),
              if (properties['notify'] == true)
                _buildPropertyChip('NOTIFY', Colors.orange),
              if (properties['indicate'] == true)
                _buildPropertyChip('INDICATE', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRawDataCard(String title, DateTime timestamp, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Icon(Icons.data_object, color: Colors.green.shade600, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Все поля данных
                ...data.entries.map((entry) {
                  final key = entry.key;
                  final value = entry.value;
                  
                  if (value == null) return const SizedBox.shrink();
                  
                  String displayValue;
                  if (value is List) {
                    displayValue = value.join(', ');
                  } else if (value is Map) {
                    displayValue = value.toString();
                  } else {
                    displayValue = value.toString();
                  }
                  
                  return _buildRawDataItem(key, displayValue);
                }).toList(),
                
                // HEX данные отдельно
                if (data['hexData'] != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'HEX данные:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      data['hexData'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
                
                // Raw данные (байты)
                if (data['rawData'] != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Raw данные (байты):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      data['rawData'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

