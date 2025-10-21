class BluetoothException implements Exception {
  final String message;
  const BluetoothException(this.message);
}

class PermissionException implements Exception {
  final String message;
  const PermissionException(this.message);
}

class ConnectionException implements Exception {
  final String message;
  const ConnectionException(this.message);
}

class DataException implements Exception {
  final String message;
  const DataException(this.message);
}
