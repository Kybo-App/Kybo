// Gestisce connessione BLE a bilance smart (standard Weight Scale e Xiaomi Mi Scale).
// _onWeightData — decodifica i byte del Weight Measurement characteristic e salva il peso; _parseWeightKg — converte raw uint16 in kg supportando sia SI che libbre.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tracking_service.dart';

const String _kWeightScaleServiceUuid = '0000181d-0000-1000-8000-00805f9b34fb';
const String _kWeightMeasurementCharUuid = '00002a9d-0000-1000-8000-00805f9b34fb';

const String _kBodyCompositionServiceUuid = '0000181b-0000-1000-8000-00805f9b34fb';

class ScaleService extends ChangeNotifier {
  final TrackingService _trackingService = TrackingService();

  List<BluetoothDevice> _scannedDevices = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  double? _lastWeight;
  String? _bleError;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  List<BluetoothDevice> get scannedDevices => _scannedDevices;
  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  double? get lastWeight => _lastWeight;
  String? get bleError => _bleError;
  bool get isConnected => _connectedDevice != null;

  Future<void> scanForScales() async {
    _bleError = null;

    final hasPermission = await _requestBluetoothPermissions();
    if (!hasPermission) {
      _bleError = 'Permesso Bluetooth negato. Abilitalo nelle impostazioni del dispositivo.';
      notifyListeners();
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _bleError = 'Il Bluetooth non è attivo. Attivalo e riprova.';
      notifyListeners();
      return;
    }

    _scannedDevices = [];
    _isScanning = true;
    notifyListeners();

    await _scanSubscription?.cancel();

    try {
      await FlutterBluePlus.startScan(
        withServices: [
          Guid(_kWeightScaleServiceUuid),
          Guid(_kBodyCompositionServiceUuid),
        ],
        timeout: const Duration(seconds: 10),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final devices = results.map((r) => r.device).toList();
        final seen = <DeviceIdentifier>{};
        _scannedDevices = devices.where((d) => seen.add(d.remoteId)).toList();
        notifyListeners();
      });

      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      _bleError = 'Errore durante la scansione: $e';
      debugPrint('❌ BLE scan error: $e');
    } finally {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connectToScale(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      notifyListeners();

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _notifySubscription?.cancel();
          notifyListeners();
        }
      });

      final services = await device.discoverServices();
      for (final service in services) {
        final sUuid = service.uuid.toString().toLowerCase();
        if (sUuid == _kWeightScaleServiceUuid || sUuid == _kBodyCompositionServiceUuid) {
          for (final char in service.characteristics) {
            final cUuid = char.uuid.toString().toLowerCase();
            if (cUuid == _kWeightMeasurementCharUuid || char.properties.notify || char.properties.indicate) {
              await char.setNotifyValue(true);
              _notifySubscription = char.lastValueStream.listen(_onWeightData);
              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      _bleError = 'Errore connessione: $e';
      _connectedDevice = null;
      debugPrint('❌ BLE connect error: $e');
      notifyListeners();
    }
  }

  Future<void> disconnectScale() async {
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    notifyListeners();
  }

  void _onWeightData(List<int> data) {
    if (data.isEmpty) return;

    try {
      final kg = _parseWeightKg(data);
      if (kg == null || kg < 5 || kg > 300) return;

      _lastWeight = kg;
      debugPrint('⚖️ Peso ricevuto da BLE: ${kg.toStringAsFixed(1)} kg');

      _trackingService.saveWeight(kg, note: 'Da bilancia Bluetooth');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ BLE parse error: $e');
    }
  }

  double? _parseWeightKg(List<int> data) {
    if (data.length < 3) return null;

    final flags = data[0];
    final isLbs = (flags & 0x01) != 0;

    final raw = data[1] | (data[2] << 8);

    if (isLbs) {
      final lbs = raw * 0.01;
      return lbs * 0.453592;
    } else {
      return raw * 0.005;
    }
  }

  Future<bool> _requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
