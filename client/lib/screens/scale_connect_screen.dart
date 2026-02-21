import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scale_service.dart';

/// Schermata per connettere una bilancia smart.
/// Tab 1: Bluetooth LE (bilance generiche, Xiaomi, ecc.)
/// Tab 2: Withings (stub, configurazione futura)
class ScaleConnectScreen extends StatefulWidget {
  const ScaleConnectScreen({super.key});

  @override
  State<ScaleConnectScreen> createState() => _ScaleConnectScreenState();
}

class _ScaleConnectScreenState extends State<ScaleConnectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connetti Bilancia'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
            Tab(icon: Icon(Icons.wifi), text: 'Withings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BleTab(),
          _WithingsTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 1: BLUETOOTH LE
// =============================================================================

class _BleTab extends StatelessWidget {
  const _BleTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ScaleService>(
      builder: (context, scale, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(context),
              const SizedBox(height: 16),
              if (scale.isConnected) ...[
                _buildConnectedCard(context, scale),
                const SizedBox(height: 16),
              ],
              if (scale.bleError != null) ...[
                _buildErrorCard(context, scale.bleError!),
                const SizedBox(height: 16),
              ],
              _buildScanButton(context, scale),
              const SizedBox(height: 16),
              if (scale.isScanning) _buildScanning(),
              if (!scale.isScanning && scale.scannedDevices.isNotEmpty)
                _buildDeviceList(context, scale),
              if (!scale.isScanning && scale.scannedDevices.isEmpty && !scale.isConnected)
                _buildNoDevicesHint(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primary.withValues(alpha:0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Supporta bilance con standard Bluetooth Weight Scale (0x181D) — '
                'compatibile con la maggior parte delle bilance smart in commercio e Xiaomi Mi Scale.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedCard(BuildContext context, ScaleService scale) {
    final deviceName = scale.connectedDevice?.platformName.isNotEmpty == true
        ? scale.connectedDevice!.platformName
        : 'Bilancia sconosciuta';

    return Card(
      elevation: 0,
      color: Colors.green.withValues(alpha:0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.green, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connessa: $deviceName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            if (scale.lastWeight != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ultimo peso: ${scale.lastWeight!.toStringAsFixed(1)} kg',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
                label: const Text('Disconnetti',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => scale.disconnectScale(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Card(
      elevation: 0,
      color: Colors.red.withValues(alpha:0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(BuildContext context, ScaleService scale) {
    return FilledButton.icon(
      icon: scale.isScanning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.search),
      label: Text(scale.isScanning ? 'Scansione in corso...' : 'Cerca bilance'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: scale.isScanning || scale.isConnected
          ? null
          : () => scale.scanForScales(),
    );
  }

  Widget _buildScanning() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Ricerca bilance nelle vicinanze...'),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, ScaleService scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bilance trovate (${scale.scannedDevices.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...scale.scannedDevices.map((device) {
          final name = device.platformName.isNotEmpty
              ? device.platformName
              : 'Bilancia sconosciuta';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.scale),
              title: Text(name),
              subtitle: Text(device.remoteId.toString(),
                  style: const TextStyle(fontSize: 11)),
              trailing: FilledButton(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  await scale.connectToScale(device);
                  if (scale.bleError != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(scale.bleError!),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Connetti'),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoDevicesHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bluetooth_searching,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nessuna bilancia trovata',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Assicurati che la bilancia sia accesa e vicina al telefono.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 2: WITHINGS (stub)
// =============================================================================

class _WithingsTab extends StatelessWidget {
  const _WithingsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withValues(alpha:0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monitor_weight_outlined,
                size: 40, color: Color(0xFF00B4D8)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Withings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Integrazione in arrivo',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 0,
            color: Colors.grey[100],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildFeatureRow(
                    Icons.sync,
                    'Sync automatico',
                    'Il peso viene sincronizzato automaticamente ogni volta che sali sulla bilancia.',
                  ),
                  const Divider(height: 24),
                  _buildFeatureRow(
                    Icons.history,
                    'Storico completo',
                    'Importa tutto lo storico pesi dal tuo account Withings.',
                  ),
                  const Divider(height: 24),
                  _buildFeatureRow(
                    Icons.security,
                    'Sicuro e privato',
                    'Accesso tramite OAuth2 ufficiale Withings — nessuna password condivisa.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Connetti Withings'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                backgroundColor: Colors.grey[400],
              ),
              onPressed: null, // disabilitato — configurazione futura
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Disponibile nel prossimo aggiornamento.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF00B4D8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
}
