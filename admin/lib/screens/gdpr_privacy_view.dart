import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';

// Vista GDPR privacy: dashboard retention, statistiche inattività e purge utenti.
// _executePurge — lancia purge reale o simulazione con dialog di conferma; _saveConfig — aggiorna la policy via API.
class GDPRPrivacyView extends StatefulWidget {
  const GDPRPrivacyView({super.key});

  @override
  State<GDPRPrivacyView> createState() => _GDPRPrivacyViewState();
}

class _GDPRPrivacyViewState extends State<GDPRPrivacyView> {
  final AdminRepository _repo = AdminRepository();

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _dashboard;

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
          SnackBar(
            content: Text(AppLocalizations.of(context).gdprConfigSaved),
            backgroundColor: KyboColors.success,
          ),
        );
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${AppLocalizations.of(context).error}: $e"),
            backgroundColor: KyboColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executePurge({String? targetUid}) async {
    final l10n = AppLocalizations.of(context);
    final isDryRun = _dryRun;
    final targetText = targetUid != null
        ? (l10n.locale.languageCode == 'it' ? "l'utente $targetUid" : "user $targetUid")
        : (l10n.locale.languageCode == 'it' ? "tutti gli utenti inattivi" : "all inactive users");

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
            Text(isDryRun ? l10n.gdprPurgeSimulation : l10n.gdprWarning),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.gdprPurgeBody(isDryRun, targetText)),
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
                    Expanded(
                      child: Text(
                        l10n.gdprIrreversible,
                        style: const TextStyle(
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
            child: Text(l10n.cancel),
          ),
          PillButton(
            label: isDryRun ? l10n.gdprSimulate : l10n.delete,
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
        final n = isDryRun
            ? (summary?['total_processed'] ?? 0)
            : (summary?['successful'] ?? 0);
        final message = isDryRun
            ? l10n.gdprSimulationDone(n is int ? n : (n as num).toInt())
            : l10n.gdprPurgeDone(n is int ? n : (n as num).toInt());

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
            content: Text("${l10n.error}: $e"),
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
              label: AppLocalizations.of(context).retry,
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
            _buildHeader(),
          const SizedBox(height: 24),

          _buildStatisticsSection(),
          const SizedBox(height: 24),

          _buildConfigurationSection(),
          const SizedBox(height: 24),

          _buildInactiveUsersSection(),
          const SizedBox(height: 24),

          _buildApproachingDeadlineSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
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
                  l10n.gdprTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: KyboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.gdprSubtitle,
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
            tooltip: l10n.refresh,
            onPressed: _loadDashboard,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final l10n = AppLocalizations.of(context);
    final stats = _dashboard?['statistics'] as Map<String, dynamic>? ?? {};
    final totalUsers = stats['total_users'] ?? 0;
    final inactiveCount = stats['inactive_users_count'] ?? 0;
    final approachingCount = stats['approaching_deadline_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gdprStatistics,
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
                title: l10n.gdprTotalUsers,
                value: totalUsers.toString(),
                icon: Icons.people_rounded,
                color: KyboColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: l10n.gdprInactiveUsers,
                value: inactiveCount.toString(),
                icon: Icons.person_off_rounded,
                color: inactiveCount > 0 ? KyboColors.warning : KyboColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: l10n.gdprApproaching,
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
    final l10n = AppLocalizations.of(context);
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
                l10n.gdprConfigTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: KyboColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gdprRetentionPeriod,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: KyboColors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.gdprRetentionPeriodSub,
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
                  l10n.locale.languageCode == 'it'
                      ? "$_retentionMonths mesi"
                      : "$_retentionMonths months",
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

          _buildToggleRow(
            title: l10n.gdprAutoRetention,
            subtitle: l10n.gdprAutoRetentionSub,
            value: _isEnabled,
            onChanged: (val) => setState(() => _isEnabled = val),
            activeColor: KyboColors.primary,
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            title: l10n.gdprDryRun,
            subtitle: l10n.gdprDryRunSub,
            value: _dryRun,
            onChanged: (val) => setState(() => _dryRun = val),
            activeColor: KyboColors.warning,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: l10n.gdprSaveConfig,
                  icon: Icons.save_rounded,
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  onPressed: _saveConfig,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  label: _dryRun ? l10n.gdprSimulatePurge : l10n.gdprRunPurge,
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
    final l10n = AppLocalizations.of(context);
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
              l10n.gdprInactiveListTitle(inactiveUsers.length),
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
              l10n.locale.languageCode == 'it'
                  ? "...e altri ${inactiveUsers.length - 10} utenti"
                  : "...and ${inactiveUsers.length - 10} more users",
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
    final l10n = AppLocalizations.of(context);
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
              l10n.gdprApproachingListTitle(approachingUsers.length),
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
    final l10n = AppLocalizations.of(context);
    // Mostriamo l'UID (codice univoco) al posto dell'email: la sezione GDPR
    // non deve esporre PII in chiaro agli operatori che la consultano.
    final uid = (user['uid'] ?? '').toString();
    final displayId = uid.isEmpty ? 'N/A' : uid;
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
                    displayId,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: KyboColors.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.gdprInactiveSubtitle(
                      daysInactive is int ? daysInactive : (daysInactive as num).toInt(),
                      deadline != null
                          ? DateFormat('dd/MM/yyyy').format(deadline)
                          : null,
                    ),
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
                tooltip: l10n.gdprDeleteUserTooltip,
                size: 32,
                onPressed: () => _executePurge(targetUid: user['uid']),
              ),
          ],
        ),
      ),
    );
  }
}
