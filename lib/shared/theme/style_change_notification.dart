import 'package:flutter/material.dart';
import 'theme_styles.dart';

class StyleChangeNotification extends Notification {
  final AppBarStyle? appBarStyle;
  final BottomNavStyle? bottomNavStyle;
  
  StyleChangeNotification({
    this.appBarStyle,
    this.bottomNavStyle,
  });
}
