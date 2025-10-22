import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';
import '../widgets/device_item_widget.dart';
import 'intercept_screen.dart';
import 'emulation_screen.dart';

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
        // Фильтруем устройства в зависимости от настройки
        final showAllDevices = state.showAllDevices;
        final filteredDevices = showAllDevices 
            ? state.discoveredDevices 
            : state.discoveredDevices.where((device) => device.isConnectable == true).toList();

        return Column(
          children: [
            // Заголовок с количеством устройств и фильтром
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
                  Expanded(
                    child: Row(
                      children: [
                        if (state.isScanning) ...[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            showAllDevices 
                                ? 'Все устройства (${state.discoveredDevices.length})'
                                : 'Подключаемые устройства (${filteredDevices.length}/${state.discoveredDevices.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: state.isScanning ? Colors.blue.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Переключатель фильтра
                  InkWell(
                    onTap: () {
                      context.read<BluetoothBloc>().add(const ToggleShowAllDevicesEvent());
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: showAllDevices ? Colors.blue.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: showAllDevices ? Colors.blue.shade300 : Colors.grey.shade400,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            showAllDevices ? Icons.filter_list_off : Icons.filter_list,
                            size: 16,
                            color: showAllDevices ? Colors.blue.shade700 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            showAllDevices ? 'Все' : 'Активные',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: showAllDevices ? Colors.blue.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Анимированный loader для сканирования
                          if (state.isScanning && state.discoveredDevices.isEmpty) ...[
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade100,
                                    Colors.blue.shade200,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Идет сканирование...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Поиск Bluetooth устройств',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              state.discoveredDevices.isEmpty 
                                  ? Icons.bluetooth_searching 
                                  : showAllDevices 
                                      ? Icons.device_unknown 
                                      : Icons.filter_alt_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.discoveredDevices.isEmpty 
                                  ? 'Устройства не найдены'
                                  : showAllDevices 
                                      ? 'Нет устройств для отображения'
                                      : 'Нет подключаемых устройств',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if (state.discoveredDevices.isNotEmpty && !showAllDevices) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Переключите фильтр, чтобы увидеть все найденные устройства',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredDevices.length + (state.isScanning ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Показываем индикатор сканирования в конце списка
                        if (index == filteredDevices.length && state.isScanning) {
                          return Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Поиск новых устройств...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        final device = filteredDevices[index];
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
                          onConnect: device.isConnectable == true ? () {
                            if (wasPreviouslyConnected && !isConnected) {
                              context.read<BluetoothBloc>().add(
                                    ReconnectToDeviceEvent(device.id),
                                  );
                            } else {
                              context.read<BluetoothBloc>().add(
                                    ConnectToDeviceEvent(device.id),
                                  );
                            }
                          } : null,
                          onReconnect: device.isConnectable == true ? () {
                            context.read<BluetoothBloc>().add(
                                  ReconnectToDeviceEvent(device.id),
                                );
                          } : null,
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
            // Кнопка "Перехват" - рендерится третьей
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _fabExpanded ? 140 : -100,
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
            // Кнопка "Эмуляция" (самая верхняя) - рендерится последней (сверху)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              bottom: _fabExpanded ? 210 : -100, // Еще выше предыдущей кнопки
              right: 0,
              child: SizedBox(
                width: 140,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_emulation',
                  onPressed: _fabExpanded ? () {
                    setState(() {
                      _fabExpanded = false;
                    });
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<BluetoothBloc>(),
                          child: const EmulationScreen(),
                        ),
                      ),
                    );
                  } : null,
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.watch),
                  label: const Text('Эмуляция'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
