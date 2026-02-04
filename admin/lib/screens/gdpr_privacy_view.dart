import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';

/// GDPR Privacy & Retention Policy Management View
/// Admin-only section for managing data retention and GDPR compliance
class GDPRPrivacyView extends StatefulWidget {
  const GDPRPrivacyView({super.key});

  @override
  State<GDPRPrivacyView> createState() => _GDPRPrivacyViewState();
}

class _GDPRPrivacyViewState extends State<GDPRPrivacyView> {
  final AdminRepository _repo = AdminRepository();

  bool _isLoading = true;
  String? _error;

  // Dashboard data
  Map<String, dynamic>? _dashboard;

  // Config form
  int _retentionMonths = 24;
  bool _isEnabled = false;
  bool _dryRun = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dashboard = await _repo.getGDPRDashboard();
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          // Update form with current config
          final config = dashboard['config'] as Map<String, dynamic>?;
          if (config != null) {
            _retentionMonths = config['retention_months'] ?? 24;
            _isEnabled = config['is_enabled'] ?? false;
            _dryRun = config['dry_run'] ?? true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);

    try {
      await _repo.setRetentionConfig(
        retentionMonths: _retentionMonths,
        isEnabled: _isEnabled,
        dryRun: _dryRun,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Configurazione salvata"),
            backgroundColor: KyboColors.success,
          ),
        );
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executePurge({String? targetUid}) async {
    final isDryRun = _dryRun;
    final targetText = targetUid != null
        ? "l'utente $targetUid"
        : "tutti gli utenti inattivi";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Row(
          children: [
            Icon(
              isDryRun ? Icons.science_rounded : Icons.warning_amber_rounded,
              color: isDryRun ? KyboColors.accent : KyboColors.error,
            ),
            const SizedBox(width: 12),
            Text(isDryRun ? "Simulazione Purge" : "ATTENZIONE"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDryRun
                  ? "Verrà eseguita una SIMULAZIONE della purge per $targetText."
                  : "Stai per ELIMINARE PERMANENTEMENTE i dati di $targetText.",
            ),
            const SizedBox(height: 16),
            if (!isDryRun)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KyboColors.error.withValues(alpha: 0.1),
                  borderRadius: KyboBorderRadius.small,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: KyboColors.error),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Questa operazione è IRREVERSIBILE!",
                        style: TextStyle(
                          color: KyboColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          PillButton(
            label: isDryRun ? "Simula" : "Elimina",
            backgroundColor: isDryRun ? KyboColors.accent : KyboColors.error,
            textColor: Colors.white,
            height: 40,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await _repo.purgeInactiveUsers(
        dryRun: isDryRun,
        targetUid: targetUid,
      );

      if (mounted) {
        final summary = result['summary'] as Map<String, dynamic>?;
        final message = isDryRun
            ? "Simulazione completata: ${summary?['total_processed'] ?? 0} utenti processati"
            : "Purge completato: ${summary?['successful'] ?? 0} utenti eliminati";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: KyboColors.success,
          ),
        );
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: KyboColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: KyboColors.textSecondary)),
            const SizedBox(height: 16),
            PillButton(
              label: "Riprova",
              icon: Icons.refresh,
              onPressed: _loadDashboard,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 24),

          // Statistics Cards
          _buildStatisticsSection(),
          const SizedBox(height: 24),

          // Configuration Section
          _buildConfigurationSection(),
          const SizedBox(height: 24),

          // Inactive Users List
          _buildInactiveUsersSection(),
          const SizedBox(height: 24),

          // Approaching Deadline Section
          _buildApproachingDeadlineSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return PillCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: KyboColors.roleAdmin.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: KyboColors.roleAdmin.withValues(alpha: 0.15),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: const Icon(
              Icons.security_rounded,
              color: KyboColors.roleAdmin,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GDPR & Privacy",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: KyboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Gestione retention policy e conformità GDPR",
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PillIconButton(
            icon: Icons.refresh_rounded,
            tooltip: "Aggiorna",
            onPressed: _loadDashboard,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final stats = _dashboard?['statistics'] as Map<String, dynamic>? ?? {};
    final totalUsers = stats['total_users'] ?? 0;
    final inactiveCount = stats['inactive_users_count'] ?? 0;
    final approachingCount = stats['approaching_deadline_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Statistiche",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: KyboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: "Utenti Totali",
                value: totalUsers.toString(),
                icon: Icons.people_rounded,
                color: KyboColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: "Inattivi",
                value: inactiveCount.toString(),
                icon: Icons.person_off_rounded,
                color: inactiveCount > 0 ? KyboColors.warning : KyboColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: "In Scadenza",
                value: approachingCount.toString(),
                icon: Icons.timer_rounded,
                color: approachingCount > 0 ? KyboColors.error : KyboColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigurationSection() {
    return PillCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, color: KyboColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                "Configurazione Retention",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: KyboColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Retention months slider
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Periodo di Retention",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: KyboColors.textPrimary,
                      ),
                    ),
                    Text(
                      "Mesi di inattività prima della purge",
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  borderRadius: KyboBorderRadius.small,
                ),
                child: Text(
                  "$_retentionMonths mesi",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: KyboColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _retentionMonths.toDouble(),
            min: 6,
            max: 120,
            divisions: 19,
            activeColor: KyboColors.primary,
            onChanged: (value) {
              setState(() => _retentionMonths = value.round());
            },
          ),
          const SizedBox(height: 16),

          // Toggles
          _buildToggleRow(
            title: "Retention Automatica",
            subtitle: "Abilita purge automatica degli utenti inattivi",
            value: _isEnabled,
            onChanged: (val) => setState(() => _isEnabled = val),
            activeColor: KyboColors.primary,
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            title: "Modalità Dry Run",
            subtitle: "Simula le operazioni senza eliminare dati",
            value: _dryRun,
            onChanged: (val) => setState(() => _dryRun = val),
            activeColor: KyboColors.warning,
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: "Salva Configurazione",
                  icon: Icons.save_rounded,
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  onPressed: _saveConfig,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  label: _dryRun ? "Simula Purge" : "Esegui Purge",
                  icon: _dryRun ? Icons.science_rounded : Icons.delete_forever_rounded,
                  backgroundColor: _dryRun ? KyboColors.accent : KyboColors.error,
                  textColor: Colors.white,
                  onPressed: () => _executePurge(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: KyboColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: KyboColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: activeColor.withValues(alpha: 0.5),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return activeColor;
            }
            return null;
          }),
        ),
      ],
    );
  }

  Widget _buildInactiveUsersSection() {
    final inactiveUsers = _dashboard?['inactive_users'] as List<dynamic>? ?? [];

    if (inactiveUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_off_rounded, color: KyboColors.warning),
            const SizedBox(width: 8),
            Text(
              "Utenti Inattivi (${inactiveUsers.length})",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: KyboColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...inactiveUsers.take(10).map((user) => _buildUserTile(user, isInactive: true)),
        if (inactiveUsers.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "...e altri ${inactiveUsers.length - 10} utenti",
              style: TextStyle(
                color: KyboColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildApproachingDeadlineSection() {
    final approachingUsers = _dashboard?['approaching_deadline'] as List<dynamic>? ?? [];

    if (approachingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_rounded, color: KyboColors.error),
            const SizedBox(width: 8),
            Text(
              "Prossimi alla Scadenza (${approachingUsers.length})",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: KyboColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...approachingUsers.take(10).map((user) => _buildUserTile(user, isInactive: false)),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, {required bool isInactive}) {
    final email = user['email'] ?? 'N/A';
    final daysInactive = user['days_inactive'] ?? 0;
    final deadline = user['retention_deadline'] != null
        ? DateTime.tryParse(user['retention_deadline'])
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PillCard(
        padding: const EdgeInsets.all(12),
        backgroundColor: isInactive
            ? KyboColors.warning.withValues(alpha: 0.05)
            : KyboColors.error.withValues(alpha: 0.05),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isInactive
                  ? KyboColors.warning.withValues(alpha: 0.2)
                  : KyboColors.error.withValues(alpha: 0.2),
              child: Icon(
                Icons.person_rounded,
                color: isInactive ? KyboColors.warning : KyboColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: KyboColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Inattivo da $daysInactive giorni${deadline != null ? ' • Scadenza: ${DateFormat('dd/MM/yyyy').format(deadline)}' : ''}",
                    style: TextStyle(
                      fontSize: 12,
                      color: KyboColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (user['uid'] != null)
              PillIconButton(
                icon: Icons.delete_outline_rounded,
                color: KyboColors.error,
                tooltip: "Elimina utente",
                size: 32,
                onPressed: () => _executePurge(targetUid: user['uid']),
              ),
          ],
        ),
      ),
    );
  }
}
