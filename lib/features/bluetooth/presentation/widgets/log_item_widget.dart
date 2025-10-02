import 'package:flutter/material.dart';
import '../../domain/entities/bluetooth_log_entity.dart';

class LogItemWidget extends StatelessWidget {
  final BluetoothLogEntity log;

  const LogItemWidget({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (log.deviceName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Устройство: ${log.deviceName}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
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
}
