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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';

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
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _userName = (data['first_name'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status sistema in cima → primo segnale visivo all'admin appena
          // entra: "tutto OK" o "qualcosa è giù".
          _ServerHealthBanner(
            onTap: () => widget.onNavigateTo?.call('server'),
          ),
          const SizedBox(height: 16),
          _buildHeader(l10n),
          const SizedBox(height: 24),
          _buildStatsRow(l10n),
          const SizedBox(height: 24),
          _buildRecentActivity(l10n),
          const SizedBox(height: 24),
          _buildQuickActions(l10n),
        ],
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

        return Row(
          children: [
            Expanded(
              child: _AdminStatCard(
                title: 'Utenti totali',
                value: '$total',
                icon: Icons.group_rounded,
                color: KyboColors.primary,
                onTap: () => widget.onNavigateTo?.call('users'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AdminStatCard(
                title: 'Nuove iscrizioni',
                value: '$newSignups7d',
                subtitle: 'Ultimi 7 giorni',
                icon: Icons.person_add_rounded,
                color: KyboColors.success,
                trend: signupsDelta,
                trendLabel: 'vs sett. scorsa',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AdminStatCard(
                title: 'Professionisti',
                value: '$nutritionists',
                subtitle: 'Nutrizionisti + PT',
                icon: Icons.medical_services_rounded,
                color: KyboColors.accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AdminStatCard(
                title: 'Clienti attivi',
                value: '$activeClients',
                subtitle: 'Ultimi 14 giorni',
                icon: Icons.bolt_rounded,
                color: KyboColors.warning,
              ),
            ),
          ],
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

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  /// Delta numerico rispetto al periodo precedente (es. -3, 0, +5).
  /// Quando null o quando trendLabel è null, l'indicatore non viene mostrato.
  final int? trend;
  final String? trendLabel;

  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.trend,
    this.trendLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = StatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      subtitle: subtitle,
    );

    // Sovrappongo il trend pill in basso a destra della card.
    if (trend != null && trendLabel != null) {
      final t = trend!;
      final isPositive = t > 0;
      final isFlat = t == 0;
      final trendColor = isFlat
          ? KyboColors.textMuted
          : (isPositive ? KyboColors.success : KyboColors.error);
      final arrow = isFlat
          ? Icons.remove_rounded
          : (isPositive
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded);
      final sign = isPositive ? '+' : '';
      result = Stack(
        children: [
          result,
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(arrow, size: 12, color: trendColor),
                  const SizedBox(width: 2),
                  Text(
                    '$sign$t',
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trendLabel!,
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return result;
    return InkWell(
      onTap: onTap,
      borderRadius: KyboBorderRadius.large,
      child: result,
    );
  }
}

/// Banner in cima alla AdminMyDayView con lo stato di salute dei servizi
/// backend (Firebase, Gemini, Redis, Tesseract, Sentry). Polla /system/status
/// ogni 60 secondi. Click → naviga a Server Metrics per dettagli.
class _ServerHealthBanner extends StatefulWidget {
  final VoidCallback? onTap;
  const _ServerHealthBanner({this.onTap});

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
    if (_loading) {
      return _bannerShell(
        color: KyboColors.textMuted,
        icon: Icons.hourglass_top_rounded,
        title: 'Verifico stato servizi…',
        subtitle: '',
      );
    }

    if (_errored || _data == null) {
      return _bannerShell(
        color: KyboColors.error,
        icon: Icons.cloud_off_rounded,
        title: 'Backend non raggiungibile',
        subtitle: 'Impossibile contattare /system/status',
      );
    }

    final data = _data!;
    final status = (data['status'] ?? 'unknown').toString();
    final checks = (data['checks'] as Map<String, dynamic>?) ?? {};
    final env = (data['environment'] ?? '').toString();

    int ok = 0, errors = 0, warnings = 0;
    final issuesNames = <String>[];
    checks.forEach((name, value) {
      final s = (value is Map ? value['status'] : '').toString();
      switch (s) {
        case 'ok':
          ok++;
          break;
        case 'error':
          errors++;
          issuesNames.add(name);
          break;
        case 'warning':
          warnings++;
          issuesNames.add(name);
          break;
        // 'disabled' (es. redis non configurato): non conta come problema,
        // semplicemente non incluso nei totali ok/error/warning.
      }
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
        ? 'Sistema: $errors servizi giù'
        : (warnings > 0
            ? 'Sistema: $warnings warning'
            : 'Sistema: tutto OK');
    final subtitle = errors > 0 || warnings > 0
        ? 'Problemi: ${issuesNames.join(", ")} • $ok/$total servizi OK'
        : '$ok/$total servizi OK${env.isNotEmpty ? " • $env" : ""}';

    return _bannerShell(
      color: color,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: widget.onTap,
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
