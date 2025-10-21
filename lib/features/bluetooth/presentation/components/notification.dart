import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

enum ToastType {
  info,
  success,
  error,
  warning,
}


// Тоастификационные уведомления
class MyToastNotification {
  // Конфигурация для разных типов уведомлений
  static const _toastConfig = {
    ToastType.info: {
      'type': ToastificationType.info,
      'primaryColor': Colors.blue,
    },
    ToastType.success: {
      'type': ToastificationType.success,
      'primaryColor': Colors.green,
    },
    ToastType.error: {
      'type': ToastificationType.error,
      'primaryColor': Colors.red,
    },
    ToastType.warning: {
      'type': ToastificationType.warning,
      'primaryColor': Colors.yellow,
    },
  };

  // Основной метод для показа уведомления
  void _showToast(
    BuildContext context,
    String message,
    ToastType toastType, {
    Duration? duration,
  }) {
    final config = _toastConfig[toastType]!;

    toastification.show(
      context: context,
      title: Text(message),
      type: config['type'] as ToastificationType,
      autoCloseDuration: duration ?? const Duration(seconds: 5),
      style: ToastificationStyle.flatColored,
      alignment: Alignment.bottomCenter,
      backgroundColor: Colors.black,
      foregroundColor: Colors.black,
      primaryColor: config['primaryColor'] as Color,
    );
  }

  // Публичные методы для каждого типа уведомления
  void showInfoToast(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(context, message, ToastType.info, duration: duration);
  }

  void showSuccessToast(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(context, message, ToastType.success, duration: duration);
  }

  void showErrorToast(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(context, message, ToastType.error, duration: duration);
  }

  void showWarningToast(BuildContext context, String message,
      {Duration? duration}) {
    _showToast(context, message, ToastType.warning, duration: duration);
  }

  // Универсальный метод для показа уведомления любого типа
  void showToast(
    BuildContext context,
    String message,
    ToastType type, {
    Duration? duration,
  }) {
    _showToast(context, message, type, duration: duration);
  }
}