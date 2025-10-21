import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/entities/bluetooth_log_entity.dart';

class LogItemWidget extends StatefulWidget {
  final BluetoothLogEntity log;
  final BluetoothDeviceEntity? device;

  const LogItemWidget({
    super.key,
    required this.log,
    this.device,
  });

  @override
  State<LogItemWidget> createState() => _LogItemWidgetState();
}

class _LogItemWidgetState extends State<LogItemWidget> {
  bool _expanded = false;

  BluetoothLogEntity get log => widget.log;
  BluetoothDeviceEntity? get device => widget.device;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getBorderColor(),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIcon(),
                  size: 16,
                  color: _getIconColor(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getLevelText(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getIconColor(),
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  _formatTime(log.timestamp),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              log.message,
              style: const TextStyle(fontSize: 14),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              if (device != null) ...[
                _buildDetailRow('Устройство', device!.name),
                _buildDetailRow('ID', device!.id),
                _buildDetailRow('Тип', device!.deviceType),
                _buildDetailRow('RSSI', '${device!.rssi} dBm'),
                _buildDetailRow('Дистанция', '≈ ${_estimateDistanceMeters(device!.rssi)}'),
                _buildDetailRow('Сервисы', device!.serviceUuids.isEmpty ? 'Нет' : device!.serviceUuids.join(', ')),
                const SizedBox(height: 8),
              ] else ...[
                _buildDetailRow('ID лога', log.id),
                if (log.deviceName != null)
                  _buildDetailRow('Устройство', log.deviceName!),
                if (log.deviceId != null)
                  _buildDetailRow('ID устройства', log.deviceId!),
              ],
              if (log.additionalData != null && log.additionalData!.isNotEmpty) ...[
                _buildDetailRow('Доп. данные', ''),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildPrettyJson(log.additionalData!),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildPrettyJson(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    void writeValue(String key, dynamic value, int indent) {
      final prefix = ' ' * indent;
      if (value is Map) {
        buffer.writeln('$prefix$key:');
        value.forEach((k, v) => writeValue('$k', v, indent + 2));
      } else if (value is List) {
        buffer.writeln('$prefix$key:');
        for (var i = 0; i < value.length; i++) {
          writeValue('[$i]', value[i], indent + 2);
        }
      } else {
        buffer.writeln('$prefix$key: $value');
      }
    }

    data.forEach((k, v) => writeValue(k, v, 0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          buffer.toString(),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (log.level) {
      case LogLevel.error:
        return Colors.red.shade50;
      case LogLevel.warning:
        return Colors.orange.shade50;
      case LogLevel.info:
        return Colors.blue.shade50;
      case LogLevel.debug:
        return Colors.grey.shade50;
    }
  }

  Color _getBorderColor() {
    switch (log.level) {
      case LogLevel.error:
        return Colors.red.shade300;
      case LogLevel.warning:
        return Colors.orange.shade300;
      case LogLevel.info:
        return Colors.blue.shade300;
      case LogLevel.debug:
        return Colors.grey.shade300;
    }
  }

  Color _getIconColor() {
    switch (log.level) {
      case LogLevel.error:
        return Colors.red.shade700;
      case LogLevel.warning:
        return Colors.orange.shade700;
      case LogLevel.info:
        return Colors.blue.shade700;
      case LogLevel.debug:
        return Colors.grey.shade700;
    }
  }

  IconData _getIcon() {
    switch (log.level) {
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

  String _getLevelText() {
    switch (log.level) {
      case LogLevel.error:
        return 'ОШИБКА';
      case LogLevel.warning:
        return 'ПРЕДУПРЕЖДЕНИЕ';
      case LogLevel.info:
        return 'ИНФО';
      case LogLevel.debug:
        return 'ОТЛАДКА';
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}';
  }

  String _estimateDistanceMeters(int rssi) {
    const txPower = -59;
    const pathLossExponent = 2.0;
    final ratio = (txPower - rssi) / (10 * pathLossExponent);
    final distance = math.pow(10, ratio).toDouble();
    final meters = distance.isFinite ? distance : double.infinity;
    if (!meters.isFinite) return '—';
    if (meters < 1) {
      return '${meters.toStringAsFixed(2)} м';
    } else if (meters < 10) {
      return '${meters.toStringAsFixed(1)} м';
    }
    return '${meters.toStringAsFixed(0)} м';
  }
}
