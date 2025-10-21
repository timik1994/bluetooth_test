import 'package:equatable/equatable.dart';

/// Данные, получаемые с беговой дорожки во время тренировки
class TreadmillDataEntity extends Equatable {
  final double? speed; // Скорость в км/ч
  final double? distance; // Дистанция в метрах
  final double? incline; // Наклон в процентах
  final int? heartRate; // Пульс в ударах в минуту
  final int? calories; // Калории
  final Duration? elapsedTime; // Время тренировки
  final bool isRunning; // Статус бега
  final DateTime timestamp; // Время получения данных

  const TreadmillDataEntity({
    this.speed,
    this.distance,
    this.incline,
    this.heartRate,
    this.calories,
    this.elapsedTime,
    required this.isRunning,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        speed,
        distance,
        incline,
        heartRate,
        calories,
        elapsedTime,
        isRunning,
        timestamp,
      ];

  /// Форматированная скорость для отображения
  String get formattedSpeed {
    if (speed == null) return '--';
    return '${speed!.toStringAsFixed(1)} км/ч';
  }

  /// Форматированная дистанция для отображения
  String get formattedDistance {
    if (distance == null) return '--';
    return '${(distance! / 1000).toStringAsFixed(2)} км';
  }

  /// Форматированный наклон для отображения
  String get formattedIncline {
    if (incline == null) return '--';
    return '${incline!.toStringAsFixed(0)}%';
  }

  /// Форматированное время для отображения
  String get formattedTime {
    if (elapsedTime == null) return '--';
    final minutes = elapsedTime!.inMinutes.remainder(60);
    final hours = elapsedTime!.inHours;
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${elapsedTime!.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${minutes}:${elapsedTime!.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}
