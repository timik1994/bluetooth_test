import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'treadmill_protocols/technogym_control_commands.dart';

/// Сервис для управления беговой дорожкой через Bluetooth
class TreadmillControlService {
  /// UUID сервиса Fitness Machine Service
  static const String fitnessMachineServiceUuid = '00001826-0000-1000-8000-00805F9B34FB';
  
  /// UUID характеристики для управления (Control Point)
  static const String controlPointCharUuid = '00002AD9-0000-1000-8000-00805F9B34FB';
  
  /// UUID характеристики для данных (Treadmill Data)
  static const String dataCharUuid = '00002ACD-0000-1000-8000-00805F9B34FB';
  
  /// Отправляет команду управления на беговую дорожку
  /// 
  /// [device] - подключенное Bluetooth устройство
  /// [command] - команда для отправки (Uint8List)
  /// 
  /// Возвращает true если команда отправлена успешно
  static Future<bool> sendCommand(
    BluetoothDevice device,
    Uint8List command,
  ) async {
    try {
      if (!device.isConnected) {
        print('TreadmillControlService: Устройство не подключено');
        return false;
      }
      
      // Открываем сервисы если они еще не открыты
      try {
        final services = await device.discoverServices();
        
        // Ищем Fitness Machine Service
        BluetoothService? fitnessService;
        for (final service in services) {
          if (service.uuid.toString().toLowerCase().contains('1826')) {
            fitnessService = service;
            break;
          }
        }
        
        if (fitnessService == null) {
          print('TreadmillControlService: Fitness Machine Service не найден');
          return false;
        }
        
        // Ищем характеристику для записи команд
        BluetoothCharacteristic? controlCharacteristic;
        for (final characteristic in fitnessService.characteristics) {
          final uuid = characteristic.uuid.toString().toLowerCase();
          // Ищем Control Point характеристику или любую с возможностью записи
          if (uuid.contains('ad9') || 
              (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
            controlCharacteristic = characteristic;
            break;
          }
        }
        
        if (controlCharacteristic == null) {
          print('TreadmillControlService: Характеристика для записи не найдена');
          return false;
        }
        
        // Отправляем команду
        if (controlCharacteristic.properties.writeWithoutResponse) {
          await controlCharacteristic.write(command, withoutResponse: true);
        } else {
          await controlCharacteristic.write(command, withoutResponse: false);
        }
        
        print('TreadmillControlService: Команда отправлена успешно');
        return true;
      } catch (e) {
        print('TreadmillControlService: Ошибка отправки команды: $e');
        return false;
      }
    } catch (e) {
      print('TreadmillControlService: Критическая ошибка: $e');
      return false;
    }
  }
  
  /// Отправляет команду старт/стоп
  static Future<bool> sendStartStop(BluetoothDevice device) async {
    final command = TechnogymControlCommands.createCommand(
      TechnogymControlCommands.startStop,
    );
    return await sendCommand(device, command);
  }
  
  /// Отправляет команду пауза
  static Future<bool> sendPause(BluetoothDevice device) async {
    final command = TechnogymControlCommands.createCommand(
      TechnogymControlCommands.pause,
    );
    return await sendCommand(device, command);
  }
  
  /// Отправляет команду увеличения скорости
  static Future<bool> sendSpeedUp(BluetoothDevice device) async {
    final command = TechnogymControlCommands.createCommand(
      TechnogymControlCommands.speedUp,
    );
    return await sendCommand(device, command);
  }
  
  /// Отправляет команду уменьшения скорости
  static Future<bool> sendSpeedDown(BluetoothDevice device) async {
    final command = TechnogymControlCommands.createCommand(
      TechnogymControlCommands.speedDown,
    );
    return await sendCommand(device, command);
  }
  
  /// Отправляет команду увеличения наклона
  static Future<bool> sendInclineUp(BluetoothDevice device) async {
    final command = TechnogymControlCommands.createCommand(
      TechnogymControlCommands.inclineUp,
    );
    return await sendCommand(device, command);
  }
  
  /// Отправляет команду уменьшения наклона
  static Future<bool> sendInclineDown(BluetoothDevice device) async {
    final command = TechnogymControlCommands.createCommand(
      TechnogymControlCommands.inclineDown,
    );
    return await sendCommand(device, command);
  }
}

