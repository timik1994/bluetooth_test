import 'package:flutter/material.dart';

enum ConnectionType {
  flutter,
  native,
}

class ConnectionTypeModal extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final Function(ConnectionType) onConnectionTypeSelected;

  const ConnectionTypeModal({
    super.key,
    required this.deviceName,
    required this.deviceId,
    required this.onConnectionTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Row(
              children: [
                Icon(
                  Icons.bluetooth_connected,
                  color: Colors.blue.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Выберите тип подключения',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              deviceName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            
            // Кнопка Flutter подключения
            _buildConnectionOption(
              context,
              icon: Icons.flutter_dash,
              title: 'Flutter подключение',
              description: 'Использует flutter_blue_plus',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).pop();
                onConnectionTypeSelected(ConnectionType.flutter);
              },
            ),
            
            const SizedBox(height: 16),
            
            // Кнопка нативного подключения
            _buildConnectionOption(
              context,
              icon: Icons.phone_android,
              title: 'Нативное подключение',
              description: 'Использует Android Native API',
              color: Colors.green,
              onTap: () {
                Navigator.of(context).pop();
                onConnectionTypeSelected(ConnectionType.native);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Конвертируем Color в MaterialColor для использования shade
    MaterialColor materialColor;
    if (color == Colors.blue) {
      materialColor = Colors.blue;
    } else if (color == Colors.green) {
      materialColor = Colors.green;
    } else {
      materialColor = Colors.blue; // По умолчанию
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: materialColor.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: materialColor.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: materialColor.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: materialColor.shade700,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: materialColor.shade700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: materialColor.shade700,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

