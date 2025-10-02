import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../widgets/log_item_widget.dart';
import '../widgets/device_item_widget.dart';

class BluetoothPage extends StatefulWidget {
  BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<BluetoothBloc>().add(const LoadLogsEvent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Тестер'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<BluetoothBloc, BluetoothState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.isBluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                  color: state.isBluetoothEnabled ? Colors.white : Colors.red,
                ),
                onPressed: null,
                tooltip: state.isBluetoothEnabled ? 'Bluetooth включен' : 'Bluetooth выключен',
              );
            },
          ),
        ],
      ),
      body: BlocListener<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: Column(
          children: [
            _buildControlPanel(),
            _buildDevicesSection(),
            _buildLogsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          BlocBuilder<BluetoothBloc, BluetoothState>(
            builder: (context, state) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: state.isScanning
                          ? null
                          : () => context.read<BluetoothBloc>().add(const StartScanEvent()),
                      icon: const Icon(Icons.search),
                      label: const Text('Начать сканирование'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: state.isScanning
                          ? () => context.read<BluetoothBloc>().add(const StopScanEvent())
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Остановить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.read<BluetoothBloc>().add(const ClearLogsEvent()),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Очистить логи'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.read<BluetoothBloc>().add(const LoadLogsEvent()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Обновить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          BlocBuilder<BluetoothBloc, BluetoothState>(
            builder: (context, state) {
              return Column(
                children: [
                  if (state.isScanning)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Сканирование...'),
                      ],
                    ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('Bluetooth: ${state.isBluetoothEnabled ? "Включен" : "Выключен"}'),
                      Text('Устройств: ${state.discoveredDevices.length}'),
                      Text('Логов: ${state.logs.length}'),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesSection() {
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Найденные устройства',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: BlocBuilder<BluetoothBloc, BluetoothState>(
              builder: (context, state) {
                if (state.discoveredDevices.isEmpty) {
                  return const Center(
                    child: Text(
                      'Устройства не найдены.\nНажмите "Начать сканирование"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: state.discoveredDevices.length,
                  itemBuilder: (context, index) {
                    final device = state.discoveredDevices[index];
                    return DeviceItemWidget(
                      device: device,
                      onConnect: () {
                        context.read<BluetoothBloc>().add(
                          ConnectToDeviceEvent(device.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Логи',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: BlocBuilder<BluetoothBloc, BluetoothState>(
              builder: (context, state) {
                if (state.logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Логи пусты',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: state.logs.length,
                  itemBuilder: (context, index) {
                    final log = state.logs.reversed.toList()[index];
                    return LogItemWidget(log: log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
