import 'package:flutter/material.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';

/// Dashboard metriche server — visibile solo agli admin.
/// Legge /metrics/api e /health/detailed dal backend e mostra:
///   - Stato servizi (health check)
///   - Cache hit ratio per layer (L1 RAM, L1.5 Redis, L2 Firestore)
///   - Gemini AI: chiamate, errori, durata media
///   - OCR: scansioni, errori, durata media
///   - HTTP: richieste totali, latenza
class ServerMetricsView extends StatefulWidget {
  const ServerMetricsView({super.key});

  @override
  State<ServerMetricsView> createState() => _ServerMetricsViewState();
}

class _ServerMetricsViewState extends State<ServerMetricsView> {
  final _repo = AdminRepository();

  Map<String, dynamic>? _metrics;
  Map<String, dynamic>? _health;
  bool _loading = true;
  String? _error;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getServerMetrics(),
        _repo.getHealthDetailed(),
      ]);
      if (mounted) {
        setState(() {
          _metrics = results[0];
          _health = results[1];
          _loading = false;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          _buildError()
        else
          Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KyboColors.primary.withValues(alpha: 0.1),
            borderRadius: KyboBorderRadius.medium,
          ),
          child: Icon(Icons.monitor_heart_rounded,
              color: KyboColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server & Metriche',
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_lastRefresh != null)
                Text(
                  'Aggiornato alle ${_lastRefresh!.hour.toString().padLeft(2, '0')}:${_lastRefresh!.minute.toString().padLeft(2, '0')}:${_lastRefresh!.second.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: KyboColors.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        PillButton(
          label: 'Aggiorna',
          icon: Icons.refresh_rounded,
          height: 38,
          onPressed: _loading ? null : _load,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: KyboColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Errore nel caricamento metriche',
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: TextStyle(color: KyboColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PillButton(
              label: 'Riprova',
              icon: Icons.refresh_rounded,
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HEALTH CHECK ───────────────────────────────────────────────
          _buildSectionTitle('Stato Servizi', Icons.health_and_safety_rounded),
          const SizedBox(height: 12),
          _buildHealthSection(),
          const SizedBox(height: 28),

          // ─── GEMINI AI ──────────────────────────────────────────────────
          _buildSectionTitle('Gemini AI', Icons.auto_awesome_rounded),
          const SizedBox(height: 12),
          _buildGeminiSection(),
          const SizedBox(height: 28),

          // ─── CACHE ──────────────────────────────────────────────────────
          _buildSectionTitle('Cache', Icons.layers_rounded),
          const SizedBox(height: 12),
          _buildCacheSection(),
          const SizedBox(height: 28),

          // ─── OCR ────────────────────────────────────────────────────────
          _buildSectionTitle('OCR Scontrini', Icons.document_scanner_rounded),
          const SizedBox(height: 12),
          _buildOcrSection(),
          const SizedBox(height: 28),

          // ─── REDIS ──────────────────────────────────────────────────────
          _buildSectionTitle('Redis', Icons.storage_rounded),
          const SizedBox(height: 12),
          _buildRedisSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEZIONI
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHealthSection() {
    final checks =
        (_health?['checks'] as Map<String, dynamic>?) ?? {};
    final overallStatus = _health?['status'] as String? ?? 'unknown';
    final warnings = (_health?['warnings'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall status badge
        Row(
          children: [
            _StatusChip(
              label: overallStatus == 'healthy' ? 'Healthy' : 'Unhealthy',
              color: overallStatus == 'healthy'
                  ? KyboColors.success
                  : KyboColors.error,
              icon: overallStatus == 'healthy'
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(width: 8),
              _StatusChip(
                label: '${warnings.length} warning',
                color: KyboColors.warning,
                icon: Icons.warning_amber_rounded,
              ),
            ],
            const SizedBox(width: 12),
            Text(
              _health?['environment'] as String? ?? '',
              style: TextStyle(
                color: KyboColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '  v${_health?['version'] ?? ''}',
              style: TextStyle(
                color: KyboColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: checks.entries.map((e) {
            final svc = e.value as Map<String, dynamic>;
            final status = svc['status'] as String? ?? 'unknown';
            final message = svc['message'] as String? ?? '';
            return _ServiceCard(
              name: e.key,
              status: status,
              message: message,
              isWarning: warnings.contains(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGeminiSection() {
    final diet = (_metrics?['diet_parser'] as Map<String, dynamic>?) ?? {};
    final sug =
        (_metrics?['meal_suggestions'] as Map<String, dynamic>?) ?? {};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _GeminiCard(
            title: 'Diet Parser',
            calls: _toInt(diet['gemini_calls']),
            errors: _toInt(diet['gemini_errors']),
            avgDuration: _toDouble(diet['avg_parse_duration_s']),
            durationLabel: 'durata media parsing',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GeminiCard(
            title: 'Meal Suggestions',
            calls: _toInt(sug['gemini_calls']),
            errors: _toInt(sug['gemini_errors']),
            avgDuration: _toDouble(sug['avg_generation_duration_s']),
            durationLabel: 'durata media suggerimenti',
          ),
        ),
      ],
    );
  }

  Widget _buildCacheSection() {
    final diet = (_metrics?['diet_parser'] as Map<String, dynamic>?) ?? {};
    final sug =
        (_metrics?['meal_suggestions'] as Map<String, dynamic>?) ?? {};
    final dietCache = (diet['cache'] as Map<String, dynamic>?) ?? {};
    final sugCache = (sug['cache'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diet Parser',
          style: TextStyle(
            color: KyboColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildCacheLayerRow(dietCache),
        const SizedBox(height: 16),
        Text(
          'Meal Suggestions',
          style: TextStyle(
            color: KyboColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildCacheLayerRow(sugCache),
      ],
    );
  }

  Widget _buildCacheLayerRow(Map<String, dynamic> cache) {
    final layers = [
      ('L1 RAM', cache['L1_ram'] as Map<String, dynamic>?),
      ('L1.5 Redis', cache['L1_5_redis'] as Map<String, dynamic>?),
      ('L2 Firestore', cache['L2_firestore'] as Map<String, dynamic>?),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: layers.map((layer) {
        final name = layer.$1;
        final data = layer.$2;
        final ratio = data?['ratio'] as String? ?? 'N/A';
        final hits = _toInt(data?['hits']);
        final misses = _toInt(data?['misses']);
        final total = hits + misses;
        final pct = total > 0 ? hits / total : 0.0;

        return _CacheLayerCard(
          name: name,
          ratio: ratio,
          hits: hits,
          misses: misses,
          pct: pct,
        );
      }).toList(),
    );
  }

  Widget _buildOcrSection() {
    // OCR non è in /metrics/api, mostriamo solo info dal health
    final tesseract =
        ((_health?['checks'] as Map<String, dynamic>?)?['tesseract']
                as Map<String, dynamic>?) ??
            {};
    final status = tesseract['status'] as String? ?? 'unknown';
    final message = tesseract['message'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface,
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: KyboColors.border),
      ),
      child: Row(
        children: [
          Icon(
            status == 'ok'
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: status == 'ok' ? KyboColors.success : KyboColors.warning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tesseract OCR',
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: KyboColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (status != 'ok')
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: KyboColors.warning.withValues(alpha: 0.1),
                borderRadius: KyboBorderRadius.pill,
              ),
              child: Text(
                'Non disponibile su Render',
                style: TextStyle(
                  color: KyboColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRedisSection() {
    final redis =
        (_metrics?['redis'] as Map<String, dynamic>?) ?? {};
    final available = redis['available'] == true;
    final configured = redis['url_configured'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface,
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: KyboColors.border),
      ),
      child: Row(
        children: [
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: available ? KyboColors.success : KyboColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Redis Cache (L1.5)',
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  available
                      ? 'Connesso e operativo'
                      : configured
                          ? 'Configurato ma non raggiungibile'
                          : 'Non configurato — in uso solo cache RAM + Firestore',
                  style: TextStyle(
                    color: KyboColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(
            label: available ? 'Online' : 'Offline',
            color: available ? KyboColors.success : KyboColors.textMuted,
            icon: available
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: KyboColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: KyboColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

// =============================================================================
// WIDGET HELPER: SERVICE CARD
// =============================================================================

class _ServiceCard extends StatelessWidget {
  final String name;
  final String status;
  final String message;
  final bool isWarning;

  const _ServiceCard({
    required this.name,
    required this.status,
    required this.message,
    this.isWarning = false,
  });

  Color get _color {
    if (status == 'ok') return KyboColors.success;
    if (status == 'disabled') return KyboColors.textMuted;
    if (isWarning) return KyboColors.warning;
    return KyboColors.error;
  }

  IconData get _icon {
    if (status == 'ok') return Icons.check_circle_rounded;
    if (status == 'disabled') return Icons.radio_button_unchecked_rounded;
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KyboColors.surface,
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: _color, size: 16),
              const SizedBox(width: 6),
              Text(
                name[0].toUpperCase() + name.substring(1),
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: KyboColors.textMuted,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET HELPER: GEMINI CARD
// =============================================================================

class _GeminiCard extends StatelessWidget {
  final String title;
  final int calls;
  final int errors;
  final double avgDuration;
  final String durationLabel;

  const _GeminiCard({
    required this.title,
    required this.calls,
    required this.errors,
    required this.avgDuration,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final errorRate = calls > 0 ? (errors / calls * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface,
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: KyboColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: KyboColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          _MetricRow(
            label: 'Chiamate totali',
            value: calls.toString(),
            icon: Icons.call_made_rounded,
            color: KyboColors.primary,
          ),
          const SizedBox(height: 8),
          _MetricRow(
            label: 'Errori',
            value: '$errors (${errorRate.toStringAsFixed(1)}%)',
            icon: Icons.error_outline_rounded,
            color: errors > 0 ? KyboColors.error : KyboColors.textMuted,
          ),
          const SizedBox(height: 8),
          _MetricRow(
            label: durationLabel,
            value: '${avgDuration.toStringAsFixed(1)}s',
            icon: Icons.timer_rounded,
            color: KyboColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET HELPER: CACHE LAYER CARD
// =============================================================================

class _CacheLayerCard extends StatelessWidget {
  final String name;
  final String ratio;
  final int hits;
  final int misses;
  final double pct;

  const _CacheLayerCard({
    required this.name,
    required this.ratio,
    required this.hits,
    required this.misses,
    required this.pct,
  });

  Color get _barColor {
    if (pct >= 0.8) return KyboColors.success;
    if (pct >= 0.5) return KyboColors.warning;
    return KyboColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KyboColors.surface,
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: KyboColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: KyboColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ratio,
            style: TextStyle(
              color: KyboColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: KyboBorderRadius.pill,
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: KyboColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '✓ $hits hit',
                style: TextStyle(
                  color: KyboColors.success,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                '✗ $misses miss',
                style: TextStyle(
                  color: KyboColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET HELPER: STATUS CHIP
// =============================================================================

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET HELPER: METRIC ROW
// =============================================================================

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: KyboColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: KyboColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
