// Dialog per configurare il promemoria allenamento (locale, ricorrente).
// Salva preferenze in SharedPreferences e (ri)schedula le notifiche
// settimanali tramite NotificationService.saveWorkoutReminder.

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/design_system.dart';

class WorkoutReminderDialog extends StatefulWidget {
  const WorkoutReminderDialog({super.key});

  @override
  State<WorkoutReminderDialog> createState() => _WorkoutReminderDialogState();
}

class _WorkoutReminderDialogState extends State<WorkoutReminderDialog> {
  final _service = NotificationService();
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  // Set di giorni selezionati: 1=Lun..7=Dom
  final Set<int> _selectedDays = {};
  bool _loading = true;
  bool _saving = false;

  static const _dayLabels = {
    1: 'L', 2: 'M', 3: 'M', 4: 'G', 5: 'V', 6: 'S', 7: 'D',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _service.loadWorkoutReminderPrefs();
    if (!mounted) return;
    final timeStr = prefs['time'] as String;
    final parts = timeStr.split(':');
    setState(() {
      _enabled = prefs['enabled'] as bool;
      _time = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 18,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
      _selectedDays.clear();
      for (final d in (prefs['days'] as List<String>)) {
        final i = int.tryParse(d);
        if (i != null && i >= 1 && i <= 7) _selectedDays.add(i);
      }
      _loading = false;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveWorkoutReminder(
        enabled: _enabled,
        time: _time,
        weekdays: _selectedDays.toList()..sort(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_enabled
              ? 'Promemoria salvato ✓'
              : 'Promemoria disattivato'),
          backgroundColor: KyboColors.primary,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KyboColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
      title: Row(
        children: [
          Icon(Icons.alarm_rounded, color: KyboColors.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            'Promemoria allenamento',
            style: TextStyle(
              color: KyboColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Attivo',
                      style: TextStyle(
                        color: KyboColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'Riceverai notifica nei giorni selezionati'
                          : 'Nessuna notifica',
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textMuted(context),
                      ),
                    ),
                    value: _enabled,
                    activeThumbColor: KyboColors.primary,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: _enabled,
                    leading: Icon(Icons.schedule_rounded,
                        color: KyboColors.primary),
                    title: Text(
                      'Orario',
                      style: TextStyle(
                          color: KyboColors.textPrimary(context),
                          fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _enabled
                            ? KyboColors.primary
                            : KyboColors.textMuted(context),
                      ),
                    ),
                    onTap: _enabled ? _pickTime : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Giorni',
                    style: TextStyle(
                      color: KyboColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final wd = i + 1;
                      final selected = _selectedDays.contains(wd);
                      return GestureDetector(
                        onTap: _enabled
                            ? () => setState(() {
                                  if (selected) {
                                    _selectedDays.remove(wd);
                                  } else {
                                    _selectedDays.add(wd);
                                  }
                                })
                            : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected && _enabled
                                ? KyboColors.primary
                                : KyboColors.background(context),
                            border: Border.all(
                              color: selected && _enabled
                                  ? KyboColors.primary
                                  : KyboColors.border(context),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _dayLabels[wd]!,
                              style: TextStyle(
                                color: selected && _enabled
                                    ? Colors.white
                                    : KyboColors.textSecondary(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Annulla',
              style: TextStyle(color: KyboColors.textSecondary(context))),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: KyboColors.primary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }
}
