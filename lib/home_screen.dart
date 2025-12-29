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
  double _freq1 = 1.0;
  double _freq2 = 2.0;
  double _freq3 = 5.0;
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
                        if (bluetooth.devices.isNotEmpty && !bluetooth.isConnected)
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
                                _addLog('Dispositivo seleccionado: ${device.name}');
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
                                            _addLog('Conectando a ${bluetooth.selectedDevice?.name}...');
                                          }
                                        : null),
                                icon: Icon(bluetooth.isConnected
                                    ? Icons.close
                                    : Icons.bluetooth),
                                label: Text(bluetooth.isConnected
                                    ? 'Desconectar'
                                    : 'Conectar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: bluetooth.isConnected
                                      ? Colors.red
                                      : null,
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
                ],

                // Sliders de frecuencia (solo si está conectado)
                if (bluetooth.isConnected) ...[
                  const Text(
                    'Frecuencia de Destellos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nivel 1
                  _buildFrequencySlider(
                    bluetooth,
                    'Nivel 1 - Info',
                    _freq1,
                    Colors.blue,
                    (value) {
                      setState(() => _freq1 = value);
                      bluetooth.setFrequency(1, value);
                      _addLog('→ FREQ:L1=${value.toStringAsFixed(1)}');
                    },
                  ),

                  const SizedBox(height: 16),

                  // Nivel 2
                  _buildFrequencySlider(
                    bluetooth,
                    'Nivel 2 - Importante',
                    _freq2,
                    Colors.orange,
                    (value) {
                      setState(() => _freq2 = value);
                      bluetooth.setFrequency(2, value);
                      _addLog('→ FREQ:L2=${value.toStringAsFixed(1)}');
                    },
                  ),

                  const SizedBox(height: 16),

                  // Nivel 3
                  _buildFrequencySlider(
                    bluetooth,
                    'Nivel 3 - Urgente',
                    _freq3,
                    Colors.red,
                    (value) {
                      setState(() => _freq3 = value);
                      bluetooth.setFrequency(3, value);
                      _addLog('→ FREQ:L3=${value.toStringAsFixed(1)}');
                    },
                  ),

                  const SizedBox(height: 24),

                  // Botones de selección de alarma (solo habilitados en modo Autónomo)
                  Row(
                    children: [
                      const Text(
                        'Seleccionar Alarma',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!bluetooth.canSelectAlarm) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  if (!bluetooth.canSelectAlarm)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'En modo FLARM, la alarma es controlada automáticamente.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: bluetooth.canSelectAlarm
                              ? () {
                                  bluetooth.testLevel(1);
                                  _addLog('→ SIM:L1');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Nivel 1'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: bluetooth.canSelectAlarm
                              ? () {
                                  bluetooth.testLevel(2);
                                  _addLog('→ SIM:L2');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Nivel 2'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: bluetooth.canSelectAlarm
                              ? () {
                                  bluetooth.testLevel(3);
                                  _addLog('→ SIM:L3');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Nivel 3'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

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
                                onPressed: () => _showPinDialog(bluetooth, true),
                                icon: const Icon(Icons.input, size: 18),
                                label: const Text('Set RX'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showPinDialog(bluetooth, false),
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
                                icon: const Icon(Icons.analytics_outlined, size: 18),
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

                  const SizedBox(height: 24),

                  // Logs de debug
                  Card(
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
                          height: 200,
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
                  ),
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
                    Card(
                      color: Colors.black87,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.terminal, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Logs',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
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
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrequencySlider(
    BluetoothService bluetooth,
    String title,
    double value,
    Color color,
    Function(double) onChanged,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: 0.1,
              max: 10.0,
              divisions: 99,
              activeColor: color,
              onChanged: onChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lento',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Rápido',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
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
                        _addLog('→ MODE:AUTONOMO');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isAutonomo ? Colors.deepPurple : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: isAutonomo ? Colors.white : Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Autónomo',
                              style: TextStyle(
                                color: isAutonomo ? Colors.white : Colors.grey[600],
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
                        _addLog('→ MODE:FLARM');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !isAutonomo ? Colors.orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.airplanemode_active,
                              color: !isAutonomo ? Colors.white : Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'FLARM',
                              style: TextStyle(
                                color: !isAutonomo ? Colors.white : Colors.grey[600],
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
                  ? 'Modo manual: selecciona la alarma con los botones. Ignora señales FLARM.'
                  : 'Modo automático: reacciona a señales FLARM. Apagado cuando no hay alertas.',
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
