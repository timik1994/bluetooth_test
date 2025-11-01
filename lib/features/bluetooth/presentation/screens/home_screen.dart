import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart';
import '../theme/theme_toggle_notification.dart';
import '../theme/navigate_to_emulation_notification.dart';
import '../components/notification.dart';
import '../widgets/style_selector.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import 'permissions_screen.dart';
import 'devices_screen.dart';
import 'emulation_screen.dart';
import 'logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PermissionsScreen(),
    const DevicesScreen(),
    const EmulationScreen(),
    const LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Bluetooth Тестер',
        isDark: isDark,
        actions: [
          // Селектор стилей
          const StyleSelector(),
          // Переключатель темы
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: 'Переключить тему',
                icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                onPressed: () {
                  ThemeToggleNotification().dispatch(context);
                },
              );
            },
          ),
        ],
      ),
      body: NotificationListener<NavigateToEmulationNotification>(
        onNotification: (_) {
          setState(() {
            _currentIndex = 2; // Индекс вкладки эмуляции
          });
          return true;
        },
        child: BlocListener<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            MyToastNotification().showErrorToast(context, state.errorMessage!);
          }
          if (state.successMessage != null) {
            MyToastNotification().showSuccessToast(context, state.successMessage!);
          }
        },
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        isDark: isDark,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Разрешения',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Устройства',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.watch),
            label: 'Эмуляция',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Логи',
          ),
        ],
      ),
    );
  }
}
