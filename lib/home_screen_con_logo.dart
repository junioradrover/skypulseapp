import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'bluetooth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _rxController = TextEditingController(text: '16');
  final TextEditingController _txController = TextEditingController(text: '17');
  
  // Frecuencias en Hz (destellos por segundo)
  double _level1Frequency = 1.0;  // 1 Hz = 1 destello/seg
  double _level2Frequency = 2.0;  // 2 Hz = 2 destellos/seg
  double _level3Frequency = 5.0;  // 5 Hz = 5 destellos/seg

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothService>().initialize();
    });
  }

  @override
  void dispose() {
    _rxController.dispose();
    _txController.dispose();
    super.dispose();
  }

  void _savePins() async {
    final service = context.read<BluetoothService>();
    final rx = int.tryParse(_rxController.text);
    final tx = int.tryParse(_txController.text);

    if (rx == null || tx == null || rx < 0 || rx > 39 || tx < 0 || tx > 39) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pines deben ser números entre 0 y 39'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await service.sendCommand('PIN:RX=$rx');
    await Future.delayed(const Duration(milliseconds: 100));
    await service.sendCommand('PIN:TX=$tx');
    await Future.delayed(const Duration(milliseconds: 100));
    await service.sendCommand('RESTART');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Configuración guardada, reiniciando...'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _testLevel(int level) async {
    final service = context.read<BluetoothService>();
    
    // Primero activar simulación si no está activa
    if (!service.isSimulationActive) {
      await service.sendCommand('SIM:ON');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Enviar frecuencia correspondiente
    double frequency;
    switch (level) {
      case 1:
        frequency = _level1Frequency;
        break;
      case 2:
        frequency = _level2Frequency;
        break;
      case 3:
        frequency = _level3Frequency;
        break;
      default:
        frequency = 1.0;
    }
    
    // Enviar comando de frecuencia
    await service.sendCommand('FREQ:L$level=$frequency');
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Activar nivel
    await service.sendCommand('SIM:L$level');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<BluetoothService>(
          builder: (context, service, _) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // HEADER CON LOGO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        // Estado de conexión
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: service.isConnected ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              service.isConnected ? 'Conectado' : 'Desconectado',
                              style: TextStyle(
                                color: service.isConnected ? Colors.green : Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // CONTENIDO
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // CONEXIÓN BLUETOOTH
                        _buildSection(
                          title: 'CONEXIÓN BLUETOOTH',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (service.deviceName.isNotEmpty) ...[
                                Text(
                                  service.deviceName,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (service.isConnected)
                                ElevatedButton(
                                  onPressed: service.disconnect,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                  ),
                                  child: const Text('Desconectar'),
                                )
                              else
                                ElevatedButton(
                                  onPressed: service.connect,
                                  child: const Text('Conectar'),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // CONFIGURACIÓN DE PINES
                        _buildSection(
                          title: 'CONFIGURACIÓN DE PINES',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _rxController,
                                      decoration: const InputDecoration(
                                        labelText: 'Pin RX',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _txController,
                                      decoration: const InputDecoration(
                                        labelText: 'Pin TX',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: service.isConnected ? _savePins : null,
                                  child: const Text('Guardar Configuración'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // FRECUENCIA DE ALARMAS
                        _buildSection(
                          title: 'FRECUENCIA DE DESTELLOS',
                          child: Column(
                            children: [
                              // Nivel 1
                              _buildFrequencySlider(
                                label: 'Nivel 1 - Info',
                                color: const Color(0xFF90CAF9),
                                value: _level1Frequency,
                                onChanged: (value) {
                                  setState(() => _level1Frequency = value);
                                },
                                onChangeEnd: (value) async {
                                  if (service.isConnected) {
                                    await service.sendCommand('FREQ:L1=$value');
                                  }
                                },
                              ),
                              const SizedBox(height: 24),
                              
                              // Nivel 2
                              _buildFrequencySlider(
                                label: 'Nivel 2 - Importante',
                                color: const Color(0xFFFFB74D),
                                value: _level2Frequency,
                                onChanged: (value) {
                                  setState(() => _level2Frequency = value);
                                },
                                onChangeEnd: (value) async {
                                  if (service.isConnected) {
                                    await service.sendCommand('FREQ:L2=$value');
                                  }
                                },
                              ),
                              const SizedBox(height: 24),
                              
                              // Nivel 3
                              _buildFrequencySlider(
                                label: 'Nivel 3 - Urgente',
                                color: const Color(0xFFEF5350),
                                value: _level3Frequency,
                                onChanged: (value) {
                                  setState(() => _level3Frequency = value);
                                },
                                onChangeEnd: (value) async {
                                  if (service.isConnected) {
                                    await service.sendCommand('FREQ:L3=$value');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // PROBAR ALARMAS
                        _buildSection(
                          title: 'PROBAR ALARMAS',
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTestButton(
                                  label: '1',
                                  sublabel: 'Info',
                                  color: const Color(0xFF90CAF9),
                                  onPressed: service.isConnected ? () => _testLevel(1) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTestButton(
                                  label: '2',
                                  sublabel: 'Importante',
                                  color: const Color(0xFFFFB74D),
                                  onPressed: service.isConnected ? () => _testLevel(2) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTestButton(
                                  label: '3',
                                  sublabel: 'Urgente',
                                  color: const Color(0xFFEF5350),
                                  onPressed: service.isConnected ? () => _testLevel(3) : null,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ESTADO
                        _buildSection(
                          title: 'ESTADO',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusRow('Nivel actual', service.currentLevel),
                              const SizedBox(height: 8),
                              _buildStatusRow('Último mensaje', service.lastMessageTime),
                              const SizedBox(height: 8),
                              _buildStatusRow('Simulación', service.isSimulationActive ? 'ON' : 'OFF'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildFrequencySlider({
    required String label,
    required Color color,
    required double value,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.toStringAsFixed(1)} Hz',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: 0.1,
            max: 10.0,
            divisions: 99,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lento (0.1 Hz)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Rápido (10 Hz)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTestButton({
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
