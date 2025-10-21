import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/treadmill_data_entity.dart';
import '../../data/services/fitness_device_service.dart';

class TreadmillScreen extends StatefulWidget {
  final String deviceName;
  final FitnessDeviceService fitnessService;

  const TreadmillScreen({
    super.key,
    required this.deviceName,
    required this.fitnessService,
  });

  @override
  State<TreadmillScreen> createState() => _TreadmillScreenState();
}

class _TreadmillScreenState extends State<TreadmillScreen> {
  TreadmillDataEntity? _currentData;
  StreamSubscription<TreadmillDataEntity>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  void _subscribeToData() {
    _dataSubscription = widget.fitnessService.treadmillDataStream.listen(
      (data) {
        setState(() {
          _currentData = data;
        });
      },
      onError: (error) {
        // Обработка ошибок
      },
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.deviceName} - Данные'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: _currentData == null 
          ? _buildWaitingState()
          : _buildDataDisplay(),
      ),
    );
  }

  Widget _buildWaitingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Ожидание данных от беговой дорожки...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Начните тренировку на тренажере',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDataDisplay() {
    final data = _currentData!;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Статус подключения
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: data.isRunning ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: data.isRunning ? Colors.green : Colors.grey,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  data.isRunning ? Icons.play_circle_filled : Icons.pause_circle_filled,
                  color: data.isRunning ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  data.isRunning ? 'Тренировка активна' : 'Тренировка приостановлена',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: data.isRunning ? Colors.green.shade800 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Основные метрики
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMetricCard(
                  'Скорость',
                  data.formattedSpeed,
                  Icons.speed,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'Дистанция',
                  data.formattedDistance,
                  Icons.straighten,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Наклон',
                  data.formattedIncline,
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Время',
                  data.formattedTime,
                  Icons.timer,
                  Colors.purple,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Дополнительные метрики
          if (data.heartRate != null || data.calories != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (data.heartRate != null)
                    Column(
                      children: [
                        Icon(Icons.favorite, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '${data.heartRate}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('уд/мин', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (data.calories != null)
                    Column(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '${data.calories}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('ккал', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Время последнего обновления
          Text(
            'Последнее обновление: ${_formatTimestamp(data.timestamp)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 5) {
      return 'только что';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}с назад';
    } else {
      return '${difference.inMinutes}м назад';
    }
  }
}
