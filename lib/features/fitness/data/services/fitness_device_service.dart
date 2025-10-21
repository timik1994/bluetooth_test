import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../bluetooth/domain/entities/bluetooth_device_entity.dart';
import '../../domain/entities/fitness_device_entity.dart';
import '../../domain/entities/treadmill_data_entity.dart';
import 'treadmill_protocols/technogym_protocol.dart';

/// Сервис для работы с фитнес-оборудованием
class FitnessDeviceService {
  final Map<String, StreamSubscription> _subscriptions = {};
  final StreamController<TreadmillDataEntity> _treadmillDataController = 
      StreamController<TreadmillDataEntity>.broadcast();

  Stream<TreadmillDataEntity> get treadmillDataStream => _treadmillDataController.stream;

  /// Определяет тип фитнес-оборудования по характеристикам устройства
  FitnessDeviceEntity? identifyFitnessDevice(BluetoothDeviceEntity device) {
    // Определяем производителя по названию
    String manufacturer = 'Unknown';
    if (device.name.toLowerCase().contains('technogym')) {
      manufacturer = 'Technogym';
    } else if (device.name.toLowerCase().contains('precor')) {
      manufacturer = 'Precor';
    } else if (device.name.toLowerCase().contains('life fitness')) {
      manufacturer = 'Life Fitness';
    }

    // Определяем тип устройства
    FitnessDeviceType deviceType = FitnessDeviceType.unknown;
    if (device.name.toLowerCase().contains('run') || 
        device.name.toLowerCase().contains('treadmill')) {
      deviceType = FitnessDeviceType.treadmill;
    } else if (device.name.toLowerCase().contains('bike') ||
               device.name.toLowerCase().contains('cycle')) {
      deviceType = FitnessDeviceType.bike;
    } else if (device.name.toLowerCase().contains('elliptical')) {
      deviceType = FitnessDeviceType.elliptical;
    }

    // Проверяем по сервисам
    final fitnessServiceUuids = [
      '00001826-0000-1000-8000-00805f9b34fb', // Fitness Machine Service
      '0000181d-0000-1000-8000-00805f9b34fb', // Heart Rate Service
    ];

    final hasFitnessServices = device.serviceUuids.any((serviceUuid) =>
        fitnessServiceUuids.any((fitnessUuid) => 
            serviceUuid.toLowerCase().contains(fitnessUuid.replaceAll('-', '').substring(4, 8))));

    if (!hasFitnessServices && deviceType == FitnessDeviceType.unknown) {
      return null; // Не фитнес-оборудование
    }

    // Определяем поддерживаемые метрики
    List<String> supportedMetrics = [];
    if (deviceType == FitnessDeviceType.treadmill) {
      supportedMetrics.addAll(['speed', 'distance', 'incline']);
      if (hasFitnessServices) {
        supportedMetrics.add('heart_rate');
      }
    }

    return FitnessDeviceEntity(
      bluetoothDevice: device,
      deviceType: deviceType,
      manufacturer: manufacturer,
      supportedMetrics: supportedMetrics,
      isConnected: device.isConnected,
    );
  }

  /// Начинает сбор данных с фитнес-оборудования
  Future<void> startDataCollection(BluetoothDevice device, FitnessDeviceEntity fitnessDevice) async {
    try {
      if (_subscriptions.containsKey(device.remoteId.toString())) {
        return; // Уже подписаны
      }

      final services = await device.discoverServices();
      
      for (final service in services) {
        // Ищем Fitness Machine Service
        if (service.uuid.toString().toLowerCase().contains('1826')) {
          for (final characteristic in service.characteristics) {
            // Подписываемся на данные беговой дорожки
            if (characteristic.properties.notify || characteristic.properties.indicate) {
              await characteristic.setNotifyValue(true);
              
              final subscription = characteristic.lastValueStream.listen((List<int> data) {
                _handleFitnessData(Uint8List.fromList(data), fitnessDevice);
              });

              _subscriptions[device.remoteId.toString()] = subscription;
            }
          }
        }

        // Ищем Heart Rate Service
        if (service.uuid.toString().toLowerCase().contains('181d')) {
          for (final characteristic in service.characteristics) {
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              
              final subscription = characteristic.lastValueStream.listen((List<int> data) {
                _handleHeartRateData(Uint8List.fromList(data), fitnessDevice);
              });

              _subscriptions[device.remoteId.toString()] = subscription;
            }
          }
        }
      }
    } catch (e) {
      // Обработка ошибок
    }
  }

  /// Обрабатывает данные фитнес-оборудования
  void _handleFitnessData(Uint8List data, FitnessDeviceEntity fitnessDevice) {
    if (fitnessDevice.deviceType == FitnessDeviceType.treadmill) {
      final treadmillData = TechnogymProtocol.parseTreadmillData(data);
      if (treadmillData != null) {
        _treadmillDataController.add(treadmillData);
      }
    }
  }

  /// Обрабатывает данные пульса
  void _handleHeartRateData(Uint8List data, FitnessDeviceEntity fitnessDevice) {
    if (data.isNotEmpty) {
      // Простейший парсинг пульса
      // Можно добавить логику для обновления данных беговой дорожки с пульсом
    }
  }

  /// Отправляет команду управления на устройство
  Future<bool> sendControlCommand(BluetoothDevice device, Uint8List command) async {
    try {
      final services = await device.discoverServices();
      
      for (final service in services) {
        if (service.uuid.toString().toLowerCase().contains('1826')) {
          for (final characteristic in service.characteristics) {
            if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
              await characteristic.write(command);
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Останавливает сбор данных
  Future<void> stopDataCollection(String deviceId) async {
    final subscription = _subscriptions.remove(deviceId);
    await subscription?.cancel();
  }

  /// Освобождает ресурсы
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _treadmillDataController.close();
  }
}
