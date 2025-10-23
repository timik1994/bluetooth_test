import 'package:flutter/material.dart';
import '../../../../shared/theme/theme_styles.dart';
import '../../../../shared/theme/style_change_notification.dart';

class StyleSelector extends StatelessWidget {
  const StyleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.palette),
      tooltip: 'Выбрать стиль',
      onSelected: (String value) {
        _handleStyleSelection(context, value);
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'classic',
          child: Text('🎨 Классический'),
        ),
        const PopupMenuItem(
          value: 'gradient',
          child: Text('🌊 Океанский'),
        ),
        const PopupMenuItem(
          value: 'glass',
          child: Text('🔮 Морфизм'),
        ),
        const PopupMenuItem(
          value: 'neon',
          child: Text('⚡ Киберпанк'),
        ),
        const PopupMenuItem(
          value: 'material',
          child: Text('📱 Material You'),
        ),
        const PopupMenuItem(
          value: 'dark',
          child: Text('🖤 Готический'),
        ),
        const PopupMenuItem(
          value: 'colorful',
          child: Text('🎪 Карнавал'),
        ),
        const PopupMenuItem(
          value: 'minimal',
          child: Text('🌸 Японский'),
        ),
        const PopupMenuItem(
          value: 'corporate',
          child: Text('🏦 Банковский'),
        ),
        const PopupMenuItem(
          value: 'creative',
          child: Text('🎨 Художественный'),
        ),
      ],
    );
  }

  void _handleStyleSelection(BuildContext context, String value) {
    AppBarStyle? appBarStyle;
    BottomNavStyle? bottomNavStyle;

    switch (value) {
      case 'classic':
        appBarStyle = AppBarStyle.classic;
        bottomNavStyle = BottomNavStyle.classic;
        break;
      case 'gradient':
        appBarStyle = AppBarStyle.gradient;
        bottomNavStyle = BottomNavStyle.floating;
        break;
      case 'glass':
        appBarStyle = AppBarStyle.glass;
        bottomNavStyle = BottomNavStyle.glass;
        break;
      case 'neon':
        appBarStyle = AppBarStyle.neon;
        bottomNavStyle = BottomNavStyle.neon;
        break;
      case 'material':
        appBarStyle = AppBarStyle.material;
        bottomNavStyle = BottomNavStyle.material;
        break;
      case 'dark':
        appBarStyle = AppBarStyle.dark;
        bottomNavStyle = BottomNavStyle.dark;
        break;
      case 'colorful':
        appBarStyle = AppBarStyle.colorful;
        bottomNavStyle = BottomNavStyle.colorful;
        break;
      case 'minimal':
        appBarStyle = AppBarStyle.minimal;
        bottomNavStyle = BottomNavStyle.minimal;
        break;
      case 'corporate':
        appBarStyle = AppBarStyle.corporate;
        bottomNavStyle = BottomNavStyle.corporate;
        break;
      case 'creative':
        appBarStyle = AppBarStyle.creative;
        bottomNavStyle = BottomNavStyle.creative;
        break;
    }

    if (appBarStyle != null && bottomNavStyle != null) {
      StyleChangeNotification(
        appBarStyle: appBarStyle,
        bottomNavStyle: bottomNavStyle,
      ).dispatch(context);
    }
  }
}
