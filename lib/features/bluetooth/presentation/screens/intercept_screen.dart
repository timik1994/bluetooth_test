import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart';

class InterceptPage extends StatefulWidget {
  const InterceptPage({super.key});

  @override
  State<InterceptPage> createState() => _InterceptPageState();
}

class _InterceptPageState extends State<InterceptPage> {
  bool _isCollectingData = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Перехват (сырые данные)'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isCollectingData ? Icons.stop : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isCollectingData = !_isCollectingData;
              });
              // Здесь можно добавить логику для управления сбором данных
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Статус сбора данных
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isCollectingData ? Colors.green.shade50 : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(
                  color: _isCollectingData ? Colors.green : Colors.grey,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isCollectingData ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _isCollectingData ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isCollectingData ? 'Сбор данных активен' : 'Сбор данных остановлен',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _isCollectingData ? Colors.green.shade800 : Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                if (_isCollectingData)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Живые данные',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Данные логов в реальном времени
          Expanded(
            child: _buildRawDataDisplay(),
          ),
        ],
      ),
    );
  }

  Widget _buildRawDataDisplay() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        if (state.logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_searching,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ожидание данных...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Начните сканирование или подключитесь к устройству',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Показываем последние 50 логов в режиме реального времени
        final recentLogs = state.logs.reversed.take(50).toList();

        return ListView.builder(
          itemCount: recentLogs.length,
          itemBuilder: (context, index) {
            final log = recentLogs[index];
            return _buildRawDataCard(log);
          },
        );
      },
    );
  }

  Widget _buildRawDataCard(dynamic log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: ExpansionTile(
        leading: Icon(
          _getEventIcon(log.level.toString()),
          color: _getEventColor(log.level.toString()),
          size: 20,
        ),
        title: Text(
          log.message ?? 'Нет сообщения',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(log.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 16),
                if (log.deviceName != null) ...[
                  Icon(Icons.device_hub, size: 12, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.deviceName,
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
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Базовая информация
                _buildInfoSection('Основная информация', {
                  'ID лога': log.id ?? 'N/A',
                  'Уровень': log.level?.toString() ?? 'N/A',
                  'Время': log.timestamp?.toString() ?? 'N/A',
                  'Устройство': log.deviceName ?? 'N/A',
                  'ID устройства': log.deviceId ?? 'N/A',
                }),

                // Дополнительные данные
                if (log.additionalData != null && log.additionalData!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoSection('Дополнительные данные', log.additionalData!),
                ],

                // Если есть байтовые данные - показываем их
                if (_hasBytesData(log)) ...[
                  const SizedBox(height: 16),
                  _buildBytesSection(log),
                ],
              ],
            ),
          ),
        ],
        initiallyExpanded: false,
      ),
    );
  }

  Widget _buildInfoSection(String title, Map<String, dynamic> data) {
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
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
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

  Widget _buildBytesSection(dynamic log) {
    // Извлекаем байтовые данные из additionalData или других полей
    List<int>? bytes = [];
    String? bytesSource = '';

    if (log.additionalData != null) {
      // Ищем байтовые данные в additionalData
      for (var entry in log.additionalData!.entries) {
        if (entry.value is List<int> || entry.value is String) {
          if (entry.value is List<int>) {
            bytes = entry.value as List<int>;
            bytesSource = entry.key;
            break;
          } else if (entry.value is String && entry.value.length > 0) {
            // Попытаемся преобразовать строку в байты
            try {
              bytes = (entry.value as String).codeUnits;
              bytesSource = entry.key;
              break;
            } catch (e) {
              // Игнорируем ошибки
            }
          }
        }
      }
    }

    if (bytes == null || bytes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Данные в байтах (${bytesSource ?? 'неизвестный источник'})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        
        // Hexadecimal формат
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
                'HEX:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' '),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Decimal формат
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
                'DEC:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                bytes.join(' '),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Попытка декодирования как строка
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
                  Icon(Icons.text_fields, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Нормальный вид (UTF-8 декодирование):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                _tryDecodeBytes(bytes),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '💡 Подсказка: HEX и DEC - это разные представления одних и тех же байтов.\n'
                'HEX (шестнадцатеричный) - компактный формат для программистов.\n'
                'DEC (десятичный) - обычные числа от 0 до 255.\n'
                'Нормальный вид - это текст, который получается при декодировании этих байтов.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasBytesData(dynamic log) {
    if (log.additionalData != null) {
      for (var value in log.additionalData!.values) {
        if (value is List<int> || (value is String && value.isNotEmpty)) {
          return true;
        }
      }
    }
    return false;
  }

  String _tryDecodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return 'Нет данных';
    
    // Попытка 1: UTF-8 декодирование
    try {
      final utf8Decoded = String.fromCharCodes(bytes);
      // Проверяем, содержит ли строка читаемые символы (ASCII + некоторые Unicode)
      final hasReadableChars = utf8Decoded.codeUnits.any((c) => 
        (c >= 32 && c <= 126) || // ASCII печатные символы
        c == 9 || c == 10 || c == 13 || // табуляция, новая строка, возврат каретки
        (c >= 160 && c <= 255) // расширенная латиница
      );
      
      if (utf8Decoded.isNotEmpty && hasReadableChars && utf8Decoded.trim().isNotEmpty) {
        // Фильтруем только читаемые символы для отображения
        final readable = utf8Decoded.codeUnits
            .where((c) => (c >= 32 && c <= 126) || c == 9 || c == 10 || c == 13 || (c >= 160 && c <= 255))
            .map((c) => String.fromCharCode(c))
            .join();
        
        if (readable.isNotEmpty) {
          return readable;
        }
      }
    } catch (e) {
      // Продолжаем попытки
    }
    
    // Попытка 2: Только ASCII символы
    try {
      final asciiOnly = bytes
          .where((b) => b >= 32 && b <= 126) // Только ASCII печатные символы
          .map((b) => String.fromCharCode(b))
          .join();
      
      if (asciiOnly.isNotEmpty) {
        return asciiOnly;
      }
    } catch (e) {
      // Продолжаем
    }
    
    // Попытка 3: UTF-8 с фильтрацией проблемных байтов
    try {
      final filteredBytes = bytes.where((b) => b >= 32 && b <= 255).toList();
      if (filteredBytes.isNotEmpty) {
        final utf8Decoded = String.fromCharCodes(filteredBytes);
        
        if (utf8Decoded.isNotEmpty && utf8Decoded.trim().isNotEmpty) {
          return utf8Decoded;
        }
      }
    } catch (e) {
      // Игнорируем
    }
    
    // Если ничего не получилось - показываем информацию о данных
    final printableCount = bytes.where((b) => b >= 32 && b <= 126).length;
    if (printableCount == 0) {
      return 'Только бинарные данные (${bytes.length} байт)';
    } else {
      return 'Частично декодируемо (${printableCount}/${bytes.length} читаемых символов)';
    }
  }

  IconData _getEventIcon(String level) {
    switch (level) {
      case 'LogLevel.error':
        return Icons.error;
      case 'LogLevel.warning':
        return Icons.warning;
      case 'LogLevel.info':
        return Icons.info;
      case 'LogLevel.debug':
        return Icons.bug_report;
      default:
        return Icons.bluetooth;
    }
  }

  Color _getEventColor(String level) {
    switch (level) {
      case 'LogLevel.error':
        return Colors.red;
      case 'LogLevel.warning':
        return Colors.orange;
      case 'LogLevel.info':
        return Colors.blue;
      case 'LogLevel.debug':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

}


