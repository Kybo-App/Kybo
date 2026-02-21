import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tracking_service.dart';

/// UUID standard Bluetooth SIG — Weight Scale (0x181D) e Weight Measurement (0x2A9D)
const String _kWeightScaleServiceUuid = '0000181d-0000-1000-8000-00805f9b34fb';
const String _kWeightMeasurementCharUuid = '00002a9d-0000-1000-8000-00805f9b34fb';

/// UUID Xiaomi Body Composition (0x181B) — compatibilità Mi Scale
const String _kBodyCompositionServiceUuid = '0000181b-0000-1000-8000-00805f9b34fb';

/// Servizio per la connessione a bilance smart via Bluetooth LE.
/// Supporta:
/// - Standard Bluetooth SIG Weight Scale (molte bilance commerciali)
/// - Xiaomi Mi Scale (Body Composition service)
/// - Withings (stub — da configurare con credenziali OAuth)
class ScaleService extends ChangeNotifier {
  final TrackingService _trackingService = TrackingService();

  // --- BLE State ---
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

  // --- Withings State (stub) ---
  final bool isWithingsConfigured = false;

  // -------------------------------------------------------------------------
  // BLE — SCAN
  // -------------------------------------------------------------------------

  /// Richiede i permessi Bluetooth e avvia una scansione di 10 secondi.
  /// Filtra i dispositivi che pubblicizzano Weight Scale o Body Composition service.
  Future<void> scanForScales() async {
    _bleError = null;

    // Richiedi permessi
    final hasPermission = await _requestBluetoothPermissions();
    if (!hasPermission) {
      _bleError = 'Permesso Bluetooth negato. Abilitalo nelle impostazioni del dispositivo.';
      notifyListeners();
      return;
    }

    // Verifica che il BLE sia disponibile
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
        // Deduplicazione per deviceId
        final seen = <DeviceIdentifier>{};
        _scannedDevices = devices.where((d) => seen.add(d.remoteId)).toList();
        notifyListeners();
      });

      // Dopo 10s lo scan si ferma automaticamente
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

  // -------------------------------------------------------------------------
  // BLE — CONNECT
  // -------------------------------------------------------------------------

  /// Connette al dispositivo e si iscrive alle notifiche del Weight Measurement characteristic.
  Future<void> connectToScale(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      notifyListeners();

      // Ascolta disconnessioni
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _notifySubscription?.cancel();
          notifyListeners();
        }
      });

      // Scopri servizi
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

  /// Disconnette dalla bilancia corrente.
  Future<void> disconnectScale() async {
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // BLE — PARSE WEIGHT
  // -------------------------------------------------------------------------

  /// Gestisce i dati in arrivo dal Weight Measurement characteristic.
  /// Formato standard (Bluetooth SIG):
  ///   Byte 0:     Flags — bit 0: unità (0=kg, 1=lb), bit 1: timestamp, bit 2: userID, bit 3: BMI
  ///   Bytes 1-2:  Weight (uint16, little-endian) — risoluzione 0.005 kg (SI) o 0.01 lb
  void _onWeightData(List<int> data) {
    if (data.isEmpty) return;

    try {
      final kg = _parseWeightKg(data);
      if (kg == null || kg < 5 || kg > 300) return; // sanity check

      _lastWeight = kg;
      debugPrint('⚖️ Peso ricevuto da BLE: ${kg.toStringAsFixed(1)} kg');

      // Salva in Firestore (existing TrackingService)
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

    // Weight è uint16 little-endian
    final raw = data[1] | (data[2] << 8);

    if (isLbs) {
      // Risoluzione 0.01 lb → converti in kg
      final lbs = raw * 0.01;
      return lbs * 0.453592;
    } else {
      // Risoluzione 0.005 kg
      return raw * 0.005;
    }
  }

  // -------------------------------------------------------------------------
  // BLE — PERMISSIONS
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // WITHINGS (stub — da configurare con credenziali)
  // -------------------------------------------------------------------------

  /// Avvia il flusso OAuth Withings.
  /// Attualmente non configurato: richiede WITHINGS_CLIENT_ID e WITHINGS_CLIENT_SECRET.
  Future<void> connectWithings() async {
    if (!isWithingsConfigured) {
      throw UnsupportedError(
        'Integrazione Withings non ancora configurata. '
        'Aggiungi WITHINGS_CLIENT_ID e WITHINGS_CLIENT_SECRET.',
      );
    }
    // TODO: implementare OAuth2 Withings quando le credenziali sono disponibili
  }

  /// Sincronizza il peso da Withings.
  Future<void> syncWithingsWeight() async {
    if (!isWithingsConfigured) {
      throw UnsupportedError('Withings non configurato.');
    }
    // TODO: GET /measure?action=getmeas dal backend
  }

  // -------------------------------------------------------------------------
  // DISPOSE
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
