import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/entities/bluetooth_device_entity.dart';

class BluetoothDeviceModel extends BluetoothDeviceEntity {
  const BluetoothDeviceModel({
    required super.id,
    required super.name,
    required super.isConnected,
    required super.rssi,
    required super.serviceUuids,
    required super.deviceType,
    required super.isClassicBluetooth,
    required super.isBonded,
  });

  factory BluetoothDeviceModel.fromBluetoothDevice(BluetoothDevice device) {
    return BluetoothDeviceModel(
      id: device.remoteId.toString(),
      name: device.platformName.isNotEmpty ? device.platformName : 'Неизвестное устройство',
      isConnected: device.isConnected,
      rssi: 0, // RSSI будет получен из ScanResult
      serviceUuids: [], // Сервисы будут получены при подключении
      deviceType: _getDeviceType(device.platformName),
      isClassicBluetooth: false,
      isBonded: false,
    );
  }

  factory BluetoothDeviceModel.fromScanResult(ScanResult result) {
    try {
      // Пытаемся получить имя устройства из разных источников
      String deviceName = _getDeviceName(result);
      
      // Определяем тип устройства на основе имени И сервисов
      String deviceType = _getDeviceTypeAdvanced(deviceName, result.advertisementData.serviceUuids);
      
      return BluetoothDeviceModel(
        id: result.device.remoteId.toString(),
        name: deviceName,
        isConnected: result.device.isConnected,
        rssi: result.rssi,
        serviceUuids: result.advertisementData.serviceUuids.map((uuid) => uuid.toString()).toList(),
        deviceType: deviceType,
        isClassicBluetooth: false,
        isBonded: false,
      );
    } catch (e) {
      // Возвращаем базовую модель в случае ошибки
      return BluetoothDeviceModel(
        id: result.device.remoteId.toString(),
        name: 'Ошибка устройства',
        isConnected: false,
        rssi: 0,
        serviceUuids: [],
        deviceType: 'Неизвестное устройство',
        isClassicBluetooth: false,
        isBonded: false,
      );
    }
  }

  /// Получает имя устройства из разных источников
  static String _getDeviceName(ScanResult result) {
    // 1. Пробуем platformName (основное имя устройства)
    if (result.device.platformName.isNotEmpty && 
        result.device.platformName != "Unknown" &&
        result.device.platformName != "unknown") {
      return _decodeDeviceName(result.device.platformName, result.device.remoteId.toString());
    }
    
    // 2. Пробуем localName из рекламных данных
    if (result.advertisementData.localName.isNotEmpty &&
        result.advertisementData.localName != "Unknown" &&
        result.advertisementData.localName != "unknown") {
      return _decodeDeviceName(result.advertisementData.localName, result.device.remoteId.toString());
    }
    
    // 3. Пробуем advName из рекламных данных (если доступно)
    try {
      if (result.advertisementData.advName.isNotEmpty &&
          result.advertisementData.advName != "Unknown" &&
          result.advertisementData.advName != "unknown") {
        return _decodeDeviceName(result.advertisementData.advName, result.device.remoteId.toString());
      }
    } catch (e) {
      // advName может не быть доступным в некоторых версиях
    }
    
    // 4. Пробуем получить имя из manufacturerData
    if (result.advertisementData.manufacturerData.isNotEmpty) {
      final manufacturerData = result.advertisementData.manufacturerData;
      
      // Пытаемся извлечь имя из manufacturerData
      for (final entry in manufacturerData.entries) {
        final companyId = entry.key;
        final data = entry.value;
        
        if (data.length > 2) {
          try {
            // Пытаемся декодировать разными способами
            
            // Способ 1: Пропускаем первые 2 байта (часто это флаги)
            final possibleName1 = String.fromCharCodes(data.skip(2)).trim();
            if (_isValidDeviceName(possibleName1)) {
              return possibleName1;
            }
            
            // Способ 2: Декодируем все данные
            final possibleName2 = String.fromCharCodes(data).trim();
            if (_isValidDeviceName(possibleName2)) {
              return possibleName2;
            }
            
            // Способ 3: Ищем строку в данных (может быть в середине)
            for (int i = 0; i < data.length - 3; i++) {
              try {
                final substring = String.fromCharCodes(data.skip(i).take(data.length - i)).trim();
                if (_isValidDeviceName(substring) && substring.length >= 3) {
                  return substring;
                }
              } catch (e) {
                continue;
              }
            }
          } catch (e) {
            // Ошибка декодирования manufacturerData
          }
        }
      }
    }
    
    // 5. Пробуем serviceData
    if (result.advertisementData.serviceData.isNotEmpty) {
      for (final entry in result.advertisementData.serviceData.entries) {
        final data = entry.value;
        if (data.length > 2) {
          try {
            final possibleName = String.fromCharCodes(data).trim();
            if (_isValidDeviceName(possibleName)) {
              return possibleName;
            }
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    // 6. Создаем имя на основе MAC-адреса
    final macAddress = result.device.remoteId.toString();
    if (macAddress.length >= 5) {
      final lastPart = macAddress.split(':').last;
      final generatedName = "Устройство ${lastPart.substring(0, 1)}:${lastPart.substring(1)}";
      return generatedName;
    }
    
    // 7. Fallback
    return 'Неизвестное устройство';
  }

  /// Проверяет, является ли строка валидным именем устройства
  static bool _isValidDeviceName(String name) {
    if (name.isEmpty || name.length < 2 || name.length > 50) return false;
    
    // Проверяем, что строка содержит хотя бы одну букву или цифру
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(name)) return false;
    
    // Исключаем строки с только специальными символами
    if (RegExp(r'^[^\w\s]+$').hasMatch(name)) return false;
    
    // Исключаем строки с слишком большим количеством повторяющихся символов
    if (RegExp(r'(.)\1{4,}').hasMatch(name)) return false;
    
    return true;
  }

  /// Определяет тип устройства на основе имени и сервисов
  static String _getDeviceTypeAdvanced(String deviceName, List<Guid> serviceUuids) {
    // Сначала пробуем определить по сервисам
    final typeByServices = _getDeviceTypeByServices(serviceUuids);
    if (typeByServices != 'Bluetooth устройство') {
      return typeByServices;
    }
    
    // Если по сервисам не определили, используем имя
    return _getDeviceType(deviceName);
  }

  /// Определяет тип устройства по UUID сервисов
  static String _getDeviceTypeByServices(List<Guid> serviceUuids) {
    final uuidStrings = serviceUuids.map((uuid) => uuid.toString().toLowerCase()).toList();
    
    // Проверяем известные UUID сервисов
    for (final uuid in uuidStrings) {
      // Heart Rate Service
      if (uuid.contains('180d')) return 'Фитнес устройство';
      // Battery Service
      if (uuid.contains('180f')) return 'Носимое устройство';
      // Device Information Service
      if (uuid.contains('180a')) return 'Умное устройство';
      // Human Interface Device
      if (uuid.contains('1812')) return 'Устройство ввода';
      // Audio/Video Remote Control Profile
      if (uuid.contains('110e') || uuid.contains('110c')) return 'Аудио устройство';
      // Advanced Audio Distribution Profile
      if (uuid.contains('110d')) return 'Аудио устройство';
      // Hands-Free Profile
      if (uuid.contains('111e')) return 'Аудио устройство';
      // Phone Book Access Profile
      if (uuid.contains('1130')) return 'Телефон/Планшет';
    }
    
    return 'Bluetooth устройство';
  }

  static String _getDeviceType(String deviceName) {
    final name = deviceName.toLowerCase();
    
    // Телефоны и планшеты
    if (name.contains('phone') || name.contains('телефон') ||
        name.contains('galaxy') || name.contains('iphone') ||
        name.contains('pixel') || name.contains('xiaomi') ||
        name.contains('huawei') || name.contains('oneplus') ||
        name.contains('samsung') || name.contains('android') ||
        name.contains('redmi') || name.contains('poco') ||
        name.contains('realme') || name.contains('oppo') ||
        name.contains('vivo') || name.contains('lg') ||
        name.contains('sony') || name.contains('nokia') ||
        name.contains('motorola') || name.contains('asus') ||
        name.contains('tablet') || name.contains('планшет') ||
        name.contains('ipad')) {
      return 'Телефон/Планшет';
    }
    
    // Умные часы и фитнес браслеты
    if (name.contains('watch') || name.contains('часы') ||
        name.contains('band') || name.contains('браслет') ||
        name.contains('fit') || name.contains('health') ||
        name.contains('sport') || name.contains('fitness') ||
        name.contains('tracker') || name.contains('трекер') ||
        name.contains('mi band') || name.contains('amazfit') ||
        name.contains('fitbit') || name.contains('garmin') ||
        name.contains('polar') || name.contains('suunto') ||
        name.contains('apple watch') || name.contains('galaxy watch') ||
        name.contains('wear') || name.contains('smart watch')) {
      return 'Фитнес устройство';
    }
    
    // Аудио устройства
    if (name.contains('headphone') || name.contains('наушники') ||
        name.contains('earphone') || name.contains('earbud') ||
        name.contains('speaker') || name.contains('колонка') ||
        name.contains('audio') || name.contains('sound') ||
        name.contains('music') || name.contains('beats') ||
        name.contains('sony wh') || name.contains('airpods') ||
        name.contains('buds') || name.contains('jbl') ||
        name.contains('bose') || name.contains('sennheiser') ||
        name.contains('marshall') || name.contains('harman')) {
      return 'Аудио устройство';
    }
    
    // Компьютеры и ноутбуки
    if (name.contains('laptop') || name.contains('ноутбук') ||
        name.contains('computer') || name.contains('компьютер') ||
        name.contains('pc') || name.contains('mac') ||
        name.contains('desktop') || name.contains('workstation') ||
        name.contains('thinkpad') || name.contains('macbook') ||
        name.contains('surface') || name.contains('dell') ||
        name.contains('hp') || name.contains('lenovo') ||
        name.contains('asus') || name.contains('acer')) {
      return 'Компьютер';
    }
    
    // Игровые устройства
    if (name.contains('controller') || name.contains('геймпад') ||
        name.contains('gamepad') || name.contains('joystick') ||
        name.contains('playstation') || name.contains('xbox') ||
        name.contains('nintendo') || name.contains('steam') ||
        name.contains('gaming') || name.contains('игровой')) {
      return 'Игровое устройство';
    }
    
    // Автомобильные системы
    if (name.contains('car') || name.contains('auto') ||
        name.contains('vehicle') || name.contains('авто') ||
        name.contains('машина') || name.contains('bmw') ||
        name.contains('mercedes') || name.contains('audi') ||
        name.contains('toyota') || name.contains('honda') ||
        name.contains('ford') || name.contains('volkswagen') ||
        name.contains('carplay') || name.contains('android auto')) {
      return 'Автомобиль';
    }
    
    // Умный дом
    if (name.contains('smart') || name.contains('умный') ||
        name.contains('home') || name.contains('дом') ||
        name.contains('light') || name.contains('lamp') ||
        name.contains('bulb') || name.contains('лампа') ||
        name.contains('switch') || name.contains('выключатель') ||
        name.contains('sensor') || name.contains('датчик') ||
        name.contains('thermostat') || name.contains('термостат') ||
        name.contains('camera') || name.contains('камера') ||
        name.contains('doorbell') || name.contains('звонок') ||
        name.contains('lock') || name.contains('замок')) {
      return 'Умный дом';
    }
    
    // Принтеры
    if (name.contains('printer') || name.contains('принтер') ||
        name.contains('print') || name.contains('canon') ||
        name.contains('epson') || name.contains('hp') ||
        name.contains('brother') || name.contains('samsung') ||
        name.contains('xerox') || name.contains('kyocera')) {
      return 'Принтер';
    }
    
    // Медицинские устройства
    if (name.contains('medical') || name.contains('health') ||
        name.contains('blood') || name.contains('pressure') ||
        name.contains('glucose') || name.contains('thermometer') ||
        name.contains('медицинский') || name.contains('здоровье') ||
        name.contains('давление') || name.contains('глюкоза') ||
        name.contains('термометр') || name.contains('пульс')) {
      return 'Медицинское устройство';
    }
    
    // Клавиатуры и мыши
    if (name.contains('keyboard') || name.contains('клавиатура') ||
        name.contains('mouse') || name.contains('мышь') ||
        name.contains('trackpad') || name.contains('touchpad') ||
        name.contains('magic') || name.contains('wireless')) {
      return 'Устройство ввода';
    }
    
    return 'Bluetooth устройство';
  }

  /// Декодирует имя устройства из различных кодировок
  static String _decodeDeviceName(String rawName, String deviceId) {
    if (rawName.isEmpty) {
      return _generateNameFromId(deviceId);
    }

    // Сначала проверяем, является ли имя уже корректным ASCII
    if (_isValidAsciiName(rawName)) {
      return rawName;
    }

    try {
      // Пробуем декодировать как UTF-8
      final bytes = rawName.codeUnits;
      final decoded = utf8.decode(bytes, allowMalformed: true);
      
      if (_isValidAsciiName(decoded)) {
        return decoded;
      }
    } catch (e) {
      // Игнорируем ошибки декодирования
    }

    try {
      // Пробуем декодировать как Latin-1
      final bytes = rawName.codeUnits.map((c) => c & 0xFF).toList();
      final decoded = utf8.decode(bytes, allowMalformed: true);
      
      if (_isValidAsciiName(decoded)) {
        return decoded;
      }
    } catch (e) {
      // Игнорируем ошибки декодирования
    }

    // Если ничего не помогло, очищаем от нечитаемых символов
    final cleaned = rawName.replaceAll(RegExp(r'[^\w\s\-\.\(\)]+'), '').trim();
    if (cleaned.isNotEmpty && cleaned.length >= 2) {
      return cleaned;
    }

    // В крайнем случае генерируем имя из ID
    return _generateNameFromId(deviceId);
  }

  /// Проверяет, является ли имя валидным ASCII
  static bool _isValidAsciiName(String name) {
    if (name.isEmpty || name.length > 50) return false;
    
    // Проверяем ASCII символы (32-127)
    if (!name.codeUnits.every((c) => c >= 32 && c <= 127)) return false;
    
    // Проверяем наличие букв или цифр
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(name)) return false;
    
    // Исключаем строки только из спецсимволов
    if (RegExp(r'^[^\w\s]+$').hasMatch(name)) return false;
    
    return true;
  }

  /// Генерирует читаемое имя из ID устройства
  static String _generateNameFromId(String deviceId) {
    final parts = deviceId.split(':');
    if (parts.length >= 2) {
      final lastPart = parts.last;
      final secondLastPart = parts[parts.length - 2];
      return 'Устройство ${secondLastPart}:${lastPart}';
    }
    
    final shortId = deviceId.length > 6 ? deviceId.substring(deviceId.length - 6) : deviceId;
    return 'Устройство $shortId';
  }
}
