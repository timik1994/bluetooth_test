import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../../domain/entities/bluetooth_log_entity.dart';
import '../../../../core/utils/ble_uuid_decoder.dart';

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
                  _buildLogInfoSection('Дополнительные данные', _formatAdditionalData(log.additionalData!)),
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
    Map<String, List<int>> rawBytesData = {};
    Map<String, String> decodedData = {};
    Map<String, String> hexData = {};
    Map<String, dynamic> interpretedData = {};

    if (log.additionalData != null) {
      for (var entry in log.additionalData!.entries) {
        List<int>? bytes;
        
        // Проверяем различные форматы данных
        if (entry.value is List<int>) {
          bytes = entry.value as List<int>;
        } else if (entry.value is String) {
          final strValue = entry.value as String;
          // Пропускаем строки, которые уже являются декодированными значениями
          if (!strValue.contains(' ') && strValue.length < 50) {
            continue;
          }
          // Пытаемся интерпретировать как hex строку
          if (RegExp(r'^[0-9A-Fa-f\s]+$').hasMatch(strValue)) {
            final hexStr = strValue.replaceAll(' ', '');
            if (hexStr.length % 2 == 0) {
              bytes = [];
              for (int i = 0; i < hexStr.length; i += 2) {
                final byteStr = hexStr.substring(i, i + 2);
                bytes.add(int.parse(byteStr, radix: 16));
              }
            }
          }
        }
        
        if (bytes != null && bytes.isNotEmpty) {
          final key = entry.key;
          rawBytesData[key] = bytes;
          
          // HEX представление
          hexData['$key (hex)'] = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          
          // Декодирование UTF-8
          try {
            // Сначала пробуем декодировать как UTF-8
            String? utf8Decoded;
            try {
              utf8Decoded = utf8.decode(bytes);
              // Проверяем, что декодирование дало осмысленный результат
              // (не только ASCII, но и другие символы)
              if (utf8Decoded.isNotEmpty && utf8Decoded.trim().isNotEmpty) {
                decodedData['$key (UTF-8)'] = utf8Decoded;
              }
            } catch (e) {
              // Если UTF-8 декодирование не удалось, пробуем как простую строку ASCII
              try {
                final asciiDecoded = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
                if (asciiDecoded.isNotEmpty && asciiDecoded.trim().isNotEmpty) {
                  decodedData['$key (ASCII)'] = asciiDecoded;
                }
              } catch (e2) {
                // Игнорируем ошибки декодирования
              }
            }
          } catch (e) {
            // Игнорируем ошибки декодирования
          }
          
          // Интерпретация данных
          final interpretation = _interpretBytes(bytes, key);
          if (interpretation.isNotEmpty) {
            interpretedData[key] = interpretation;
          }
        }
      }
    }

    if (hexData.isEmpty && decodedData.isEmpty && interpretedData.isEmpty) {
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
        
        // Декодированные строки (самое важное)
        if (decodedData.isNotEmpty) ...[
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
                Row(
                  children: [
                    Icon(Icons.text_fields, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Декодированные данные:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...decodedData.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.replaceAll(' (UTF-8)', ''),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
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

        // Интерпретация данных
        if (interpretedData.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Интерпретация:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...interpretedData.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                    ),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // HEX представление (технические детали)
        if (hexData.isNotEmpty) ...[
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
                Row(
                  children: [
                    Icon(Icons.code, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'HEX представление:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...hexData.entries.map((entry) => Padding(
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
                          fontSize: 10,
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
        ],
      ],
    );
  }

  /// Интерпретирует байты в понятный формат
  String _interpretBytes(List<int> bytes, String key) {
    if (bytes.isEmpty) return '';
    
    final interpretations = <String>[];
    
    // Анализ по размеру
    if (bytes.length == 1) {
      interpretations.add('Однобайтовое значение: ${bytes[0]} (0x${bytes[0].toRadixString(16).padLeft(2, '0').toUpperCase()})');
    } else if (bytes.length == 2) {
      final littleEndian = (bytes[1] << 8) | bytes[0];
      final bigEndian = (bytes[0] << 8) | bytes[1];
      interpretations.add('16-битное значение: Little Endian=$littleEndian, Big Endian=$bigEndian');
    } else if (bytes.length == 4) {
      final littleEndian = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
      final bigEndian = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      interpretations.add('32-битное значение: Little Endian=$littleEndian, Big Endian=$bigEndian');
    }
    
    // Попытка интерпретации как число
    if (bytes.length <= 8) {
      try {
        int value = 0;
        for (int i = 0; i < bytes.length; i++) {
          value |= bytes[i] << (i * 8);
        }
        interpretations.add('Как число: $value');
      } catch (e) {
        // Игнорируем
      }
    }
    
    // Анализ для конкретных UUID
    if (key.contains('characteristicUuid') || key.contains('serviceUuid')) {
      final uuidStr = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
      if (uuidStr.length == 4) {
        final decoded = key.contains('characteristicUuid')
            ? BleUuidDecoder.decodeCharacteristicUuid(uuidStr)
            : BleUuidDecoder.decodeServiceUuid(uuidStr);
        if (decoded != uuidStr) {
          interpretations.add('Декодированный UUID: $decoded');
        }
      }
    }
    
    return interpretations.join('; ');
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
          final service = Map<String, dynamic>.from(entry.value as Map);
          final characteristics = service['characteristics'] as List? ?? [];
          final serviceUuid = service['uuid']?.toString() ?? 'Неизвестно';
          final decodedServiceName = BleUuidDecoder.decodeServiceUuid(serviceUuid);
          final serviceDisplayName = decodedServiceName != serviceUuid 
              ? '$decodedServiceName' 
              : null;
          
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceDisplayName ?? 'Сервис ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          if (serviceDisplayName != null)
                            Text(
                              'Сервис ${index + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'UUID: $serviceUuid',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.purple.shade600,
                  ),
                ),
                if (service['type'] != null)
                  Text(
                    'Тип: ${service['type']}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple.shade600,
                    ),
                  ),
                if (characteristics.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Характеристики (${characteristics.length}):',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...characteristics.map((char) {
                    final charMap = Map<String, dynamic>.from(char as Map);
                    final charUuid = charMap['uuid']?.toString() ?? 'Неизвестно';
                    final decodedCharName = BleUuidDecoder.decodeCharacteristicUuid(charUuid);
                    final properties = BleUuidDecoder.formatCharacteristicProperties(charMap['properties']);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.purple.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (decodedCharName != charUuid)
                                      Text(
                                        decodedCharName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    Text(
                                      'UUID: $charUuid',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                        color: Colors.purple.shade600,
                                      ),
                                    ),
                                    if (properties.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Свойства: $properties',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.purple.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDataAnalysis(BluetoothLogEntity log) {
    final analysis = Map<String, dynamic>.from(log.additionalData!['analysis'] as Map);
    
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
    return '${timestamp.day.toString().padLeft(2, '0')}.'
        '${timestamp.month.toString().padLeft(2, '0')}.'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  String _formatFullTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}.'
        '${timestamp.month.toString().padLeft(2, '0')}.'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
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

  /// Форматирует дополнительные данные, декодируя UUID где возможно
  Map<String, dynamic> _formatAdditionalData(Map<String, dynamic> data) {
    final formatted = <String, dynamic>{};
    
    for (var entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Форматируем timestamp в нужный формат
      if (key == 'timestamp' && value is String) {
        try {
          // Пытаемся распарсить ISO8601 формат и преобразовать в нужный формат
          final dateTime = DateTime.parse(value);
          formatted[key] = _formatFullTimestamp(dateTime);
        } catch (e) {
          // Если не удалось распарсить, оставляем как есть
          formatted[key] = value;
        }
      }
      // Декодируем UUID сервисов и характеристик
      else if (key.contains('Uuid') || key.contains('uuid')) {
        if (value is String) {
          final decoded = key.toLowerCase().contains('characteristic')
              ? BleUuidDecoder.formatCharacteristicUuid(value)
              : BleUuidDecoder.formatUuid(value);
          formatted[key] = decoded;
        } else {
          formatted[key] = value;
        }
      } else if (key == 'action' && value is String) {
        // Форматируем action в читаемый вид
        formatted[key] = value.replaceAll('_', ' ').split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
      } else {
        formatted[key] = value;
      }
    }
    
    return formatted;
  }
}
