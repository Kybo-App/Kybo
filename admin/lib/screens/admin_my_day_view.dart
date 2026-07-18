// "La mia giornata" rivisitata per il ruolo ADMIN.
//
// L'admin è un pannello di controllo superiore — non si occupa delle
// faccende quotidiane di un nutrizionista (clienti da ricontattare, diete
// scadute, chat individuali). Questa view sostituisce la MyDayView
// operativa con metriche di sistema, attività recente e scorciatoie
// alle aree di osservazione (Analytics, Reports, Audit, Server Metrics).
//
// La view nutri/PT/independent originale resta in `my_day_view.dart` e
// continua ad essere utilizzata per quei ruoli.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../providers/user_provider.dart';
import '../widgets/design_system.dart';
import '../widgets/smooth_scroll.dart';

class AdminMyDayView extends StatefulWidget {
  /// Callback per saltare a un'altra tab nav. Etichette supportate:
  /// 'users', 'chat', 'analytics', 'reports', 'audit', 'server'.
  final void Function(String label)? onNavigateTo;

  const AdminMyDayView({super.key, this.onNavigateTo});

  @override
  State<AdminMyDayView> createState() => _AdminMyDayViewState();
}

class _AdminMyDayViewState extends State<AdminMyDayView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // [COERENZA 2026-07-07] Profilo dal UserProvider condiviso (sincrono,
    // niente lettura Firestore per-view di users/{uid}).
    _userName = context.read<UserProvider>().firstName;
    _loading = false;
  }

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.goodMorning;
    if (h < 18) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  static const _itDays = [
    'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì',
    'Venerdì', 'Sabato', 'Domenica',
  ];
  static const _itMonths = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ];
  static const _enDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    final l10n = AppLocalizations.of(context);
    return SmoothScroll(
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con saluto a sinistra e, a destra, il pill compatto
            // dello stato sistema → primo segnale visivo ("tutto OK" o
            // "qualcosa è giù") senza occupare una fascia a tutta larghezza.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHeader(l10n)),
                const SizedBox(width: 16),
                _ServerHealthBanner(
                  compact: true,
                  onTap: () => widget.onNavigateTo?.call('server'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildStatsRow(l10n),
            const SizedBox(height: 24),
            _buildRecentActivity(l10n),
            const SizedBox(height: 16),
            _ServerMetricsCard(
              onTap: () => widget.onNavigateTo?.call('server'),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final now = DateTime.now();
    final isItalian = l10n.locale.languageCode == 'it';
    final days = isItalian ? _itDays : _enDays;
    final months = isItalian ? _itMonths : _enMonths;
    final today = isItalian
        ? '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}'
        : '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting(l10n)}${_userName.isNotEmpty ? ', $_userName' : ''}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: KyboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isItalian
              ? '$today — Panoramica sistema'
              : '$today — System overview',
          style: TextStyle(
            fontSize: 14,
            color: KyboColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AppLocalizations l10n) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').snapshots(),
      builder: (ctx, usersSnap) {
        int total = 0;
        int newSignups7d = 0;
        int newSignupsPrev7d = 0; // giorni 8-14 indietro, per trend WoW
        int nutritionists = 0;
        int activeClients = 0;

        if (usersSnap.hasData) {
          final now = DateTime.now();
          for (final d in usersSnap.data!.docs) {
            total++;
            final data = d.data();
            final role = (data['role'] ?? '').toString();
            if (role == 'nutritionist' || role == 'personal_trainer') {
              nutritionists++;
            }
            if (role == 'user' || role == 'independent') {
              final lastSeenRaw = data['last_seen'] ?? data['last_login'];
              if (lastSeenRaw != null) {
                final dt = DateTime.tryParse(lastSeenRaw.toString());
                if (dt != null && now.difference(dt).inDays < 14) {
                  activeClients++;
                }
              }
            }
            final createdAt = data['created_at'];
            DateTime? createdDt;
            if (createdAt is Timestamp) createdDt = createdAt.toDate();
            if (createdAt is String) createdDt = DateTime.tryParse(createdAt);
            if (createdDt != null) {
              final daysAgo = now.difference(createdDt).inDays;
              if (daysAgo < 7) {
                newSignups7d++;
              } else if (daysAgo < 14) {
                newSignupsPrev7d++;
              }
            }
          }
        }

        // Trend WoW per "Nuove iscrizioni": +N rispetto alla settimana
        // precedente (8-14 gg fa). Positivo verde, negativo rosso.
        final signupsDelta = newSignups7d - newSignupsPrev7d;

        // Tutte le card hanno la stessa struttura (title + value + subtitle)
        // così l'altezza è uniforme — anche dove non c'è una vera sottoscritta,
        // riempiamo lo slot con uno spazio "filler" per coerenza visiva.
        return IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _CompactKpiCard(
                  title: 'Utenti totali',
                  value: '$total',
                  subtitle: 'registrati',
                  icon: Icons.group_rounded,
                  color: KyboColors.primary,
                  onTap: () => widget.onNavigateTo?.call('users'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactKpiCard(
                  title: AppLocalizations.of(context).newSignups,
                  value: '$newSignups7d',
                  subtitle: AppLocalizations.of(context).last7Days,
                  icon: Icons.person_add_rounded,
                  color: KyboColors.success,
                  trend: signupsDelta,
                  trendLabel: 'vs sett.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactKpiCard(
                  title: AppLocalizations.of(context).professionalsLabel,
                  value: '$nutritionists',
                  subtitle: AppLocalizations.of(context).nutriAndPtShort,
                  icon: Icons.medical_services_rounded,
                  color: KyboColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactKpiCard(
                  title: AppLocalizations.of(context).activeClientsLabel,
                  value: '$activeClients',
                  subtitle: AppLocalizations.of(context).last14Days,
                  icon: Icons.bolt_rounded,
                  color: KyboColors.warning,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity(AppLocalizations l10n) {
    final isItalian = l10n.locale.languageCode == 'it';
    // [2026-05-26] Sezione molto compattata. L'admin nota cosa è successo
    // a colpo d'occhio ma non occupa metà schermo. Per il dettaglio di
    // tutti gli eventi c'è Audit Log dedicato (linkato a destra).
    return PillCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: KyboColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                isItalian ? 'Attività recente' : 'Recent activity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KyboColors.textPrimary,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => widget.onNavigateTo?.call('audit'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  child: Text(
                    isItalian ? 'Log completo →' : 'Full log →',
                    style: TextStyle(
                      color: KyboColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('access_logs')
                .orderBy('timestamp', descending: true)
                .limit(3)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                  height: 60,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snap.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    isItalian
                        ? 'Nessuna attività recente'
                        : 'No recent activity',
                    style: TextStyle(
                      color: KyboColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final data = doc.data();
                  final action = (data['action'] ?? '-').toString();
                  final actor = (data['actor_email'] ??
                          data['user_email'] ??
                          data['actor'] ??
                          '-')
                      .toString();
                  final ts = data['timestamp'];
                  DateTime? when;
                  if (ts is Timestamp) when = ts.toDate();
                  final whenLabel = when != null
                      ? timeago.format(when,
                          locale: isItalian ? 'it' : 'en')
                      : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // bullet point a sinistra
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: KyboColors.accent.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // action name
                        Expanded(
                          flex: 3,
                          child: Text(
                            action,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: KyboColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // actor (truncato se troppo lungo)
                        Expanded(
                          flex: 2,
                          child: Text(
                            actor,
                            style: TextStyle(
                              fontSize: 11,
                              color: KyboColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // when
                        Text(
                          whenLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: KyboColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations l10n) {
    final isItalian = l10n.locale.languageCode == 'it';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isItalian ? 'Scorciatoie' : 'Quick actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: KyboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.analytics_rounded,
                title: isItalian ? 'Analytics' : 'Analytics',
                subtitle: isItalian ? 'Metriche e trend' : 'Metrics & trends',
                color: KyboColors.primary,
                onTap: () => widget.onNavigateTo?.call('analytics'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.assessment_rounded,
                title: isItalian ? 'Report' : 'Reports',
                subtitle:
                    isItalian ? 'Report aggregati' : 'Aggregate reports',
                color: KyboColors.success,
                onTap: () => widget.onNavigateTo?.call('reports'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.monitor_heart_rounded,
                title: isItalian ? 'Server' : 'Server',
                subtitle: isItalian ? 'Health backend' : 'Backend health',
                color: KyboColors.warning,
                onTap: () => widget.onNavigateTo?.call('server'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.security_rounded,
                title: isItalian ? 'Audit Log' : 'Audit Log',
                subtitle:
                    isItalian ? 'Eventi sensibili' : 'Sensitive events',
                color: KyboColors.accent,
                onTap: () => widget.onNavigateTo?.call('audit'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// KPI card compatta usata in AdminMyDayView. Tutte e 4 le KPI hanno la
/// stessa struttura (icona + title + valore + subtitle) così l'altezza è
/// uniforme e l'header di MyDay sta in viewport senza scroll.
///
/// Dimensioni ridotte rispetto a `StatCard` del design system:
/// - padding 14 (vs 24)
/// - icon 36px (vs 56)
/// - valore 22px (vs 28)
/// - title 11px (vs 13)
class _CompactKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  /// Trend numerico rispetto al periodo precedente (es. -3, 0, +5).
  /// Se null o trendLabel null, nessun pill mostrato.
  final int? trend;
  final String? trendLabel;

  const _CompactKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.trend,
    this.trendLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = PillCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icona (più piccola)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Title / value / subtitle in colonna
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                // Subtitle SEMPRE presente nella struttura → altezza uniforme
                // tra tutte le 4 card, anche quelle senza trend.
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (trend != null && trendLabel != null) ...[
                      const SizedBox(width: 6),
                      _TrendPill(
                        trend: trend!,
                        label: trendLabel!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: KyboBorderRadius.large,
      child: card,
    );
  }
}

/// Pill compatto "↑+N vs sett." da inserire accanto al subtitle della
/// _CompactKpiCard. Verde se positivo, rosso se negativo, neutro se 0.
class _TrendPill extends StatelessWidget {
  final int trend;
  final String label;

  const _TrendPill({required this.trend, required this.label});

  @override
  Widget build(BuildContext context) {
    final isPositive = trend > 0;
    final isFlat = trend == 0;
    final trendColor = isFlat
        ? KyboColors.textMuted
        : (isPositive ? KyboColors.success : KyboColors.error);
    final arrow = isFlat
        ? Icons.remove_rounded
        : (isPositive
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded);
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrow, size: 10, color: trendColor),
          const SizedBox(width: 1),
          Text(
            '$sign$trend',
            style: TextStyle(
              color: trendColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: trendColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner in cima alla AdminMyDayView con lo stato di salute dei servizi
/// backend (Firebase, Gemini, Redis, Tesseract, Sentry). Polla /system/status
/// ogni 60 secondi. Click → naviga a Server Metrics per dettagli.
class _ServerHealthBanner extends StatefulWidget {
  final VoidCallback? onTap;
  /// compact=true → pill stretto (icona + titolo breve) da mettere a destra
  /// dell'header. compact=false → fascia larga (icona + titolo + sottotitolo).
  final bool compact;
  const _ServerHealthBanner({this.onTap, this.compact = false});

  @override
  State<_ServerHealthBanner> createState() => _ServerHealthBannerState();
}

class _ServerHealthBannerState extends State<_ServerHealthBanner> {
  final _repo = AdminRepository();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _errored = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.getHealthDetailed();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _errored = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errored = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return _shell(
        color: KyboColors.textMuted,
        icon: Icons.hourglass_top_rounded,
        title: l10n.checkingServices,
        compactLabel: '…',
        subtitle: '',
      );
    }

    if (_errored || _data == null) {
      return _shell(
        color: KyboColors.error,
        icon: Icons.cloud_off_rounded,
        title: l10n.backendUnreachable,
        compactLabel: l10n.backendKo,
        subtitle: l10n.systemStatusUnreachable,
      );
    }

    final data = _data!;
    final status = (data['status'] ?? 'unknown').toString();
    final checks = (data['checks'] as Map<String, dynamic>?) ?? {};
    final env = (data['environment'] ?? '').toString();

    // [FIX 2026-05-27] Usiamo la classificazione del SERVER (top-level
    // `errors` / `warnings` array) invece di contare ogni `status: 'error'`
    // dei singoli check. Il server promuove a "warning" gli error nei
    // servizi OPTIONAL_SERVICES (tesseract, redis), così il status overall
    // resta "healthy" se non manca nulla di critico.
    final serverErrors = (data['errors'] as List<dynamic>?) ?? [];
    final serverWarnings = (data['warnings'] as List<dynamic>?) ?? [];
    final errors = serverErrors.length;
    final warnings = serverWarnings.length;
    final issuesNames = [
      ...serverErrors.map((e) => e.toString()),
      ...serverWarnings.map((w) => w.toString()),
    ];

    int ok = 0;
    checks.forEach((_, value) {
      if (value is Map && value['status'] == 'ok') ok++;
    });

    final total = checks.length;
    final isHealthy = status == 'healthy';
    final color = errors > 0
        ? KyboColors.error
        : (warnings > 0 || !isHealthy
            ? KyboColors.warning
            : KyboColors.success);
    final icon = errors > 0
        ? Icons.error_rounded
        : (warnings > 0 || !isHealthy
            ? Icons.warning_amber_rounded
            : Icons.check_circle_rounded);

    final title = errors > 0
        ? '${l10n.systemLabel}: ${l10n.servicesDown(errors)}'
        : (warnings > 0
            ? '${l10n.systemLabel}: $warnings warning'
            : '${l10n.systemLabel}: ${l10n.systemAllOkShort}');
    // Etichetta breve per la modalità compatta (pill stretto a destra header).
    final compactLabel = errors > 0
        ? l10n.servicesDown(errors)
        : (warnings > 0 ? '$warnings warning' : l10n.systemAllOkShort);
    final subtitle = errors > 0 || warnings > 0
        ? '${l10n.issuesPrefix}: ${issuesNames.join(", ")} • ${l10n.servicesOk(ok, total)}'
        : '${l10n.servicesOk(ok, total)}${env.isNotEmpty ? " • $env" : ""}';

    return _shell(
      color: color,
      icon: icon,
      title: title,
      compactLabel: compactLabel,
      subtitle: subtitle,
      onTap: widget.onTap,
    );
  }

  /// Sceglie tra pill compatto (header destra) e fascia larga.
  Widget _shell({
    required Color color,
    required IconData icon,
    required String title,
    required String compactLabel,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    if (widget.compact) {
      return _compactShell(
        color: color,
        icon: icon,
        label: compactLabel,
        tooltip: subtitle.isNotEmpty ? '$title — $subtitle' : title,
        onTap: onTap,
      );
    }
    return _bannerShell(
      color: color,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  /// Pill compatto: icona + label breve, larghezza intrinseca. Tooltip con
  /// i dettagli completi. Da mettere a destra dell'header.
  Widget _compactShell({
    required Color color,
    required IconData icon,
    required String label,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final content = Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: KyboBorderRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color, size: 16),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: KyboBorderRadius.pill,
      child: content,
    );
  }

  Widget _bannerShell({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: KyboColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: color,
              size: 24,
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: KyboBorderRadius.medium,
      child: content,
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KyboBorderRadius.large,
      child: PillCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: KyboBorderRadius.medium,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: KyboColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: KyboColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: KyboColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card compatta con metriche operative del backend lette da /metrics/api.
/// 4 mini-KPI in riga orizzontale: chiamate Gemini, errori Gemini, cache
/// hit ratio, durata media parsing diete. Polling ogni 60s. Click → naviga
/// a Server Metrics per la dashboard completa.
class _ServerMetricsCard extends StatefulWidget {
  final VoidCallback? onTap;
  const _ServerMetricsCard({this.onTap});

  @override
  State<_ServerMetricsCard> createState() => _ServerMetricsCardState();
}

class _ServerMetricsCardState extends State<_ServerMetricsCard> {
  final _repo = AdminRepository();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _errored = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.getServerMetrics();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _errored = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errored = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (widget.onTap == null) return content;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: KyboBorderRadius.large,
      child: content,
    );
  }

  Widget _content() {
    if (_loading) {
      return PillCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: const SizedBox(
          height: 60,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_errored || _data == null) {
      return PillCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded,
                color: KyboColors.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              'Metriche server non disponibili',
              style: TextStyle(
                color: KyboColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final data = _data!;
    final diet = (data['diet_parser'] as Map?) ?? {};
    final sug = (data['meal_suggestions'] as Map?) ?? {};

    // Somma chiamate Gemini totali (diet + suggestions)
    final geminiCalls = ((diet['gemini_calls'] as num?) ?? 0).toInt() +
        ((sug['gemini_calls'] as num?) ?? 0).toInt();
    final geminiErrors = ((diet['gemini_errors'] as num?) ?? 0).toInt() +
        ((sug['gemini_errors'] as num?) ?? 0).toInt();

    // Hit ratio cache L1 (RAM) per diet — la più rappresentativa
    final dietCache = (diet['cache'] as Map?) ?? {};
    final l1 = (dietCache['L1_ram'] as Map?) ?? {};
    final l1Ratio = (l1['ratio'] ?? 'n/a').toString();

    // Tempo medio parse diete (in secondi → ms o s leggibile)
    final avgParseS = (diet['avg_parse_duration_s'] as num?)?.toDouble() ?? 0.0;
    final avgParseLabel = avgParseS > 0
        ? (avgParseS < 1
            ? '${(avgParseS * 1000).toStringAsFixed(0)}ms'
            : '${avgParseS.toStringAsFixed(1)}s')
        : 'n/a';

    final errorColor = geminiErrors > 0 ? KyboColors.error : KyboColors.success;

    return PillCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                size: 16,
                color: KyboColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Metriche server',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KyboColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (widget.onTap != null)
                Text(
                  'Dettagli →',
                  style: TextStyle(
                    color: KyboColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniServerStat(
                label: 'Gemini',
                value: '$geminiCalls',
                hint: 'chiamate',
                color: KyboColors.primary,
              ),
              const SizedBox(width: 8),
              _MiniServerStat(
                label: AppLocalizations.of(context).serverErrorsLabel,
                value: '$geminiErrors',
                hint: 'gemini',
                color: errorColor,
              ),
              const SizedBox(width: 8),
              _MiniServerStat(
                label: 'Cache hit',
                value: l1Ratio,
                hint: 'L1 diet',
                color: KyboColors.accent,
              ),
              const SizedBox(width: 8),
              _MiniServerStat(
                label: 'Parse',
                value: avgParseLabel,
                hint: 'avg dieta',
                color: KyboColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mini-stat box usato dentro _ServerMetricsCard. Compatto, 4 vanno in riga.
class _MiniServerStat extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _MiniServerStat({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: KyboBorderRadius.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: KyboColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              hint,
              style: TextStyle(
                fontSize: 10,
                color: KyboColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
