import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/diet_provider.dart';
import '../services/notification_service.dart';
import '../widgets/design_system.dart';

class MealReminderDialog extends StatefulWidget {
  const MealReminderDialog({super.key});

  @override
  State<MealReminderDialog> createState() => _MealReminderDialogState();
}

class _MealReminderDialogState extends State<MealReminderDialog> {
  // Fallback defaults if no diet loaded
  final Map<String, String> _fallbackDefaults = {
    'Colazione': '08:00',
    'Pranzo': '13:00',
    'Cena': '20:00',
    'Spuntino': '16:00',
  };

  Map<String, bool> _enabled = {};
  Map<String, TimeOfDay> _times = {};
  bool _isLoading = true;
  List<String> _availableMeals = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('meal_alarms');
    Map<String, String> currentAlarms = {};

    if (savedJson != null) {
      try {
        final decoded = jsonDecode(savedJson) as Map<String, dynamic>;
        decoded.forEach((k, v) => currentAlarms[k] = v.toString());
      } catch (_) {}
    }

    // Load available meals from Provider
    if (mounted) {
      final provider = Provider.of<DietProvider>(context, listen: false);
      _availableMeals = provider.getMeals();
    }

    // Map defaults to fill gaps
    // If we have dynamic meals, ensure we have a time for them (either saved or default)
    // If no dynamic meals (e.g. no diet), use fallback list
    if (_availableMeals.isEmpty) {
      _availableMeals = _fallbackDefaults.keys.toList();
    }

    // Config defaults logic
    // We try to provide sensible defaults based on meal name keywords
    TimeOfDay inferTime(String mealName) {
      final lower = mealName.toLowerCase();
      if (lower.contains('colazione')) return const TimeOfDay(hour: 8, minute: 0);
      if (lower.contains('pranzo')) return const TimeOfDay(hour: 13, minute: 0);
      if (lower.contains('cena')) return const TimeOfDay(hour: 20, minute: 0);
      if (lower.contains('merenda')) return const TimeOfDay(hour: 16, minute: 0);
      if (lower.contains('spuntino')) {
        // Morning snack vs afternoon? hard to guess, default to 11
        if (_times.containsKey('Colazione')) return const TimeOfDay(hour: 10, minute: 30);
        return const TimeOfDay(hour: 16, minute: 0);
      }
      return const TimeOfDay(hour: 12, minute: 0); // Generic default
    }

    setState(() {
      for (var meal in _availableMeals) {
        // Is it enabled?
        _enabled[meal] = currentAlarms.containsKey(meal);

        // What time?
        if (currentAlarms.containsKey(meal)) {
          final parts = currentAlarms[meal]!.split(':');
          if (parts.length == 2) {
             _times[meal] = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          } else {
             _times[meal] = inferTime(meal);
          }
        } else {
          // Check fallback defaults first
          if (_fallbackDefaults.containsKey(meal)) {
             final parts = _fallbackDefaults[meal]!.split(':');
             _times[meal] = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          } else {
             _times[meal] = inferTime(meal);
          }
        }
      }
      _isLoading = false;
    });

    // Request permissions (non-blocking in UI, but necessary)
    NotificationService().requestPermissions();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> toSave = {};

    for (var meal in _availableMeals) {
      if (_enabled[meal] == true && _times.containsKey(meal)) {
        final t = _times[meal]!;
        toSave[meal] = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
      }
    }

    await prefs.setString('meal_alarms', jsonEncode(toSave));

    if (mounted) {
      // Reschedule
      await context.read<DietProvider>().scheduleMealNotifications();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toSave.isEmpty
                  ? "Tutti i promemoria disattivati"
                  : "Salvati ${toSave.length} promemoria",
            ),
            backgroundColor: KyboColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AlertDialog(
      backgroundColor: KyboColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
      title: Row(
        children: [
          Icon(Icons.notifications_active, color: KyboColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "Promemoria Pasti",
              style: TextStyle(color: KyboColors.textPrimary(context), fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "Attiva gli interruttori e tocca l'orario per modificarlo.",
                  style: TextStyle(
                    color: KyboColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
              ),
              if (_availableMeals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Nessun pasto trovato nella dieta.",
                    style: TextStyle(color: KyboColors.textMuted(context)),
                  ),
                ),
              ..._availableMeals.map((meal) {
                final time = _times[meal] ?? const TimeOfDay(hour: 8, minute: 0);
                final isEnabled = _enabled[meal] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? KyboColors.primary.withValues(alpha: 0.05)
                        : KyboColors.surface(context),
                    borderRadius: KyboBorderRadius.medium,
                    border: Border.all(
                      color: isEnabled
                          ? KyboColors.primary.withValues(alpha: 0.2)
                          : KyboColors.border(context),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    leading: Switch(
                      value: isEnabled,
                      activeColor: KyboColors.primary,
                      onChanged: (val) {
                        setState(() => _enabled[meal] = val);
                      },
                    ),
                    title: Text(
                      meal,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isEnabled
                            ? KyboColors.primary
                            : KyboColors.textSecondary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: InkWell(
                      onTap: isEnabled
                          ? () async {
                              final p = await showTimePicker(
                                context: context,
                                initialTime: time,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: KyboColors.primary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (p != null) {
                                setState(() => _times[meal] = p);
                              }
                            }
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isEnabled ? KyboColors.primary : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                          style: TextStyle(
                            color: isEnabled ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [
        PillButton(
          label: "Annulla",
          onPressed: () => Navigator.pop(context),
          backgroundColor: KyboColors.surface(context),
          textColor: KyboColors.textPrimary(context),
          height: 40,
        ),
        PillButton(
          label: "Salva",
          onPressed: _saveSettings,
          backgroundColor: KyboColors.primary,
          textColor: Colors.white,
          height: 40,
        ),
      ],
    );
  }
}
