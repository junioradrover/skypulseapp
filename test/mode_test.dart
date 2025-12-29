import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skypulse_control/bluetooth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SkyPulseMode enum', () {
    test('has correct values', () {
      expect(SkyPulseMode.values.length, 2);
      expect(SkyPulseMode.autonomo.name, 'autonomo');
      expect(SkyPulseMode.flarm.name, 'flarm');
    });
  });

  group('AlarmResult', () {
    test('creates correctly with level and source', () {
      final result = AlarmResult(level: 2, source: 'manual');
      expect(result.level, 2);
      expect(result.source, 'manual');
    });

    test('can represent OFF state', () {
      final result = AlarmResult(level: 0, source: 'flarm');
      expect(result.level, 0);
      expect(result.source, 'flarm');
    });
  });

  group('BluetoothService Mode Logic', () {
    late BluetoothService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = BluetoothService();
    });

    test('defaults to autonomo mode', () {
      expect(service.mode, SkyPulseMode.autonomo);
    });

    test('canSelectAlarm is true in autonomo mode', () {
      expect(service.mode, SkyPulseMode.autonomo);
      expect(service.canSelectAlarm, true);
    });

    test('setMode changes mode to flarm', () async {
      await service.setMode(SkyPulseMode.flarm);
      expect(service.mode, SkyPulseMode.flarm);
    });

    test('setMode changes mode back to autonomo', () async {
      await service.setMode(SkyPulseMode.flarm);
      expect(service.mode, SkyPulseMode.flarm);
      
      await service.setMode(SkyPulseMode.autonomo);
      expect(service.mode, SkyPulseMode.autonomo);
    });

    test('canSelectAlarm is false in flarm mode', () async {
      await service.setMode(SkyPulseMode.flarm);
      expect(service.canSelectAlarm, false);
    });

    test('setManualLevel clamps values between 0 and 3', () {
      service.setManualLevel(5);
      expect(service.manualSelectedLevel, 3);
      
      service.setManualLevel(-1);
      expect(service.manualSelectedLevel, 0);
      
      service.setManualLevel(2);
      expect(service.manualSelectedLevel, 2);
    });
  });

  group('getActiveAlarmForCurrentMode()', () {
    late BluetoothService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = BluetoothService();
    });

    test('returns manual level in autonomo mode', () {
      service.setManualLevel(2);
      
      final result = service.getActiveAlarmForCurrentMode();
      expect(result.level, 2);
      expect(result.source, 'manual');
    });

    test('returns 0 (OFF) in autonomo mode when no level selected', () {
      final result = service.getActiveAlarmForCurrentMode();
      expect(result.level, 0);
      expect(result.source, 'manual');
    });

    test('returns flarm source in flarm mode', () async {
      await service.setMode(SkyPulseMode.flarm);
      
      final result = service.getActiveAlarmForCurrentMode();
      expect(result.source, 'flarm');
      expect(result.level, 0); // No FLARM alarm = OFF
    });

    test('ignores manual level in flarm mode', () async {
      service.setManualLevel(3);
      await service.setMode(SkyPulseMode.flarm);
      
      final result = service.getActiveAlarmForCurrentMode();
      expect(result.source, 'flarm');
      // Manual level is ignored, FLARM level (0) is used
      expect(result.level, 0);
    });
  });

  group('Mode Persistence', () {
    test('saves mode to SharedPreferences when set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BluetoothService();
      
      await service.setMode(SkyPulseMode.flarm);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skypulse_mode'), 'flarm');
    });

    test('saves autonomo mode to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BluetoothService();
      
      await service.setMode(SkyPulseMode.flarm);
      await service.setMode(SkyPulseMode.autonomo);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('skypulse_mode'), 'autonomo');
    });

    test('loadSavedMode loads flarm from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'skypulse_mode': 'flarm'});
      final service = BluetoothService();
      
      await service.loadSavedMode();
      
      expect(service.mode, SkyPulseMode.flarm);
    });

    test('loadSavedMode loads autonomo from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'skypulse_mode': 'autonomo'});
      final service = BluetoothService();
      
      await service.loadSavedMode();
      
      expect(service.mode, SkyPulseMode.autonomo);
    });

    test('loadSavedMode defaults to autonomo when no value stored', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BluetoothService();
      
      await service.loadSavedMode();
      
      expect(service.mode, SkyPulseMode.autonomo);
    });
  });

  group('Mode behavior scenarios', () {
    late BluetoothService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = BluetoothService();
    });

    test('AUTONOMO mode: manual alarm is used regardless of FLARM', () {
      service.setManualLevel(2);
      expect(service.mode, SkyPulseMode.autonomo);
      
      final result = service.getActiveAlarmForCurrentMode();
      expect(result.level, 2);
      expect(result.source, 'manual');
    });

    test('FLARM mode: no FLARM messages = OFF (level 0)', () async {
      await service.setMode(SkyPulseMode.flarm);
      
      final result = service.getActiveAlarmForCurrentMode();
      expect(result.level, 0);
      expect(result.source, 'flarm');
    });

    test('setMode does not trigger if mode unchanged', () async {
      expect(service.mode, SkyPulseMode.autonomo);
      
      await service.setMode(SkyPulseMode.autonomo);
      expect(service.mode, SkyPulseMode.autonomo);
    });

    test('mode persists across simulated app reload', () async {
      SharedPreferences.setMockInitialValues({});
      final service1 = BluetoothService();
      await service1.setMode(SkyPulseMode.flarm);
      
      // Simulate app reload
      final service2 = BluetoothService();
      await service2.loadSavedMode();
      
      expect(service2.mode, SkyPulseMode.flarm);
    });
  });
}



