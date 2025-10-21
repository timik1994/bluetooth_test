import 'dart:typed_data';

/// Команды управления беговой дорожкой Technogym
class TechnogymControlCommands {
  static const int startStop = 0x07;
  static const int pause = 0x02;
  static const int speedUp = 0x05;
  static const int speedDown = 0x04;
  static const int inclineUp = 0x01;
  static const int inclineDown = 0x00;

  /// Создает команду для отправки на беговую дорожку
  static Uint8List createCommand(int command) {
    return Uint8List.fromList([command]);
  }
}
