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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
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
            if (createdDt != null && now.difference(createdDt).inDays < 7) {
              newSignups7d++;
            }
          }
        }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isItalian ? 'Attività recente' : 'Recent activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KyboColors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => widget.onNavigateTo?.call('audit'),
              child: Text(
                isItalian ? 'Log completo →' : 'Full log →',
                style: TextStyle(color: KyboColors.primary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('access_logs')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.data!.docs.isEmpty) {
              return PillCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    isItalian
                        ? 'Nessuna attività recente'
                        : 'No recent activity',
                    style: TextStyle(color: KyboColors.textMuted),
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
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PillCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                KyboColors.accent.withValues(alpha: 0.12),
                            borderRadius: KyboBorderRadius.medium,
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            size: 18,
                            color: KyboColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: KyboColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$actor • $whenLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: KyboColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
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

  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = StatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      subtitle: subtitle,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: KyboBorderRadius.large,
      child: card,
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
