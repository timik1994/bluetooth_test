import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../widgets/device_item_widget.dart';
import 'intercept_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _fabExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<BluetoothBloc, BluetoothState>(
        listener: (context, state) {
          // Автоматически закрываем меню при остановке сканирования
          if (!state.isScanning && _fabExpanded) {
            setState(() {
              _fabExpanded = false;
            });
          }
        },
        child: _buildDevicesList(),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildDevicesList() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        return Column(
          children: [
            // Заголовок с количеством устройств
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Доступные устройства (${state.discoveredDevices.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.discoveredDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.isScanning
                                ? 'Идет сканирование...'
                                : 'Устройства не найдены',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = state.discoveredDevices[index];
                        final isConnected =
                            state.connectedDevices.contains(device.id);
                        final wasPreviouslyConnected = state
                            .previouslyConnectedDevices
                            .contains(device.id);
                        return DeviceItemWidget(
                          device: device,
                          isConnecting:
                              state.connectingDevices.contains(device.id),
                          isConnected: isConnected,
                          wasPreviouslyConnected: wasPreviouslyConnected,
                          onConnect: () {
                            if (wasPreviouslyConnected && !isConnected) {
                              context.read<BluetoothBloc>().add(
                                    ReconnectToDeviceEvent(device.id),
                                  );
                            } else {
                              context.read<BluetoothBloc>().add(
                                    ConnectToDeviceEvent(device.id),
                                  );
                            }
                          },
                          onReconnect: () {
                            context.read<BluetoothBloc>().add(
                                  ReconnectToDeviceEvent(device.id),
                                );
                          },
                          onDisconnect: () {
                            context.read<BluetoothBloc>().add(
                                  DisconnectFromDeviceEvent(device.id),
                                );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        // Если идет сканирование - показываем только кнопку "Стоп"
        if (state.isScanning) {
          return SizedBox(
            width: 140,
            child: FloatingActionButton.extended(
              heroTag: 'fab_stop',
              onPressed: () {
                context.read<BluetoothBloc>().add(const StopScanEvent());
              },
              backgroundColor: Colors.red,
              icon: const Icon(Icons.stop),
              label: const Text('Стоп'),
            ),
          );
        }

        // Обычное состояние - меню или раскрытые кнопки
        return Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Главная кнопка "Меню" / "Закрыть" - рендерится первой (внизу)
            Positioned(
              bottom: 0,
              right: 0,
              child: SizedBox(
                width: 140,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_main',
                  onPressed: () {
                    setState(() {
                      _fabExpanded = !_fabExpanded;
                    });
                  },
                  backgroundColor: _fabExpanded ? Colors.grey : Colors.blue,
                  icon: Icon(_fabExpanded ? Icons.close : Icons.menu),
                  label: Text(_fabExpanded ? 'Закрыть' : 'Меню'),
                ),
              ),
            ),
            // Кнопка "Скан" (средняя) - рендерится второй
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _fabExpanded ? 70 : -100, // Выше главной кнопки
              right: 0,
              child: SizedBox(
                width: 140,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_scan',
                  onPressed: _fabExpanded ? () {
                    setState(() {
                      _fabExpanded = false;
                    });
                    context.read<BluetoothBloc>().add(const StartScanEvent());
                  } : null,
                  backgroundColor: Colors.blue,
                  icon: const Icon(Icons.search),
                  label: const Text('Скан'),
                ),
              ),
            ),
            // Кнопка "Перехват" (самая верхняя) - рендерится последней (сверху)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _fabExpanded ? 140 : -100, // Еще выше
              right: 0,
              child: SizedBox(
                width: 140,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_intercept',
                  onPressed: _fabExpanded ? () {
                    setState(() {
                      _fabExpanded = false;
                    });
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<BluetoothBloc>(),
                          child: const InterceptPage(),
                        ),
                      ),
                    );
                  } : null,
                  backgroundColor: Colors.purple,
                  icon: const Icon(Icons.track_changes),
                  label: const Text('Перехват'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
