import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Operating mode for the SkyPulse device
enum SkyPulseMode { autonomo, flarm }

/// Result of alarm selection based on current mode
class AlarmResult {
  final int level; // 0=OFF, 1-3=L1-L3
  final String source; // 'manual' or 'flarm'

  AlarmResult({required this.level, required this.source});
}

class BluetoothService extends ChangeNotifier {
  BluetoothConnection? _connection;
  bool _isConnected = false;
  String _statusMessage = 'Desconectado';
  String _currentLevel = '0';
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  String _lastMessageTime = 'Nunca';

  // Mode state
  SkyPulseMode _mode = SkyPulseMode.autonomo;
  int _manualSelectedLevel = 0; // 0=OFF, 1-3=L1-L3
  int _flarmAlarmLevel = 0; // Level received from FLARM (0=none, 1-3=L1-L3)

  bool get isConnected => _isConnected;
  String get statusMessage => _statusMessage;
  String get currentLevel => _currentLevel;
  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  String get lastMessageTime => _lastMessageTime;
  SkyPulseMode get mode => _mode;
  int get manualSelectedLevel => _manualSelectedLevel;
  int get flarmAlarmLevel => _flarmAlarmLevel;

  // Solicitar permisos
  Future<bool> requestAllPermissions() async {
    try {
      _statusMessage = 'Solicitando permisos...';
      notifyListeners();

      // Solicitar permisos según versión de Android
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      bool allGranted = statuses.values
          .every((status) => status.isGranted || status.isLimited);

      if (!allGranted) {
        _statusMessage = 'Permisos denegados. Ve a Ajustes → Apps → Permisos';
        notifyListeners();
        return false;
      }

      _statusMessage = 'Permisos concedidos';
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = 'Error solicitando permisos: $e';
      notifyListeners();
      return false;
    }
  }

  // Verificar si Bluetooth está habilitado
  Future<bool> isBluetoothEnabled() async {
    try {
      return await FlutterBluetoothSerial.instance.isEnabled ?? false;
    } catch (e) {
      return false;
    }
  }

  // Solicitar habilitar Bluetooth
  Future<bool> enableBluetooth() async {
    try {
      return await FlutterBluetoothSerial.instance.requestEnable() ?? false;
    } catch (e) {
      _statusMessage = 'Error al habilitar Bluetooth';
      notifyListeners();
      return false;
    }
  }

  // Escanear dispositivos EMPAREJADOS
  Future<void> scanDevices() async {
    try {
      // Verificar y solicitar permisos
      bool hasPermissions = await requestAllPermissions();
      if (!hasPermissions) {
        return;
      }

      // Verificar si Bluetooth está habilitado
      bool bluetoothEnabled = await isBluetoothEnabled();
      if (!bluetoothEnabled) {
        _statusMessage = 'Habilitando Bluetooth...';
        notifyListeners();

        bool enabled = await enableBluetooth();
        if (!enabled) {
          _statusMessage = 'Bluetooth no habilitado. Actívalo en Ajustes';
          notifyListeners();
          return;
        }
      }

      _statusMessage = 'Buscando dispositivos emparejados...';
      notifyListeners();

      // Obtener solo dispositivos EMPAREJADOS (bonded)
      List<BluetoothDevice> bondedDevices =
          await FlutterBluetoothSerial.instance.getBondedDevices();

      _devices = bondedDevices;

      if (_devices.isEmpty) {
        _statusMessage =
            'No hay dispositivos emparejados.\nEmpareja SkyPulse-FLARM en:\nAjustes → Bluetooth';
        notifyListeners();
        return;
      }

      // Buscar automáticamente SkyPulse-FLARM
      BluetoothDevice? skyPulse = _devices.firstWhere(
        (device) => device.name?.toUpperCase().contains('SKYPULSE') ?? false,
        orElse: () => _devices.firstWhere(
          (device) => device.name?.toUpperCase().contains('FLARM') ?? false,
          orElse: () => _devices.first,
        ),
      );

      _selectedDevice = skyPulse;

      if (skyPulse.name?.contains('SkyPulse') ?? false) {
        _statusMessage = 'SkyPulse-FLARM encontrado!';
      } else {
        _statusMessage =
            'Encontrados ${_devices.length} dispositivos emparejados';
      }

      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error al escanear: $e';
      notifyListeners();
    }
  }

  // Conectar a dispositivo seleccionado
  Future<void> connect() async {
    if (_selectedDevice == null) {
      _statusMessage = 'Selecciona un dispositivo';
      notifyListeners();
      return;
    }

    // Verificar permisos antes de conectar
    bool hasPermissions = await requestAllPermissions();
    if (!hasPermissions) {
      return;
    }

    try {
      _statusMessage = 'Conectando a ${_selectedDevice!.name}...';
      notifyListeners();

      // Intentar conectar
      _connection =
          await BluetoothConnection.toAddress(_selectedDevice!.address);

      _isConnected = true;
      _statusMessage = 'Conectado a ${_selectedDevice!.name}';
      notifyListeners();

      // Escuchar datos recibidos
      _connection!.input!.listen(
        (Uint8List data) {
          String message = String.fromCharCodes(data);
          _handleReceivedData(message);
        },
        onDone: () {
          _isConnected = false;
          _statusMessage = 'Desconectado';
          notifyListeners();
        },
        onError: (error) {
          _isConnected = false;
          _statusMessage = 'Error de conexión: $error';
          notifyListeners();
        },
      );

      // Enviar comando de estado inicial
      await Future.delayed(const Duration(milliseconds: 500));
      await sendCommand('STATUS');

      // Send current mode to device after connection
      await Future.delayed(const Duration(milliseconds: 100));
      await _sendModeToDevice();

      // If in autonomo mode with a selected level, restore it
      if (_mode == SkyPulseMode.autonomo && _manualSelectedLevel > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _sendFlasherLevel(_manualSelectedLevel);
      }
    } catch (e) {
      _isConnected = false;
      _statusMessage = 'Error de conexión: $e';
      notifyListeners();
    }
  }

  /// Send mode command sequence to device
  /// In FLARM mode: device responds to real FLARM alarms (MODE_AUTO)
  /// In Autónomo mode: we use SIM:Lx commands to manually control (also needs MODE_AUTO)
  Future<void> _sendModeToDevice() async {
    if (_mode == SkyPulseMode.flarm) {
      // Enter FLARM/AUTO mode: turn off any simulation, let real FLARM control
      await sendCommand('SIM:OFF');
      await Future.delayed(const Duration(milliseconds: 100));
      await sendCommand('SIM:L0'); // Clear any alarm level
    } else {
      // Autónomo mode: enable simulation so SIM:Lx commands work
      await sendCommand('SIM:ON');
    }
  }

  /// Send flasher level command using SIM:Lx (works in MODE_AUTO which is default)
  Future<void> _sendFlasherLevel(int level) async {
    // Use SIM:Lx commands - these work in MODE_AUTO (firmware default)
    await sendCommand('SIM:L$level');
  }

  // Desconectar
  Future<void> disconnect() async {
    try {
      await _connection?.close();
      _connection = null;
      _isConnected = false;
      _statusMessage = 'Desconectado';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error al desconectar: $e';
      notifyListeners();
    }
  }

  // Enviar comando
  Future<void> sendCommand(String command) async {
    if (!_isConnected || _connection == null) {
      _statusMessage = 'No conectado';
      notifyListeners();
      return;
    }

    try {
      _connection!.output.add(Uint8List.fromList('$command\n'.codeUnits));
      await _connection!.output.allSent;
    } catch (e) {
      _statusMessage = 'Error al enviar: $e';
      notifyListeners();
    }
  }

  // Configurar frecuencia de nivel
  Future<void> setFrequency(int level, double frequency) async {
    await sendCommand('FREQ:L$level=${frequency.toStringAsFixed(1)}');
  }

  // Comandos rápidos - FIX: Use FLASH:Lx commands in manual mode
  Future<void> testLevel(int level) async {
    // Only allow manual level selection in Autónomo mode
    if (_mode == SkyPulseMode.flarm) {
      _statusMessage = 'Selección manual deshabilitada en modo FLARM';
      notifyListeners();
      return;
    }

    _manualSelectedLevel = level;

    // FIX: Use FLASH:OFF or FLASH:Lx commands for MANUAL mode
    // The old SIM:Lx commands only work in MODE_AUTO (FLARM mode)
    await _sendFlasherLevel(level);

    // Persist the selected level
    _persistManualLevel(level);

    notifyListeners();
  }

  /// Persist manual level selection
  Future<void> _persistManualLevel(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('skypulse_manual_level', level);
    } catch (e) {
      // Continue even if persistence fails
    }
  }

  /// Load saved manual level from SharedPreferences
  Future<void> _loadSavedManualLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _manualSelectedLevel = prefs.getInt('skypulse_manual_level') ?? 0;
    } catch (e) {
      _manualSelectedLevel = 0;
    }
  }

  Future<void> setRxPin(int pin) async {
    await sendCommand('PIN:RX=$pin');
  }

  Future<void> setTxPin(int pin) async {
    await sendCommand('PIN:TX=$pin');
  }

  Future<void> showPins() async {
    await sendCommand('PIN:SHOW');
  }

  Future<void> showStatus() async {
    await sendCommand('STATUS');
  }

  // Manejar datos recibidos
  void _handleReceivedData(String data) {
    if (data.contains('Level:')) {
      RegExp regExp = RegExp(r'Level:\s*(\d+)');
      Match? match = regExp.firstMatch(data);
      if (match != null) {
        _currentLevel = match.group(1) ?? '0';
        notifyListeners();
      }
    }

    // Parse FLARM alarm level (only relevant in FLARM mode)
    if (data.contains('FLARM:L')) {
      RegExp regExp = RegExp(r'FLARM:L(\d+)');
      Match? match = regExp.firstMatch(data);
      if (match != null) {
        _flarmAlarmLevel = int.tryParse(match.group(1) ?? '0') ?? 0;
        notifyListeners();
      }
    }

    // FLARM clear/no-alarm condition
    if (data.contains('FLARM:OFF') || data.contains('FLARM:CLEAR')) {
      _flarmAlarmLevel = 0;
      notifyListeners();
    }

    if (data.contains('OK')) {
      _lastMessageTime = 'Ahora';
      notifyListeners();
    }
  }

  void setSelectedDevice(BluetoothDevice device) {
    _selectedDevice = device;
    notifyListeners();
  }

  // ============================================
  // MODE MANAGEMENT
  // ============================================

  /// Load saved mode and level from SharedPreferences on startup
  Future<void> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('skypulse_mode') ?? 'autonomo';
      _mode = modeStr == 'flarm' ? SkyPulseMode.flarm : SkyPulseMode.autonomo;

      // Also load saved manual level
      _manualSelectedLevel = prefs.getInt('skypulse_manual_level') ?? 0;

      notifyListeners();
    } catch (e) {
      // Default to autonomo if loading fails
      _mode = SkyPulseMode.autonomo;
      _manualSelectedLevel = 0;
    }
  }

  /// Set operating mode, persist it, and send to device
  /// Both modes use firmware's MODE_AUTO - we control behavior via SIM commands
  /// FLARM mode: SIM:OFF, let real FLARM alarms control flasher
  /// Autónomo mode: SIM:ON + SIM:Lx to manually control flasher
  Future<void> setMode(SkyPulseMode newMode) async {
    if (_mode == newMode) return;

    // Send commands to device if connected
    if (_isConnected) {
      if (newMode == SkyPulseMode.flarm) {
        // Switching to FLARM mode: disable simulation, clear level
        await sendCommand('SIM:OFF');
        await Future.delayed(const Duration(milliseconds: 100));
        await sendCommand('SIM:L0');
      } else {
        // Switching to Autónomo mode: enable simulation
        await sendCommand('SIM:ON');
        // Restore previously selected level if any
        if (_manualSelectedLevel > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
          await _sendFlasherLevel(_manualSelectedLevel);
        }
      }
    }

    // Update internal state
    _mode = newMode;
    notifyListeners();

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('skypulse_mode',
          newMode == SkyPulseMode.flarm ? 'flarm' : 'autonomo');
    } catch (e) {
      // Continue even if persistence fails
    }
  }

  /// Set the manual alarm level (used in Autónomo mode)
  void setManualLevel(int level) {
    _manualSelectedLevel = level.clamp(0, 3);
    notifyListeners();
  }

  /// Central function to determine the active alarm based on current mode
  /// - In AUTONOMO mode: returns the manually selected alarm level
  /// - In FLARM mode: returns the FLARM-derived alarm level (device handles this)
  AlarmResult getActiveAlarmForCurrentMode() {
    if (_mode == SkyPulseMode.autonomo) {
      return AlarmResult(level: _manualSelectedLevel, source: 'manual');
    } else {
      // In FLARM mode, device controls the alarm based on FLARM signals
      // Returns current FLARM level (0 = OFF when no FLARM alarms)
      return AlarmResult(level: _flarmAlarmLevel, source: 'flarm');
    }
  }

  /// Check if manual alarm selection is allowed in current mode
  bool get canSelectAlarm => _mode == SkyPulseMode.autonomo;

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
