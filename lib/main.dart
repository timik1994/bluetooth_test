import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'shared/di/injection_container.dart' as di;
import 'features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'features/bluetooth/presentation/pages/main_tab_page.dart';

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
    return MaterialApp(
      title: 'Bluetooth Тестер',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => di.sl<BluetoothBloc>(),
        child: MainTabPage(),
      ),
    );
  }
}