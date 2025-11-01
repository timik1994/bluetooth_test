import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/entities/treadmill_data_entity.dart';
import '../../../bluetooth/data/services/ble_peripheral_service.dart';
import '../../../bluetooth/data/services/native_bluetooth_connection_service.dart';
import '../../../fitness/data/services/treadmill_data_parser.dart';
import '../../../fitness/data/services/treadmill_control_service.dart';

/// Экран HUD для отображения данных тренировки на беговой дорожке
class TreadmillHudScreen extends StatefulWidget {
  final String? deviceName;
  final String? deviceAddress; // Адрес устройства для управления
  final bool useTestData;

  const TreadmillHudScreen({
    super.key,
    this.deviceName,
    this.deviceAddress,
    this.useTestData = false,
  });

  @override
  State<TreadmillHudScreen> createState() => _TreadmillHudScreenState();
}

class _TreadmillHudScreenState extends State<TreadmillHudScreen> {
  final BlePeripheralService _bleService = BlePeripheralService();
  final NativeBluetoothConnectionService _nativeConnectionService = NativeBluetoothConnectionService();
  
  TreadmillDataEntity? _currentData;
  StreamSubscription? _bleDataSubscription;
  StreamSubscription? _nativeDataSubscription;
  Timer? _testDataTimer;
  
  // Состояние тренировки
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _sessionStartTime;
  Duration _sessionDuration = Duration.zero;
  Timer? _sessionTimer;
  
  // Состояние управления дорожкой
  bool _isSendingCommand = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    if (widget.useTestData) {
      _startTestData();
    } else {
      _setupDataListeners();
    }
    _setupSessionTimer();
  }

  @override
  void dispose() {
    _bleDataSubscription?.cancel();
    _nativeDataSubscription?.cancel();
    _testDataTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _setupDataListeners() {
    // Слушаем данные от BLE периферийного сервиса (эмуляция)
    _bleDataSubscription = _bleService.dataReceivedStream.listen((data) {
      _processRawData(data);
    });

    // Слушаем данные от нативного подключения
    _nativeDataSubscription = _nativeConnectionService.dataStream.listen((data) {
      _processRawData(data);
    });
  }

  void _processRawData(Map<String, dynamic> data) {
    try {
      final deviceName = data['deviceName'] as String? ?? widget.deviceName;
      final characteristicUuid = data['characteristicUuid'] as String?;
      
      // Парсим данные
      final treadmillData = TreadmillDataParser.parseData(
        data,
        deviceName: deviceName,
        characteristicUuid: characteristicUuid,
      );
      
      if (treadmillData != null && mounted) {
        setState(() {
          _currentData = treadmillData;
          _lastError = null; // Очищаем ошибку при успешном получении данных
          // Обновляем состояние тренировки
          if (treadmillData.isRunning && !_isRunning) {
            _startSession();
          } else if (!treadmillData.isRunning && _isRunning) {
            _pauseSession();
          }
        });
      }
    } catch (e) {
      print('TreadmillHudScreen: Ошибка обработки данных: $e');
      final errorMessage = 'Ошибка обработки данных: ${e.toString()}';
      
      if (mounted) {
        setState(() {
          _lastError = errorMessage;
        });
        
        // Показываем ошибку пользователю только если это критично
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startTestData() {
    // Генерируем тестовые данные
    _testDataTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final testData = TreadmillDataEntity(
          speed: 8.5 + (timer.tick % 20) * 0.1, // Меняющаяся скорость
          distance: timer.tick * 2.5, // Метры
          incline: 1.0 + (timer.tick % 10) * 0.5,
          heartRate: 120 + (timer.tick % 30),
          calories: timer.tick * 5,
          elapsedTime: Duration(seconds: timer.tick),
          isRunning: true,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _currentData = testData;
          if (!_isRunning) {
            _startSession();
          }
        });
      }
    });
  }

  void _startSession() {
    if (_sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
    }
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    
    // Отправляем команду старт на дорожку если доступно
    if (widget.deviceAddress != null && !widget.useTestData) {
      _sendTreadmillCommand(true);
    }
  }

  void _pauseSession() {
    setState(() {
      _isPaused = true;
    });
    
    // Отправляем команду пауза на дорожку если доступно
    if (widget.deviceAddress != null && !widget.useTestData) {
      _sendTreadmillCommand(false, pause: true);
    }
  }

  void _resumeSession() {
    if (_sessionStartTime != null) {
      final pausedDuration = DateTime.now().difference(_sessionStartTime!);
      _sessionStartTime = DateTime.now().subtract(_sessionDuration + pausedDuration);
    }
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    
    // Отправляем команду старт на дорожку если доступно
    if (widget.deviceAddress != null && !widget.useTestData) {
      _sendTreadmillCommand(true);
    }
  }

  void _stopSession() {
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _sessionStartTime = null;
      _sessionDuration = Duration.zero;
    });
    
    // Отправляем команду стоп на дорожку если доступно
    if (widget.deviceAddress != null && !widget.useTestData) {
      _sendTreadmillCommand(false);
    }
  }
  
  /// Отправляет команду управления на беговую дорожку
  Future<void> _sendTreadmillCommand(bool start, {bool pause = false}) async {
    if (_isSendingCommand || widget.deviceAddress == null) {
      return;
    }
    
    try {
      setState(() {
        _isSendingCommand = true;
        _lastError = null;
      });
      
      // Получаем подключенное устройство
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      BluetoothDevice? device;
      
      for (final connectedDevice in connectedDevices) {
        if (connectedDevice.remoteId.toString() == widget.deviceAddress) {
          device = connectedDevice;
          break;
        }
      }
      
      // Если устройство не найдено в подключенных, пытаемся создать из ID
      if (device == null) {
        try {
          device = BluetoothDevice.fromId(widget.deviceAddress!);
          if (!device.isConnected) {
            throw Exception('Устройство не подключено');
          }
        } catch (e) {
          throw Exception('Не удалось найти подключенное устройство: $e');
        }
      }
      
      // Отправляем команду
      bool success = false;
      if (pause) {
        success = await TreadmillControlService.sendPause(device);
      } else if (start) {
        success = await TreadmillControlService.sendStartStop(device);
      } else {
        success = await TreadmillControlService.sendStartStop(device); // Стоп обычно та же команда
      }
      
      if (!success) {
        throw Exception('Команда не была отправлена');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pause ? 'Команда пауза отправлена' : start ? 'Команда старт отправлена' : 'Команда стоп отправлена'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('TreadmillHudScreen: Ошибка отправки команды: $e');
      final errorMessage = 'Ошибка отправки команды: ${e.toString()}';
      
      if (mounted) {
        setState(() {
          _lastError = errorMessage;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCommand = false;
        });
      }
    }
  }

  void _setupSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRunning && !_isPaused && _sessionStartTime != null) {
        setState(() {
          _sessionDuration = DateTime.now().difference(_sessionStartTime!);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Блокируем поворот экрана в портретный режим
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // Фоновый градиент
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.grey.shade900,
                    ],
                  ),
                ),
              ),
            ),
            
            // Основной контент
            Column(
              children: [
                // Верхняя панель с информацией
                _buildTopBar(),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Основные метрики
                        _buildMainMetrics(),
                        
                        const SizedBox(height: 24),
                        
                        // Дополнительные данные
                        _buildSecondaryMetrics(),
                        
                        const SizedBox(height: 24),
                        
                        // Кнопки управления
                        _buildControlButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_run, color: Colors.green.shade400, size: 20),
          const SizedBox(width: 8),
          Text(
            widget.deviceName ?? 'Беговая дорожка',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (widget.useTestData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ТЕСТОВЫЕ ДАННЫЕ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainMetrics() {
    return Column(
      children: [
        // Скорость (большой дисплей)
        _buildLargeMetric(
          label: 'СКОРОСТЬ',
          value: _currentData?.formattedSpeed ?? '--',
          icon: Icons.speed,
          color: Colors.blue.shade400,
          size: 80,
        ),
        
        const SizedBox(height: 32),
        
        // Два ряда метрик
        Row(
          children: [
            // Дистанция
            Expanded(
              child: SizedBox(
                height: 120, // Фиксированная высота для всех верхних карточек
                child: _buildMetricCard(
                  label: 'ДИСТАНЦИЯ',
                  value: _currentData?.formattedDistance ?? '--',
                  icon: Icons.straighten,
                  color: Colors.green.shade400,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Пульс
            Expanded(
              child: SizedBox(
                height: 120, // Фиксированная высота для всех верхних карточек
                child: _buildMetricCard(
                  label: 'ПУЛЬС',
                  value: _currentData?.heartRate != null 
                      ? '${_currentData!.heartRate} уд/мин'
                      : '--',
                  icon: Icons.favorite,
                  color: Colors.red.shade400,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Наклон
            Expanded(
              child: SizedBox(
                height: 120, // Фиксированная высота для всех верхних карточек
                child: _buildMetricCard(
                  label: 'НАКЛОН',
                  value: _currentData?.formattedIncline ?? '--',
                  icon: Icons.trending_up,
                  color: Colors.orange.shade400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryMetrics() {
    return Row(
      children: [
        // Время тренировки
        Expanded(
          child: _buildTimeCard(),
        ),
        
        const SizedBox(width: 12),
        
        // Калории
        if (_currentData?.calories != null)
          Expanded(
            child: _buildInfoCard(
              label: 'Калории',
              value: '${_currentData!.calories}',
              icon: Icons.local_fire_department,
              color: Colors.orange.shade400,
            ),
          ),
      ],
    );
  }

  Widget _buildLargeMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double size,
  }) {
    // Разделяем значение на число и единицы измерения для скорости
    String? numberPart;
    String? unitPart;
    
    if (value != '--' && value.contains(' ')) {
      final parts = value.split(' ');
      if (parts.length >= 2) {
        numberPart = parts[0];
        unitPart = parts.sublist(1).join(' ');
      }
    }
    
    return Column(
      children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        numberPart != null && unitPart != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    numberPart,
                    style: TextStyle(
                      color: color,
                      fontSize: size,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unitPart,
                    style: TextStyle(
                      color: color,
                      fontSize: size * 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: size,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    final displayTime = _sessionStartTime != null && _isRunning && !_isPaused
        ? _sessionDuration
        : _currentData?.elapsedTime ?? Duration.zero;
    
    final hours = displayTime.inHours;
    final minutes = displayTime.inMinutes.remainder(60);
    final seconds = displayTime.inSeconds.remainder(60);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade400.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.timer, color: Colors.blue.shade400, size: 28),
          const SizedBox(height: 8),
          Text(
            'ВРЕМЯ',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hours > 0
                ? '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
                : '${minutes}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Colors.blue.shade400,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    final canControl = widget.deviceAddress != null && !widget.useTestData;
    
    return Column(
      children: [
        // Показываем ошибку если есть
        if (_lastError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastError!,
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        Row(
          children: [
            // Старт/Пауза
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isSendingCommand || !canControl) && !widget.useTestData
                    ? null
                    : _isRunning && !_isPaused
                        ? _pauseSession
                        : _isPaused
                            ? _resumeSession
                            : _startSession,
                icon: _isSendingCommand
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _isRunning && !_isPaused
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 24,
                      ),
                label: Text(
                  _isSendingCommand
                      ? 'ОТПРАВКА...'
                      : _isRunning && !_isPaused
                          ? 'ПАУЗА'
                          : _isPaused
                              ? 'ПРОДОЛЖИТЬ'
                              : 'СТАРТ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning && !_isPaused
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade700,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Стоп
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isSendingCommand || !canControl) && !widget.useTestData
                    ? null
                    : _stopSession,
                icon: const Icon(Icons.stop, size: 24),
                label: const Text(
                  'СТОП',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        
        // Информация о том, что управление недоступно
        if (!canControl && !widget.useTestData)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '⚠️ Управление дорожкой недоступно (нет адреса устройства)',
              style: TextStyle(
                color: Colors.orange.shade300,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

