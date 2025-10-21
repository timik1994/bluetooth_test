import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'shared/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/screens/home_screen.dart';
import 'features/bluetooth/presentation/theme/theme_toggle_notification.dart';
import 'shared/theme/app_themes.dart';

class _ThemeController {
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
  void toggle() {
    mode.value = mode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
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
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Bluetooth Тестер',
          themeMode: mode,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          home: BlocProvider(
            create: (context) => di.sl<BluetoothBloc>(),
            child: NotificationListener<ThemeToggleNotification>(
              onNotification: (_) { _themeController.toggle(); return true; },
              child: const HomeScreen(),
            ),
          ),
        );
      },
    );
  }
}

// Уведомление теперь объявлено в shared/theme/theme_toggle_notification.dart
