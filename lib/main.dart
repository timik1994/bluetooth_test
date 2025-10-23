import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'shared/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/screens/home_screen.dart';
import 'features/bluetooth/presentation/theme/theme_toggle_notification.dart';
import 'shared/theme/app_themes.dart';
import 'shared/theme/theme_styles.dart';
import 'shared/theme/style_change_notification.dart';

class _ThemeController {
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
  final ValueNotifier<bool> needsRebuild = ValueNotifier(false);
  
  void toggle() {
    mode.value = mode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
  
  void rebuild() {
    needsRebuild.value = !needsRebuild.value;
  }
}

final _themeController = _ThemeController();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await di.initializeDependencies();
    runApp(const MyApp());
  } catch (e) {
    print('Ошибка инициализации приложения: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Ошибка инициализации: $e'),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController.mode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _themeController.needsRebuild,
          builder: (context, _, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Bluetooth Тестер',
              themeMode: mode,
              theme: AppThemes.getLightTheme(),
              darkTheme: AppThemes.getDarkTheme(),
              home: BlocProvider(
                create: (context) => di.sl<BluetoothBloc>(),
                child: NotificationListener<ThemeToggleNotification>(
                  onNotification: (_) { _themeController.toggle(); return true; },
                  child: NotificationListener<StyleChangeNotification>(
                    onNotification: (notification) {
                      if (notification.appBarStyle != null) {
                        ThemeStyleManager.setAppBarStyle(notification.appBarStyle!);
                      }
                      if (notification.bottomNavStyle != null) {
                        ThemeStyleManager.setBottomNavStyle(notification.bottomNavStyle!);
                      }
                      _themeController.rebuild();
                      return true;
                    },
                    child: const HomeScreen(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Уведомление теперь объявлено в shared/theme/theme_toggle_notification.dart
