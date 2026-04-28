// Schermata admin per gestire schede allenamento (Personal Trainer / Admin).
// _loadPlans — carica tutte le schede create dal professionista.
// _createOrEditPlan — dialog per creare/modificare una scheda.
// _assignPlan — assegna scheda a un utente.
import 'package:flutter/material.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';

class WorkoutManagementView extends StatefulWidget {
  const WorkoutManagementView({super.key});

  @override
  State<WorkoutManagementView> createState() => _WorkoutManagementViewState();
}

class _WorkoutManagementViewState extends State<WorkoutManagementView> {
  final AdminRepository _repo = AdminRepository();

  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  // Nomi giorno preimpostati per velocizzare la creazione scheda: tipici split
  // usati dai personal trainer (push/pull/legs, upper/lower, ecc.).
  static const List<String> _dayPresets = [
    'Push', 'Pull', 'Gambe', 'Upper Body', 'Lower Body',
    'Full Body', 'Core', 'Cardio', 'Mobility', 'Riposo',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadClients();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getWorkoutPlans();
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(data['plans'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadClients() async {
    try {
      final raw = await _repo.getSecureUsersList();
      final clients = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((u) {
            final role = (u['role'] as String?) ?? '';
            return role == 'user' || role == 'client' || role == 'independent';
          })
          .toList();
      if (mounted) setState(() => _clients = clients);
    } catch (_) {
      // Fallback silenzioso: il PT potrà ancora digitare manualmente l'UID.
    }
  }

  void _showCreateEditDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final targetUidCtrl = TextEditingController(text: existing?['target_uid'] ?? '');

    // Parse existing days
    List<Map<String, dynamic>> days = [];
    if (existing?['days'] != null) {
      days = List<Map<String, dynamic>>.from(
        (existing!['days'] as List).map((d) => Map<String, dynamic>.from(d)),
      );
    }

    bool isSaving = false;
    bool isTemplate = (existing?['is_template'] as bool?) ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: KyboColors.surface,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: Row(
              children: [
                Icon(
                  existing == null ? Icons.add_circle_rounded : Icons.edit_rounded,
                  color: KyboColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  existing == null ? 'Nuova Scheda' : 'Modifica Scheda',
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PillTextField(
                      controller: nameCtrl,
                      hintText: 'Nome scheda (es. "Push Pull Legs")',
                      prefixIcon: Icons.fitness_center_rounded,
                    ),
                    const SizedBox(height: 12),
                    PillTextField(
                      controller: descCtrl,
                      hintText: 'Descrizione (opzionale)',
                      prefixIcon: Icons.description_rounded,
                    ),
                    const SizedBox(height: 12),
                    if (existing == null) ...[
                      // Toggle "Salva come template": se attivo, il piano non
                      // viene assegnato a nessuno e resta riutilizzabile.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTemplate
                              ? KyboColors.primary.withValues(alpha: 0.08)
                              : KyboColors.background,
                          borderRadius: KyboBorderRadius.medium,
                          border: Border.all(
                            color: isTemplate
                                ? KyboColors.primary
                                : KyboColors.border,
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            AppLocalizations.of(context).saveAsTemplate,
                            style: TextStyle(
                              color: KyboColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)
                                .saveAsTemplateSubtitle,
                            style: TextStyle(
                              color: KyboColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          value: isTemplate,
                          activeThumbColor: KyboColors.primary,
                          onChanged: (v) => setDialogState(() {
                            isTemplate = v;
                            if (v) targetUidCtrl.text = '';
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isTemplate && _clients.isNotEmpty)
                        _ClientPicker(
                          clients: _clients,
                          selectedUid: targetUidCtrl.text.isNotEmpty
                              ? targetUidCtrl.text
                              : null,
                          onSelected: (uid) {
                            setDialogState(() => targetUidCtrl.text = uid ?? '');
                          },
                        )
                      else if (!isTemplate)
                        PillTextField(
                          controller: targetUidCtrl,
                          hintText: 'UID utente (opzionale, assegna subito)',
                          prefixIcon: Icons.person_rounded,
                        ),
                      const SizedBox(height: 16),
                    ],

                    // Giorni / esercizi
                    Row(
                      children: [
                        Text(
                          'Giorni di allenamento',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: KyboColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        PillIconButton(
                          icon: Icons.add_rounded,
                          color: KyboColors.primary,
                          tooltip: 'Aggiungi giorno',
                          onPressed: () {
                            setDialogState(() {
                              days.add({
                                'day_name': 'Giorno ${days.length + 1}',
                                'exercises': <Map<String, dynamic>>[],
                                'notes': '',
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (days.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _dayPresets.map((p) => ActionChip(
                            label: Text(p, style: const TextStyle(fontSize: 12)),
                            onPressed: () {
                              setDialogState(() {
                                days.add({
                                  'day_name': p,
                                  'exercises': <Map<String, dynamic>>[],
                                  'notes': '',
                                });
                              });
                            },
                          )).toList(),
                        ),
                      ),

                    ...days.asMap().entries.map((entry) {
                      final dayIdx = entry.key;
                      final day = entry.value;
                      final dayNameCtrl = TextEditingController(
                          text: day['day_name'] ?? '');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KyboColors.background,
                          borderRadius: KyboBorderRadius.medium,
                          border: Border.all(color: KyboColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: dayNameCtrl,
                                    onChanged: (v) => day['day_name'] = v,
                                    style: TextStyle(
                                      color: KyboColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Nome giorno',
                                      hintStyle: TextStyle(
                                          color: KyboColors.textMuted),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                PillIconButton(
                                  icon: Icons.add_rounded,
                                  color: KyboColors.primary,
                                  tooltip: 'Aggiungi esercizio',
                                  size: 32,
                                  onPressed: () {
                                    setDialogState(() {
                                      (day['exercises'] as List).add({
                                        'name': '',
                                        'sets': 3,
                                        'reps': '10',
                                        'rest_seconds': 90,
                                        'notes': '',
                                        'order': (day['exercises'] as List).length,
                                      });
                                    });
                                  },
                                ),
                                PillIconButton(
                                  icon: Icons.delete_rounded,
                                  color: KyboColors.error,
                                  tooltip: 'Rimuovi giorno',
                                  size: 32,
                                  onPressed: () {
                                    setDialogState(() => days.removeAt(dayIdx));
                                  },
                                ),
                              ],
                            ),
                            ...(day['exercises'] as List)
                                .asMap()
                                .entries
                                .map((exEntry) {
                              final exIdx = exEntry.key;
                              final ex =
                                  Map<String, dynamic>.from(exEntry.value);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: KyboColors.primary
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${exIdx + 1}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: KyboColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 4,
                                          child: _miniField(
                                            value: ex['name'] ?? '',
                                            hint: 'Esercizio',
                                            onChanged: (v) {
                                              (day['exercises'] as List)[exIdx]
                                                  ['name'] = v;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: _miniField(
                                            value: '${ex['sets'] ?? 3}',
                                            hint: 'Set',
                                            onChanged: (v) {
                                              (day['exercises'] as List)[exIdx]
                                                  ['sets'] = int.tryParse(v) ?? 3;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: _miniField(
                                            value: ex['reps'] ?? '10',
                                            hint: 'Reps',
                                            onChanged: (v) {
                                              (day['exercises'] as List)[exIdx]
                                                  ['reps'] = v;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: _miniField(
                                            value: ex['weight_kg']?.toString() ?? '',
                                            hint: 'Kg',
                                            onChanged: (v) {
                                              final parsed = double.tryParse(v.replaceAll(',', '.'));
                                              (day['exercises'] as List)[exIdx]
                                                  ['weight_kg'] = parsed;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: _miniField(
                                            value: '${ex['rest_seconds'] ?? 90}',
                                            hint: 'Rest(s)',
                                            onChanged: (v) {
                                              (day['exercises'] as List)[exIdx]
                                                      ['rest_seconds'] =
                                                  int.tryParse(v) ?? 90;
                                            },
                                          ),
                                        ),
                                        PillIconButton(
                                          icon: Icons.close_rounded,
                                          color: KyboColors.error,
                                          size: 28,
                                          onPressed: () {
                                            setDialogState(() {
                                              (day['exercises'] as List)
                                                  .removeAt(exIdx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 32),
                                      child: _miniField(
                                        value: ex['notes'] ?? '',
                                        hint: 'Note / tecnica (opzionale)',
                                        onChanged: (v) {
                                          (day['exercises'] as List)[exIdx]
                                              ['notes'] = v;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annulla',
                    style: TextStyle(color: KyboColors.textSecondary)),
              ),
              PillButton(
                label: existing == null ? 'Crea' : 'Salva',
                icon: existing == null ? Icons.add : Icons.save,
                backgroundColor: KyboColors.primary,
                textColor: Colors.white,
                height: 40,
                isLoading: isSaving,
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nome obbligatorio')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          if (existing == null) {
                            await _repo.createWorkoutPlan(
                              name: name,
                              description: descCtrl.text.trim(),
                              days: days,
                              targetUid: targetUidCtrl.text.trim().isNotEmpty
                                  ? targetUidCtrl.text.trim()
                                  : null,
                              isTemplate: isTemplate,
                            );
                          } else {
                            await _repo.updateWorkoutPlan(
                              existing['id'],
                              name: name,
                              description: descCtrl.text.trim(),
                              days: days,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadPlans();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Errore: $e'),
                                backgroundColor: KyboColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _miniField({
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: onChanged,
      style: TextStyle(color: KyboColors.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: KyboColors.textMuted, fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: KyboColors.surface,
        border: OutlineInputBorder(
          borderRadius: KyboBorderRadius.small,
          borderSide: BorderSide(color: KyboColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KyboBorderRadius.small,
          borderSide: BorderSide(color: KyboColors.border),
        ),
      ),
    );
  }

  // Clona un template e lo assegna a un utente. Differisce da _assignPlan
  // perché crea un nuovo plan_doc, lasciando il template intatto.
  Future<void> _useTemplate(Map<String, dynamic> template) async {
    String? selectedUid;
    bool isAssigning = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: KyboColors.surface,
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          title: Row(
            children: [
              Icon(Icons.content_copy_rounded,
                  color: KyboColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(ctx).useTemplate,
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verrà creata una copia di "${template['name'] ?? 'template'}" '
                  'assegnata all\'utente selezionato. Il template originale '
                  'resta riutilizzabile.',
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (_clients.isNotEmpty)
                  _ClientPicker(
                    clients: _clients,
                    selectedUid: selectedUid,
                    onSelected: (uid) {
                      setDialogState(() => selectedUid = uid);
                    },
                  )
                else
                  Text(
                    'Nessun cliente disponibile.',
                    style: TextStyle(color: KyboColors.textMuted),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annulla',
                  style: TextStyle(color: KyboColors.textSecondary)),
            ),
            PillButton(
              label: AppLocalizations.of(ctx).cloneAndAssign,
              icon: Icons.check_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 40,
              isLoading: isAssigning,
              onPressed: isAssigning
                  ? null
                  : () async {
                      final uid = selectedUid;
                      if (uid == null || uid.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Seleziona un utente')),
                        );
                        return;
                      }
                      setDialogState(() => isAssigning = true);
                      try {
                        await _repo.cloneAndAssignWorkoutPlan(
                            template['id'], uid);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)
                                  .templateClonedOk),
                              backgroundColor: KyboColors.success,
                            ),
                          );
                        }
                        _loadPlans();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Errore: $e'),
                              backgroundColor: KyboColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isAssigning = false);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignPlan(Map<String, dynamic> plan) async {
    final uidCtrl = TextEditingController(
        text: (plan['target_uid'] as String?) ?? '');
    bool isAssigning = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: KyboColors.surface,
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          title: Row(
            children: [
              Icon(Icons.person_add_rounded, color: KyboColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Assegna scheda',
                style: TextStyle(
                  color: KyboColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${plan['name'] ?? 'Scheda'}" verrà assegnata all\'utente '
                  'indicato. Se la scheda era già assegnata a qualcun altro, '
                  'gli verrà rimossa dalla home.',
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (_clients.isNotEmpty)
                  _ClientPicker(
                    clients: _clients,
                    selectedUid: uidCtrl.text.isNotEmpty ? uidCtrl.text : null,
                    onSelected: (uid) {
                      setDialogState(() => uidCtrl.text = uid ?? '');
                    },
                  )
                else
                  PillTextField(
                    controller: uidCtrl,
                    hintText: 'UID utente destinatario',
                    prefixIcon: Icons.person_rounded,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annulla',
                  style: TextStyle(color: KyboColors.textSecondary)),
            ),
            PillButton(
              label: 'Assegna',
              icon: Icons.check_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 40,
              isLoading: isAssigning,
              onPressed: isAssigning
                  ? null
                  : () async {
                      final uid = uidCtrl.text.trim();
                      if (uid.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UID obbligatorio')),
                        );
                        return;
                      }
                      setDialogState(() => isAssigning = true);
                      try {
                        await _repo.assignWorkoutPlan(plan['id'], uid);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Scheda assegnata ✓'),
                              backgroundColor: KyboColors.success,
                            ),
                          );
                        }
                        _loadPlans();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Errore: $e'),
                              backgroundColor: KyboColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isAssigning = false);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePlan(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text('Elimina scheda',
            style: TextStyle(color: KyboColors.textPrimary)),
        content: Text('Vuoi eliminare "$name"? L\'azione è irreversibile.',
            style: TextStyle(color: KyboColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla',
                style: TextStyle(color: KyboColors.textSecondary)),
          ),
          PillButton(
            label: 'Elimina',
            icon: Icons.delete_rounded,
            backgroundColor: KyboColors.error,
            textColor: Colors.white,
            height: 36,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteWorkoutPlan(id);
        _loadPlans();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: KyboColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.fitness_center_rounded,
                color: KyboColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Gestione Schede Allenamento',
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            PillButton(
              label: 'Nuova Scheda',
              icon: Icons.add_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 40,
              onPressed: () => _showCreateEditDialog(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: KyboColors.primary))
              : _plans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center_rounded,
                              size: 56, color: KyboColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Nessuna scheda creata',
                            style: TextStyle(
                              fontSize: 16,
                              color: KyboColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crea la prima scheda allenamento',
                            style: TextStyle(
                              fontSize: 13,
                              color: KyboColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildPartitionedList(),
        ),
      ],
    );
  }

  // Lista partizionata: prima i template (riutilizzabili), poi le schede
  // assegnate o ancora non assegnate. Header per ogni sezione.
  Widget _buildPartitionedList() {
    final l10n = AppLocalizations.of(context);
    final templates = _plans.where((p) => p['is_template'] == true).toList();
    final assigned = _plans.where((p) => p['is_template'] != true).toList();
    return ListView(
      children: [
        if (templates.isNotEmpty) ...[
          _sectionHeader(l10n.templatesSection, templates.length,
              Icons.bookmark_rounded, KyboColors.accent),
          const SizedBox(height: 8),
          ...templates.map(_buildPlanRow),
          const SizedBox(height: 16),
        ],
        if (assigned.isNotEmpty) ...[
          _sectionHeader(l10n.plansSection, assigned.length,
              Icons.fitness_center_rounded, KyboColors.primary),
          const SizedBox(height: 8),
          ...assigned.map(_buildPlanRow),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRow(Map<String, dynamic> plan) {
    final isActive = plan['is_active'] ?? true;
    final isTemplate = plan['is_template'] == true;
    final days = plan['days'] as List? ?? [];
    final targetUid = plan['target_uid'] as String?;
    final totalExercises = days.fold<int>(
        0,
        (sum, day) =>
            sum + ((day['exercises'] as List?)?.length ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(
          color: !isActive
              ? KyboColors.error.withValues(alpha: 0.3)
              : isTemplate
                  ? KyboColors.accent.withValues(alpha: 0.4)
                  : KyboColors.border,
          width: isTemplate ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon (accent color per template)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isTemplate ? KyboColors.accent : KyboColors.primary)
                  .withValues(alpha: 0.1),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: Icon(
              isTemplate
                  ? Icons.bookmark_rounded
                  : Icons.fitness_center_rounded,
              color: isTemplate ? KyboColors.accent : KyboColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan['name'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: KyboColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isTemplate)
                      PillBadge(
                        label: AppLocalizations.of(context).templateBadge,
                        icon: Icons.bookmark_rounded,
                        color: KyboColors.accent,
                      ),
                    if (!isActive)
                      PillBadge(
                        label: 'Disattivata',
                        icon: Icons.visibility_off_rounded,
                        color: KyboColors.error,
                      ),
                  ],
                ),
                if (plan['description'] != null &&
                    (plan['description'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      plan['description'],
                      style: TextStyle(
                        fontSize: 13,
                        color: KyboColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today_rounded,
                      '${days.length} giorni',
                      KyboColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.fitness_center_rounded,
                      '$totalExercises esercizi',
                      KyboColors.accent,
                    ),
                    if (targetUid != null && targetUid.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.person_rounded,
                        'Assegnata',
                        KyboColors.success,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTemplate)
                PillIconButton(
                  icon: Icons.content_copy_rounded,
                  color: KyboColors.success,
                  tooltip: AppLocalizations.of(context).useTemplateTooltip,
                  onPressed: () => _useTemplate(plan),
                )
              else
                PillIconButton(
                  icon: Icons.person_add_rounded,
                  color: KyboColors.success,
                  tooltip: 'Assegna a utente',
                  onPressed: () => _assignPlan(plan),
                ),
              const SizedBox(width: 4),
              PillIconButton(
                icon: Icons.edit_rounded,
                color: KyboColors.primary,
                tooltip: 'Modifica',
                onPressed: () => _showCreateEditDialog(existing: plan),
              ),
              const SizedBox(width: 4),
              PillIconButton(
                icon: Icons.delete_rounded,
                color: KyboColors.error,
                tooltip: 'Elimina',
                onPressed: () =>
                    _deletePlan(plan['id'], plan['name'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientPicker extends StatelessWidget {
  final List<Map<String, dynamic>> clients;
  final String? selectedUid;
  final ValueChanged<String?> onSelected;

  const _ClientPicker({
    required this.clients,
    required this.selectedUid,
    required this.onSelected,
  });

  String _labelFor(Map<String, dynamic> u) {
    final f = (u['first_name'] as String?) ?? '';
    final l = (u['last_name'] as String?) ?? '';
    final email = (u['email'] as String?) ?? '';
    final full = '$f $l'.trim();
    return full.isNotEmpty ? '$full • $email' : email;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedUid?.isNotEmpty == true ? selectedUid : null,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.person_rounded, color: KyboColors.textMuted),
        hintText: 'Assegna subito a un cliente (opzionale)',
        filled: true,
        fillColor: KyboColors.background,
        border: OutlineInputBorder(
          borderRadius: KyboBorderRadius.pill,
          borderSide: BorderSide(color: KyboColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KyboBorderRadius.pill,
          borderSide: BorderSide(color: KyboColors.border),
        ),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('— Nessuna assegnazione —'),
        ),
        ...clients.map((u) => DropdownMenuItem<String>(
              value: u['uid'] as String?,
              child: Text(
                _labelFor(u),
                overflow: TextOverflow.ellipsis,
              ),
            )),
      ],
      onChanged: (v) => onSelected(v == '' ? null : v),
    );
  }
}
