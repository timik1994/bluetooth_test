import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Основные разрешения, необходимые для работы Bluetooth
  static const List<Permission> requiredPermissions = [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ];

  /// Дополнительные разрешения (не критичные)
  static const List<Permission> optionalPermissions = [
    Permission.locationAlways,
    Permission.notification,
  ];

  /// Все разрешения
  static List<Permission> get allPermissions => [
    ...requiredPermissions,
    ...optionalPermissions,
  ];

  /// Проверяет, получены ли все необходимые разрешения
  static Future<bool> areRequiredPermissionsGranted() async {
    final statuses = await Future.wait(
      requiredPermissions.map((permission) => permission.status),
    );
    return statuses.every((status) => status.isGranted);
  }

  /// Проверяет, получены ли все разрешения
  static Future<bool> areAllPermissionsGranted() async {
    final statuses = await Future.wait(
      allPermissions.map((permission) => permission.status),
    );
    return statuses.every((status) => status.isGranted);
  }

  /// Запрашивает основные разрешения
  static Future<Map<Permission, PermissionStatus>> requestRequiredPermissions() async {
    return await requiredPermissions.request();
  }

  /// Запрашивает дополнительные разрешения
  static Future<Map<Permission, PermissionStatus>> requestOptionalPermissions() async {
    return await optionalPermissions.request();
  }

  /// Запрашивает все разрешения
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    return await allPermissions.request();
  }

  /// Получает статус всех разрешений
  static Future<Map<Permission, PermissionStatus>> getAllPermissionStatuses() async {
    final Map<Permission, PermissionStatus> statuses = {};
    
    for (final permission in allPermissions) {
      statuses[permission] = await permission.status;
    }
    
    return statuses;
  }

  /// Получает человекочитаемое название разрешения
  static String getPermissionDisplayName(Permission permission) {
    if (permission == Permission.bluetooth) {
      return 'Bluetooth';
    } else if (permission == Permission.bluetoothScan) {
      return 'Bluetooth Scan';
    } else if (permission == Permission.bluetoothConnect) {
      return 'Bluetooth Connect';
    } else if (permission == Permission.location) {
      return 'Местоположение';
    } else if (permission == Permission.locationAlways) {
      return 'Местоположение (всегда)';
    } else if (permission == Permission.notification) {
      return 'Уведомления';
    } else {
      return permission.toString();
    }
  }

  /// Получает описание разрешения
  static String getPermissionDescription(Permission permission) {
    if (permission == Permission.bluetooth) {
      return 'Основное разрешение для работы с Bluetooth';
    } else if (permission == Permission.bluetoothScan) {
      return 'Поиск Bluetooth устройств (Android 12+)';
    } else if (permission == Permission.bluetoothConnect) {
      return 'Подключение к Bluetooth устройствам (Android 12+)';
    } else if (permission == Permission.location) {
      return 'Требуется для поиска BLE устройств';
    } else if (permission == Permission.locationAlways) {
      return 'Фоновый доступ к местоположению для Bluetooth';
    } else if (permission == Permission.notification) {
      return 'Уведомления о состоянии Bluetooth (Android 13+)';
    } else {
      return 'Разрешение для работы с Bluetooth';
    }
  }

  /// Проверяет, является ли разрешение обязательным
  static bool isRequiredPermission(Permission permission) {
    return requiredPermissions.contains(permission);
  }

  /// Получает статус разрешения в виде текста
  static String getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Предоставлено';
      case PermissionStatus.denied:
        return 'Отклонено';
      case PermissionStatus.permanentlyDenied:
        return 'Окончательно отклонено';
      case PermissionStatus.restricted:
        return 'Ограничено';
      case PermissionStatus.limited:
        return 'Ограничено';
      case PermissionStatus.provisional:
        return 'Временное';
    }
  }
}
