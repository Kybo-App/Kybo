import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';

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
        msg = "Emergency maintenance, we are working for you";
      }
      await _repo.setMaintenanceStatus(value, message: msg);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
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
            title: const Text("Conferma Schedulazione"),
            content: Text(
              "Verrà inviata una notifica a TUTTI gli utenti che la manutenzione inizierà:\n\n${DateFormat('yyyy-MM-dd HH:mm').format(dateTime)}",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Annulla"),
              ),
              PillButton(
                label: "Conferma",
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
            const SnackBar(
              content: Text("Manutenzione Schedulata!"),
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
              content: Text("Error: $e"),
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
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: const Text("Annullare Schedulazione?"),
            content: const Text(
              "Questo rimuoverà la schedulazione. Se la manutenzione è attiva, gli utenti potranno accedere immediatamente.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("No"),
              ),
              PillButton(
                label: "Sì, Annulla",
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
            const SnackBar(content: Text("Schedulazione Annullata")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
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
        // ═══════════════════════════════════════════════════════════════════
        // STATUS CARD
        // ═══════════════════════════════════════════════════════════════════
        _buildStatusCard(),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════════════════════════
        // MANUAL OVERRIDE
        // ═══════════════════════════════════════════════════════════════════
        _buildManualOverrideCard(),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════════════════════════
        // SCHEDULE SECTION
        // ═══════════════════════════════════════════════════════════════════
        _buildScheduleSection(),
      ],
    );
  }

  Widget _buildStatusCard() {
    final isDown = _isEffectivelyDown;
    final color = isDown ? KyboColors.error : KyboColors.success;
    final icon = isDown ? Icons.lock_rounded : Icons.check_circle_rounded;
    final title = isDown ? "SISTEMA OFFLINE" : "SISTEMA ATTIVO";

    String subtitle;
    if (_manualMaintenance) {
      subtitle = "Override Manuale ATTIVO";
    } else if (isDown) {
      subtitle = "Schedulazione Attiva (Ora passata)";
    } else {
      subtitle = "Gli utenti possono accedere all'app";
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
                  "Override Manuale",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: KyboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Forza manutenzione immediata",
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Schedula Manutenzione",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: KyboColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Current Schedule
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
                        "Schedulato: ${DateFormat('EEE, d MMM - HH:mm').format(_scheduledDate!)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: KyboColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PillBadge(
                        label: _isEffectivelyDown ? "ATTIVO" : "IN ATTESA",
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
                  tooltip: "Annulla Schedulazione",
                  onPressed: _cancelSchedule,
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // New Schedule
        PillCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Nuova Schedulazione",
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
                          ? "Seleziona Data e Ora"
                          : "${DateFormat('dd/MM').format(_selectedDate!)} alle ${_selectedTime!.format(context)}",
                      icon: Icons.calendar_today_rounded,
                      onPressed: _pickDateTime,
                    ),
                  ),
                  const SizedBox(width: 16),
                  PillButton(
                    label: "Schedula",
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
