import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'bluetooth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Cargar modo guardado y escanear automáticamente al iniciar
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final bluetooth = Provider.of<BluetoothService>(context, listen: false);
      bluetooth.loadSavedMode();
      bluetooth.scanDevices();
    });
  }

  void _addLog(String log) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $log');
      if (_logs.length > 50) _logs.removeAt(0);
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
        title: const Text('SkyPulse Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              setState(() {
                _logs.clear();
              });
              _addLog('Logs limpiados');
            },
            tooltip: 'Limpiar logs',
          ),
        ],
      ),
      body: Consumer<BluetoothService>(
        builder: (context, bluetooth, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Estado de conexión
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              bluetooth.isConnected
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth_disabled,
                              color: bluetooth.isConnected
                                  ? Colors.green
                                  : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bluetooth.statusMessage,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dropdown de dispositivos
                        if (bluetooth.devices.isNotEmpty &&
                            !bluetooth.isConnected)
                          DropdownButtonFormField<BluetoothDevice>(
                            value: bluetooth.selectedDevice,
                            decoration: const InputDecoration(
                              labelText: 'Seleccionar dispositivo',
                              border: OutlineInputBorder(),
                            ),
                            items: bluetooth.devices.map((device) {
                              return DropdownMenuItem(
                                value: device,
                                child: Text(
                                  device.name ?? device.address,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (device) {
                              if (device != null) {
                                bluetooth.setSelectedDevice(device);
                                _addLog(
                                    'Dispositivo seleccionado: ${device.name}');
                              }
                            },
                          ),

                        const SizedBox(height: 12),

                        // Botones de acción
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: bluetooth.isConnected
                                    ? null
                                    : () {
                                        bluetooth.scanDevices();
                                        _addLog('Escaneando dispositivos...');
                                      },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Actualizar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: bluetooth.isConnected
                                    ? () {
                                        bluetooth.disconnect();
                                        _addLog('Desconectando...');
                                      }
                                    : (bluetooth.selectedDevice != null
                                        ? () {
                                            bluetooth.connect();
                                            _addLog(
                                                'Conectando a ${bluetooth.selectedDevice?.name}...');
                                          }
                                        : null),
                                icon: Icon(bluetooth.isConnected
                                    ? Icons.close
                                    : Icons.bluetooth),
                                label: Text(bluetooth.isConnected
                                    ? 'Desconectar'
                                    : 'Conectar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      bluetooth.isConnected ? Colors.red : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Mode Toggle - visible when connected
                if (bluetooth.isConnected) ...[
                  _buildModeToggle(bluetooth),
                  const SizedBox(height: 16),

                  // Alarm level selection (only in Autónomo mode)
                  _buildAlarmSelection(bluetooth),

                  const SizedBox(height: 16),

                  // Configuración de pines
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuración',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  bluetooth.showPins();
                                  _addLog('→ PIN:SHOW');
                                },
                                icon: const Icon(Icons.info_outline, size: 18),
                                label: const Text('Ver Pines'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showPinDialog(bluetooth, true),
                                icon: const Icon(Icons.input, size: 18),
                                label: const Text('Set RX'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showPinDialog(bluetooth, false),
                                icon: const Icon(Icons.output, size: 18),
                                label: const Text('Set TX'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  bluetooth.showStatus();
                                  _addLog('→ STATUS');
                                },
                                icon: const Icon(Icons.analytics_outlined,
                                    size: 18),
                                label: const Text('Estado'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Logs de debug
                  _buildLogsCard(),
                ] else ...[
                  // Mensaje de ayuda si no está conectado
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Cómo conectar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Empareja SkyPulse-FLARM en Ajustes → Bluetooth\n'
                            '2. Vuelve a la app y presiona "Actualizar"\n'
                            '3. Selecciona SkyPulse-FLARM de la lista\n'
                            '4. Presiona "Conectar"',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Logs incluso si no está conectado
                  if (_logs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildLogsCard(),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlarmSelection(BluetoothService bluetooth) {
    final isAutonomo = bluetooth.canSelectAlarm;
    final currentLevel = bluetooth.manualSelectedLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: isAutonomo ? Colors.amber : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Nivel de Alarma',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isAutonomo) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Modo FLARM',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (!isAutonomo)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'En modo FLARM, la alarma es controlada automáticamente por el dispositivo.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 16),

            // Alarm level buttons - OFF, L1, L2, L3
            Row(
              children: [
                // OFF button
                Expanded(
                  child: _buildLevelButton(
                    bluetooth: bluetooth,
                    level: 0,
                    label: 'OFF',
                    color: Colors.grey,
                    isSelected: currentLevel == 0,
                    enabled: isAutonomo,
                  ),
                ),
                const SizedBox(width: 8),
                // Level 1
                Expanded(
                  child: _buildLevelButton(
                    bluetooth: bluetooth,
                    level: 1,
                    label: 'L1',
                    subtitle: 'Info',
                    color: Colors.blue,
                    isSelected: currentLevel == 1,
                    enabled: isAutonomo,
                  ),
                ),
                const SizedBox(width: 8),
                // Level 2
                Expanded(
                  child: _buildLevelButton(
                    bluetooth: bluetooth,
                    level: 2,
                    label: 'L2',
                    subtitle: 'Alerta',
                    color: Colors.orange,
                    isSelected: currentLevel == 2,
                    enabled: isAutonomo,
                  ),
                ),
                const SizedBox(width: 8),
                // Level 3
                Expanded(
                  child: _buildLevelButton(
                    bluetooth: bluetooth,
                    level: 3,
                    label: 'L3',
                    subtitle: 'Urgente',
                    color: Colors.red,
                    isSelected: currentLevel == 3,
                    enabled: isAutonomo,
                  ),
                ),
              ],
            ),

            // Current status indicator
            if (isAutonomo) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentLevel == 0
                      ? Colors.grey[100]
                      : _getLevelColor(currentLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: currentLevel == 0
                        ? Colors.grey[300]!
                        : _getLevelColor(currentLevel).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      currentLevel == 0 ? Icons.flash_off : Icons.flash_on,
                      color: currentLevel == 0
                          ? Colors.grey
                          : _getLevelColor(currentLevel),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentLevel == 0
                          ? 'Flasher apagado'
                          : 'Flasher activo - Nivel $currentLevel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: currentLevel == 0
                            ? Colors.grey[600]
                            : _getLevelColor(currentLevel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLevelButton({
    required BluetoothService bluetooth,
    required int level,
    required String label,
    String? subtitle,
    required Color color,
    required bool isSelected,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              bluetooth.testLevel(level);
              _addLog('→ SIM:L$level');
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (enabled ? color.withOpacity(0.1) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (enabled ? color.withOpacity(0.3) : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? Colors.white : (enabled ? color : Colors.grey),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white70
                      : (enabled ? color.withOpacity(0.7) : Colors.grey),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLogsCard() {
    return Card(
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Monitor de Comandos',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_logs.length} líneas',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.green),
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _logs[index].contains('→')
                        ? Colors.cyan
                        : Colors.green[300],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(BluetoothService bluetooth, bool isRx) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configurar pin ${isRx ? "RX" : "TX"}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de pin',
            hintText: 'Ej: 16, 17',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = int.tryParse(controller.text);
              if (pin != null) {
                if (isRx) {
                  bluetooth.setRxPin(pin);
                  _addLog('→ PIN:RX=$pin');
                } else {
                  bluetooth.setTxPin(pin);
                  _addLog('→ PIN:TX=$pin');
                }
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BluetoothService bluetooth) {
    final isAutonomo = bluetooth.mode == SkyPulseMode.autonomo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.deepPurple, size: 24),
                SizedBox(width: 8),
                Text(
                  'Modo de Operación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        bluetooth.setMode(SkyPulseMode.autonomo);
                        _addLog('→ MODE:AUTONOMO (SIM:ON)');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isAutonomo
                              ? Colors.deepPurple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.touch_app,
                              color:
                                  isAutonomo ? Colors.white : Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Autónomo',
                              style: TextStyle(
                                color: isAutonomo
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        bluetooth.setMode(SkyPulseMode.flarm);
                        _addLog('→ MODE:FLARM (SIM:OFF)');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color:
                              !isAutonomo ? Colors.orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.airplanemode_active,
                              color:
                                  !isAutonomo ? Colors.white : Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'FLARM',
                              style: TextStyle(
                                color: !isAutonomo
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAutonomo
                  ? 'Modo manual: selecciona el nivel de alarma con los botones.'
                  : 'Modo automático: reacciona a señales FLARM reales.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
