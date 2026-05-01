// Vista configurazione server: toggle manutenzione manuale, schedulazione programmata e sezione configurazione app.
// _initStream — ascolta Firestore config/global in real-time; _scheduleMaintenance — valida e salva data/ora.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';
import '../widgets/app_config_section.dart';

class ConfigView extends StatefulWidget {
  const ConfigView({super.key});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  final AdminRepository _repo = AdminRepository();

  bool _isLoading = true;
  bool _manualMaintenance = false;
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    FirebaseFirestore.instance
        .collection('config')
        .doc('global')
        .snapshots()
        .listen((snapshot) {
          if (mounted && snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            setState(() {
              _manualMaintenance = data['maintenance_mode'] ?? false;
              _isScheduled = data['is_scheduled'] ?? false;
              if (data['scheduled_maintenance_start'] != null) {
                _scheduledDate = DateTime.tryParse(
                  data['scheduled_maintenance_start'],
                );
              } else {
                _scheduledDate = null;
              }
              _isLoading = false;
            });
          }
        });
  }

  bool get _isEffectivelyDown {
    if (_manualMaintenance) return true;
    if (_isScheduled && _scheduledDate != null) {
      return DateTime.now().isAfter(_scheduledDate!);
    }
    return false;
  }

  Future<void> _toggleMaintenance(bool value) async {
    setState(() => _isLoading = true);
    try {
      String? msg;
      if (value == true) {
        // Messaggio mostrato agli utenti finali: lo lasciamo nella lingua
        // della UI dell'admin che lo ha attivato.
        if (mounted) {
          msg = AppLocalizations.of(context).configEmergencyMsg;
        }
      }
      await _repo.setMaintenanceStatus(value, message: msg);
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = date;
      _selectedTime = time;
    });
  }

  Future<void> _scheduleMaintenance() async {
    if (_selectedDate == null || _selectedTime == null) return;
    final l10n = AppLocalizations.of(context);

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: Text(l10n.configConfirmSchedule),
            content: Text(
              l10n.configScheduleBody(
                  DateFormat('yyyy-MM-dd HH:mm').format(dateTime)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              PillButton(
                label: l10n.confirm,
                backgroundColor: KyboColors.warning,
                textColor: Colors.white,
                height: 40,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await _repo.scheduleMaintenance(dateTime, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.configMaintenanceScheduled),
              backgroundColor: KyboColors.accent,
            ),
          );
          setState(() {
            _selectedDate = null;
            _selectedTime = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${l10n.error}: $e"),
              backgroundColor: KyboColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelSchedule() async {
    final l10n = AppLocalizations.of(context);
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: Text(l10n.configCancelScheduleTitle),
            content: Text(l10n.configCancelScheduleBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.no),
              ),
              PillButton(
                label: l10n.configCancelScheduleAction,
                backgroundColor: KyboColors.error,
                textColor: Colors.white,
                height: 40,
                onPressed: () => Navigator.pop(c, true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await _repo.cancelMaintenanceSchedule();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.configScheduleCancelled)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${l10n.error}: $e"),
              backgroundColor: KyboColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildStatusCard(),

        const SizedBox(height: 24),

        _buildManualOverrideCard(),

        const SizedBox(height: 24),

        _buildScheduleSection(),

        const SizedBox(height: 32),

        AppConfigSection(repo: _repo),
      ],
    );
  }

  Widget _buildStatusCard() {
    final l10n = AppLocalizations.of(context);
    final isDown = _isEffectivelyDown;
    final color = isDown ? KyboColors.error : KyboColors.success;
    final icon = isDown ? Icons.lock_rounded : Icons.check_circle_rounded;
    final title = isDown ? l10n.configSystemOffline : l10n.configSystemActive;

    String subtitle;
    if (_manualMaintenance) {
      subtitle = l10n.configManualOverrideActive;
    } else if (isDown) {
      subtitle = l10n.configScheduleActive;
    } else {
      subtitle = l10n.configUsersCanAccess;
    }

    return PillCard(
      padding: const EdgeInsets.all(24),
      backgroundColor: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualOverrideCard() {
    return PillCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: KyboColors.error.withValues(alpha: 0.1),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: KyboColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).configManualOverride,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: KyboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).configForceImmediate,
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _manualMaintenance,
            onChanged: _toggleMaintenance,
            activeThumbColor: KyboColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.configScheduleMaintenance,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: KyboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        if (_isScheduled && _scheduledDate != null)
          PillCard(
            padding: const EdgeInsets.all(20),
            backgroundColor: KyboColors.accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: KyboColors.accent.withValues(alpha: 0.15),
                    borderRadius: KyboBorderRadius.medium,
                  ),
                  child: const Icon(
                    Icons.timer_rounded,
                    color: KyboColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.configScheduledLabel(
                            DateFormat('EEE, d MMM - HH:mm')
                                .format(_scheduledDate!)),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: KyboColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PillBadge(
                        label: _isEffectivelyDown
                            ? l10n.configBadgeActive
                            : l10n.configBadgePending,
                        color: _isEffectivelyDown
                            ? KyboColors.error
                            : KyboColors.warning,
                        small: true,
                      ),
                    ],
                  ),
                ),
                PillIconButton(
                  icon: Icons.delete_rounded,
                  color: KyboColors.error,
                  tooltip: l10n.configCancelSchedule,
                  onPressed: _cancelSchedule,
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        PillCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.configNewSchedule,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: KyboColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: _selectedDate == null
                          ? l10n.configSelectDateTime
                          : l10n.configScheduledAt(
                              DateFormat('dd/MM').format(_selectedDate!),
                              _selectedTime!.format(context)),
                      icon: Icons.calendar_today_rounded,
                      onPressed: _pickDateTime,
                    ),
                  ),
                  const SizedBox(width: 16),
                  PillButton(
                    label: l10n.configScheduleCta,
                    icon: Icons.send_rounded,
                    backgroundColor: KyboColors.warning,
                    textColor: Colors.white,
                    onPressed: (_selectedDate != null && _selectedTime != null)
                        ? _scheduleMaintenance
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
