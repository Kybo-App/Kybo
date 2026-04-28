// "La mia giornata" — dashboard operativa per nutrizionisti e PT.
// Mostra metriche giornaliere + lista clienti che richiedono attenzione
// (chat non lette, dieta scaduta, inattività >14gg). Stream real-time da
// Firestore. Le card cliccabili invocano onNavigate(navIndex) per saltare
// alla tab corrispondente (chat / utenti) tramite il dashboard parent.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../core/app_localizations.dart';
import '../providers/admin_notification_provider.dart';
import '../widgets/design_system.dart';

class MyDayView extends StatefulWidget {
  /// Callback per saltare a un'altra tab nav (passato dal dashboard).
  /// label='chat' → tab Chat; label='users' → tab Utenti.
  final void Function(String label)? onNavigateTo;

  const MyDayView({super.key, this.onNavigateTo});

  @override
  State<MyDayView> createState() => _MyDayViewState();
}

class _MyDayViewState extends State<MyDayView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userName = '';
  String _userRole = '';
  String _userId = '';
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
        _userId = user.uid;
        _userName = (data['first_name'] ?? '').toString();
        _userRole = (data['role'] ?? '').toString();
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

  // Query gli utenti del nutri/PT (parent_id == uid). Per admin: tutti
  // gli user/independent. Lo stream alimenta sia le metriche che la lista.
  Stream<QuerySnapshot<Map<String, dynamic>>> _clientsStream() {
    Query<Map<String, dynamic>> q = _firestore.collection('users');
    if (_userRole == 'admin') {
      q = q.where('role', whereIn: ['user', 'independent']);
    } else {
      q = q.where('parent_id', isEqualTo: _userId);
    }
    return q.snapshots();
  }

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
          _buildActionableList(l10n),
        ],
      ),
    );
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

  Widget _buildHeader(AppLocalizations l10n) {
    final now = DateTime.now();
    final isItalian = l10n.locale.languageCode == 'it';
    final days = isItalian ? _itDays : _enDays;
    final months = isItalian ? _itMonths : _enMonths;
    final today = isItalian
        ? '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}'
        : '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
    return Row(
      children: [
        Expanded(
          child: Column(
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
                today,
                style: TextStyle(
                  fontSize: 14,
                  color: KyboColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AppLocalizations l10n) {
    final notif = context.watch<AdminNotificationProvider>();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _clientsStream(),
      builder: (ctx, snap) {
        int inactive = 0;
        int expiringDiets = 0;
        if (snap.hasData) {
          final now = DateTime.now();
          for (final d in snap.data!.docs) {
            final data = d.data();
            final lastSeenRaw = data['last_seen'] ?? data['last_login'];
            if (lastSeenRaw != null) {
              final dt = DateTime.tryParse(lastSeenRaw.toString());
              if (dt != null && now.difference(dt).inDays >= 14) inactive++;
            }
            final lastDiet = data['last_diet_update'];
            DateTime? dietDt;
            if (lastDiet is Timestamp) dietDt = lastDiet.toDate();
            if (lastDiet is String) dietDt = DateTime.tryParse(lastDiet);
            if (dietDt != null && now.difference(dietDt).inDays >= 30) {
              expiringDiets++;
            }
          }
        }
        return Row(
          children: [
            Expanded(
              child: _ClickableStat(
                title: l10n.statUnreadChats,
                value: '${notif.unreadChats}',
                icon: Icons.chat_bubble_rounded,
                color: KyboColors.primary,
                onTap: () => widget.onNavigateTo?.call('chat'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ClickableStat(
                title: l10n.statExpiredDiets,
                value: '$expiringDiets',
                icon: Icons.timer_off_outlined,
                color: KyboColors.error,
                onTap: () => widget.onNavigateTo?.call('users'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ClickableStat(
                title: l10n.statInactiveClients,
                value: '$inactive',
                icon: Icons.person_off_outlined,
                color: KyboColors.warning,
                subtitle: l10n.statInactiveSubtitle,
                onTap: () => widget.onNavigateTo?.call('users'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionableList(AppLocalizations l10n) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _clientsStream(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final actionable = <Map<String, dynamic>>[];
        final now = DateTime.now();
        for (final d in snap.data!.docs) {
          final data = d.data();
          data['_uid'] = d.id;

          final reasons = <String>[];
          int priority = 0;

          // Dieta scaduta — priorità alta
          DateTime? dietDt;
          final lastDiet = data['last_diet_update'];
          if (lastDiet is Timestamp) dietDt = lastDiet.toDate();
          if (lastDiet is String) dietDt = DateTime.tryParse(lastDiet);
          if (dietDt != null && now.difference(dietDt).inDays >= 30) {
            reasons.add(l10n.reasonExpiredDiet);
            priority += 10;
          }

          // Inattivo
          final lastSeenRaw = data['last_seen'] ?? data['last_login'];
          if (lastSeenRaw != null) {
            final dt = DateTime.tryParse(lastSeenRaw.toString());
            if (dt != null && now.difference(dt).inDays >= 14) {
              reasons.add(l10n.reasonInactive(now.difference(dt).inDays));
              priority += 5;
            }
          } else {
            reasons.add(l10n.reasonNeverActive);
            priority += 3;
          }

          if (reasons.isNotEmpty) {
            data['_reasons'] = reasons;
            data['_priority'] = priority;
            actionable.add(data);
          }
        }
        actionable.sort((a, b) =>
            (b['_priority'] as int).compareTo(a['_priority'] as int));
        final top = actionable.take(8).toList();

        if (top.isEmpty) {
          return PillCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.celebration_rounded,
                    size: 48, color: KyboColors.success),
                const SizedBox(height: 12),
                Text(
                  l10n.allUnderControl,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: KyboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.noClientsAttention,
                  style: TextStyle(
                    fontSize: 13,
                    color: KyboColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                l10n.clientsToContact,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: KyboColors.textPrimary,
                ),
              ),
            ),
            ...top.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActionableUserRow(
                    user: u,
                    l10n: l10n,
                    onOpenChat: () => widget.onNavigateTo?.call('chat'),
                    onOpenUser: () => widget.onNavigateTo?.call('users'),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _ClickableStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ClickableStat({
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

class _ActionableUserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final AppLocalizations l10n;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenUser;

  const _ActionableUserRow({
    required this.user,
    required this.l10n,
    this.onOpenChat,
    this.onOpenUser,
  });

  @override
  Widget build(BuildContext context) {
    final name = "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim();
    final email = user['email'] ?? '';
    final reasons = (user['_reasons'] as List<String>? ?? []);
    final lastSeenRaw = user['last_seen'] ?? user['last_login'];
    String? lastSeenLabel;
    if (lastSeenRaw != null) {
      final dt = DateTime.tryParse(lastSeenRaw.toString());
      if (dt != null) {
        lastSeenLabel = timeago.format(dt,
            locale: l10n.locale.languageCode == 'it' ? 'it' : 'en');
      }
    }

    return PillCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KyboColors.primary.withValues(alpha: 0.12),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: KyboColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? email : name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: KyboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...reasons.map((r) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KyboColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            r,
                            style: TextStyle(
                              color: KyboColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )),
                    if (lastSeenLabel != null)
                      Text(
                        l10n.lastActivity(lastSeenLabel),
                        style: TextStyle(
                          color: KyboColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          PillIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            color: KyboColors.primary,
            tooltip: l10n.tooltipOpenChat,
            onPressed: onOpenChat,
            size: 36,
          ),
          const SizedBox(width: 4),
          PillIconButton(
            icon: Icons.person_rounded,
            color: KyboColors.accent,
            tooltip: l10n.tooltipOpenProfile,
            onPressed: onOpenUser,
            size: 36,
          ),
        ],
      ),
    );
  }
}
