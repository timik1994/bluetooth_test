import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_state.dart';
import '../theme/theme_toggle_notification.dart';
import '../components/notification.dart';
import 'permissions_screen.dart';
import 'devices_screen.dart';
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
    const LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Тестер'),
        actions: [
          // Переключатель темы
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: 'Переключить тему',
                icon: Icon(Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode
                    : Icons.light_mode),
                onPressed: () {
                  ThemeToggleNotification().dispatch(context);
                },
              );
            },
          ),
        ],
      ),
      body: BlocListener<BluetoothBloc, BluetoothState>(
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
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
            icon: Icon(Icons.list_alt),
            label: 'Логи',
          ),
        ],
      ),
    );
  }
}
