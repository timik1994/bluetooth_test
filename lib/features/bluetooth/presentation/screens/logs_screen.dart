import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../../domain/entities/bluetooth_log_entity.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Кнопки управления логами
        _buildLogsControls(context),

        // Логи
        Expanded(
          child: _buildLogsList(),
        ),
      ],
    );
  }

  Widget _buildLogsControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () =>
                context.read<BluetoothBloc>().add(const ClearLogsEvent()),
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
      child: ExpansionTile(
        leading: Icon(
          _getLogIcon(log.level),
          color: _getLogColor(log.level),
          size: 20,
        ),
        title: Text(
          log.message,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _getLogColor(log.level),
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.schedule, size: 12, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              _formatDetailedTimestamp(log.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            if (log.deviceName != null) ...[
              Icon(Icons.device_hub, size: 12, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  log.deviceName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Основная информация
                _buildLogInfoSection('Основная информация', {
                  'ID лога': log.id,
                  'Уровень': _getLogLevelString(log.level),
                  'Сообщение': log.message,
                  'Время создания': _formatFullTimestamp(log.timestamp),
                }),

                // Информация об устройстве
                if (log.deviceName != null || log.deviceId != null) ...[
                  const SizedBox(height: 16),
                  _buildDeviceInfo(log),
                ],

                // Информация о сервисах (если есть)
                if (_hasServicesInfo(log)) ...[
                  const SizedBox(height: 16),
                  _buildServicesInfo(log),
                ],

                // Анализ данных (если есть)
                if (_hasDataAnalysis(log)) ...[
                  const SizedBox(height: 16),
                  _buildDataAnalysis(log),
                ],

                // Дополнительные данные
                if (log.additionalData != null && log.additionalData!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildLogInfoSection('Дополнительные данные', log.additionalData!),
                ],

                // Анализ данных на наличие байтов
                if (_hasRawData(log)) ...[
                  const SizedBox(height: 16),
                  _buildRawDataAnalysis(log),
                ],
              ],
            ),
          ),
        ],
        initiallyExpanded: false,
      ),
    );
  }

  Widget _buildLogInfoSection(String title, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        '${entry.key}:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRawDataAnalysis(BluetoothLogEntity log) {
    // Ищем байтовые данные в additionalData
    Map<String, dynamic> bytesData = {};
    Map<String, String> decodedData = {};

    if (log.additionalData != null) {
      for (var entry in log.additionalData!.entries) {
        if (entry.value is List<int>) {
          final bytes = entry.value as List<int>;
          bytesData['${entry.key} (bytes)'] = bytes;
          decodedData['${entry.key} (hex)'] = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          decodedData['${entry.key} (decimal)'] = bytes.join(' ');
          
          // Попытка декодирования
          try {
            final decoded = String.fromCharCodes(bytes);
            if (RegExp(r'^[\x20-\x7E\x0A\x0D\x09]*$').hasMatch(decoded) && decoded.trim().isNotEmpty) {
              decodedData['${entry.key} (UTF-8)'] = decoded;
            }
          } catch (e) {
            decodedData['${entry.key} (UTF-8)'] = 'Ошибка декодирования';
          }
        } else if (entry.value is String && entry.value.length > 0) {
          // Попытка интерпретации строки как байты
          try {
            final bytes = (entry.value as String).codeUnits;
            if (bytes.length <= 100) { // Ограничиваем для читаемости
              decodedData['${entry.key} (codeUnits)'] = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            }
          } catch (e) {
            // Игнорируем
          }
        }
      }
    }

    if (decodedData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Анализ данных',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 8),
        
        // HEX представление
        if (decodedData.values.any((v) => v.contains(' '))) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HEX представление:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...decodedData.entries.where((e) => e.key.contains('hex') || e.value.contains(' '))
                  .map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        SelectableText(
                          entry.value,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Декодированные строки
        if (decodedData.values.any((v) => !v.contains(' ') && v.length > 0)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Декодированные данные:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...decodedData.entries.where((e) => !e.key.contains('hex') && !e.key.contains('decimal') && !e.value.contains(' '))
                  .map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade600,
                          ),
                        ),
                        SelectableText(
                          entry.value,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _hasRawData(BluetoothLogEntity log) {
    if (log.additionalData != null) {
      return log.additionalData!.values.any((value) => 
        value is List<int> || 
        (value is String && value.length > 0));
    }
    return false;
  }

  bool _hasServicesInfo(BluetoothLogEntity log) {
    return log.additionalData != null && 
           log.additionalData!.containsKey('services') &&
           log.additionalData!['services'] is List;
  }

  bool _hasDataAnalysis(BluetoothLogEntity log) {
    return log.additionalData != null && 
           log.additionalData!.containsKey('analysis') &&
           log.additionalData!['analysis'] is Map;
  }

  Widget _buildServicesInfo(BluetoothLogEntity log) {
    final services = log.additionalData!['services'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сервисы устройства (${services.length})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...services.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value as Map<String, dynamic>;
          final characteristics = service['characteristics'] as List? ?? [];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bluetooth, color: Colors.purple.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Сервис ${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'UUID: ${service['uuid']}',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.purple.shade600,
                  ),
                ),
                Text(
                  'Тип: ${service['type']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple.shade600,
                  ),
                ),
                if (characteristics.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Характеристики (${characteristics.length}):',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  ...characteristics.take(3).map((char) {
                    final charMap = char as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text(
                        '• ${charMap['uuid']} (свойства: ${charMap['properties']})',
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          color: Colors.purple.shade600,
                        ),
                      ),
                    );
                  }),
                  if (characteristics.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text(
                        '... и еще ${characteristics.length - 3}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.purple.shade500,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDataAnalysis(BluetoothLogEntity log) {
    final analysis = log.additionalData!['analysis'] as Map<String, dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Анализ данных',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (analysis['interpretation'] != null) ...[
                _buildAnalysisRow('Интерпретация', analysis['interpretation'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['type'] != null) ...[
                _buildAnalysisRow('Тип данных', analysis['type'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['command'] != null) ...[
                _buildAnalysisRow('Команда', analysis['command'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['value'] != null) ...[
                _buildAnalysisRow('Значение', analysis['value'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['hex'] != null) ...[
                _buildAnalysisRow('HEX', analysis['hex'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['decimal'] != null) ...[
                _buildAnalysisRow('Десятичное', analysis['decimal'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['utf8'] != null) ...[
                _buildAnalysisRow('UTF-8', analysis['utf8'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['littleEndian'] != null) ...[
                _buildAnalysisRow('Little Endian', analysis['littleEndian'].toString()),
                const SizedBox(height: 8),
              ],
              if (analysis['bigEndian'] != null) ...[
                _buildAnalysisRow('Big Endian', analysis['bigEndian'].toString()),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.green.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfo(BluetoothLogEntity log) {
    final deviceInfo = <String, dynamic>{};
    
    if (log.deviceName != null) {
      deviceInfo['Название'] = log.deviceName!;
    }
    if (log.deviceId != null) {
      deviceInfo['ID'] = log.deviceId!;
    }
    
    // Добавляем дополнительную информацию об устройстве из additionalData
    if (log.additionalData != null) {
      if (log.additionalData!['deviceType'] != null) {
        deviceInfo['Тип устройства'] = log.additionalData!['deviceType'];
      }
      if (log.additionalData!['bondState'] != null) {
        deviceInfo['Состояние связи'] = _getBondStateString(log.additionalData!['bondState']);
      }
      if (log.additionalData!['deviceClass'] != null) {
        deviceInfo['Класс устройства'] = log.additionalData!['deviceClass'];
      }
      if (log.additionalData!['deviceClassString'] != null) {
        deviceInfo['Класс (описание)'] = log.additionalData!['deviceClassString'];
      }
    }
    
    return _buildLogInfoSection('Устройство', deviceInfo);
  }

  String _getBondStateString(dynamic bondState) {
    if (bondState == null) return 'Неизвестно';
    
    final state = bondState.toString();
    switch (state) {
      case '10':
        return 'Не связан';
      case '11':
        return 'Связывается';
      case '12':
        return 'Связан';
      default:
        return 'Неизвестно ($state)';
    }
  }

  String _getLogLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.debug:
        return 'DEBUG';
    }
  }

  String _formatDetailedTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  String _formatFullTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}.'
        '${timestamp.month.toString().padLeft(2, '0')}.'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
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
