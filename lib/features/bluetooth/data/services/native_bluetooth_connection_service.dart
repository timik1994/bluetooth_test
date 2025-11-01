import 'package:flutter/services.dart';
import 'dart:async';

class NativeBluetoothConnectionService {
  static const MethodChannel _channel = MethodChannel('native_bluetooth_connection');
  
  final StreamController<Map<String, dynamic>> _connectionController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _disconnectionController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _servicesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _dataController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get disconnectionStream => _disconnectionController.stream;
  Stream<Map<String, dynamic>> get servicesStream => _servicesController.stream;
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  
  bool _isInitialized = false;
  
  NativeBluetoothConnectionService() {
    _initialize();
  }
  
  void _initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDeviceConnected':
          _connectionController.add(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onDeviceDisconnected':
          _disconnectionController.add(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onServicesDiscovered':
          _servicesController.add(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onCharacteristicRead':
        case 'onCharacteristicChanged':
          // Оба типа событий (READ и NOTIFY/INDICATE) обрабатываем одинаково
          // Преобразуем данные в единый формат для совместимости
          final data = Map<String, dynamic>.from(call.arguments);
          
          // Убеждаемся, что данные в правильном формате
          if (data['rawData'] == null && data['hexData'] != null) {
            // Преобразуем hexData в rawData если нужно
            try {
              final hexString = data['hexData'] as String;
              final hexBytes = hexString.split(' ').where((s) => s.isNotEmpty).map((s) => int.parse(s, radix: 16)).toList();
              data['rawData'] = hexBytes;
            } catch (e) {
              print('NativeBluetoothConnectionService: Ошибка преобразования HEX: $e');
            }
          }
          
          _dataController.add(data);
          break;
      }
    });
  }
  
  Future<bool> connectToDevice(String deviceAddress) async {
    try {
      final result = await _channel.invokeMethod('connectToDevice', {
        'deviceAddress': deviceAddress,
      });
      
      if (result is Map) {
        return result['success'] as bool? ?? false;
      }
      
      return false;
    } catch (e) {
      print('Native Bluetooth Connection Error: $e');
      return false;
    }
  }
  
  Future<bool> disconnectFromDevice(String deviceAddress) async {
    try {
      final result = await _channel.invokeMethod('disconnectFromDevice', {
        'deviceAddress': deviceAddress,
      });
      
      if (result is Map) {
        return result['success'] as bool? ?? false;
      }
      
      return false;
    } catch (e) {
      print('Native Bluetooth Disconnection Error: $e');
      return false;
    }
  }
  
  Future<bool> discoverServices(String deviceAddress) async {
    try {
      final result = await _channel.invokeMethod('discoverServices', {
        'deviceAddress': deviceAddress,
      });
      
      if (result is Map) {
        return result['success'] as bool? ?? false;
      }
      
      return false;
    } catch (e) {
      print('Native Bluetooth Service Discovery Error: $e');
      return false;
    }
  }
  
  void dispose() {
    _connectionController.close();
    _disconnectionController.close();
    _servicesController.close();
    _dataController.close();
  }
}

