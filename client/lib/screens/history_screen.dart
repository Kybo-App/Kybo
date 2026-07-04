// Schermata cronologia: switch per categoria (Diete / Allenamenti).
// [DISABLED workout feature 2026-05-25] Sezione "Allenamenti" nascosta.
// La cronologia mostra solo le diete. Per riattivare il segmented switch,
// scommentare il SegmentedButton e il branch del Workouts qui sotto.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../providers/diet_provider.dart';
// [DISABLED workout feature 2026-05-25] import '../providers/workout_provider.dart';
import '../core/error_handler.dart';
import '../widgets/design_system.dart';
import '../widgets/skeleton_loaders.dart';

// [DISABLED workout feature 2026-05-25] enum _HistoryCategory { diets, workouts }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // [DISABLED workout feature 2026-05-25] _HistoryCategory _category = _HistoryCategory.diets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        title: Text(
          "Cronologia",
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        iconTheme: IconThemeData(color: KyboColors.textPrimary(context)),
      ),
      // [DISABLED workout feature 2026-05-25] Senza segmented button mostriamo
      // direttamente la lista diete. Quando ripristineremo workouts:
      // - Decommentare enum + _category + l'intero Column con SegmentedButton
      // - Sostituire il body con quella struttura
      body: const _DietsHistoryList(),
    );
  }
}

class _DietsHistoryList extends StatelessWidget {
  const _DietsHistoryList();

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestore.getDietHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonCardList();
        }
        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.error_outline,
            color: Colors.red,
            text: ErrorMapper.toUserMessage(snapshot.error!),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _EmptyState(
            icon: Icons.history,
            color: KyboColors.textMuted(context),
            text: "Nessuna dieta salvata nel cloud.",
          );
        }

        final diets = snapshot.data!;
        return ListView.builder(
          itemCount: diets.length,
          itemBuilder: (context, index) {
            final diet = diets[index];
            DateTime date = DateTime.now();
            if (diet['uploadedAt'] != null) {
              date = (diet['uploadedAt'] as dynamic).toDate();
            }
            final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);

            // [FIX FS1] Un item con decryption_failed veniva mostrato come
            // una dieta normale, e "Ripristina" passava dati privi di
            // 'plan'/'substitutions' a DietPlan.fromJson, rompendo il
            // ripristino. Mostralo come voce non ripristinabile ma comunque
            // eliminabile.
            final isCorrupted = diet['error'] == 'decryption_failed';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: KyboColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
              child: ListTile(
                leading: Icon(
                  isCorrupted ? Icons.error_outline : Icons.cloud_done,
                  color: isCorrupted ? KyboColors.error : KyboColors.primary,
                ),
                title: Text(
                  isCorrupted ? "Dieta non leggibile" : "Dieta del $dateStr",
                  style: TextStyle(color: KyboColors.textPrimary(context), fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isCorrupted
                      ? "Impossibile decifrare questa voce. Puoi solo eliminarla."
                      : "Tocca per ripristinare",
                  style: TextStyle(color: KyboColors.textSecondary(context)),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: KyboColors.error),
                  onPressed: () => _confirmDeleteDiet(context, firestore, diet, dateStr),
                ),
                onTap: isCorrupted ? null : () => _showRestoreDialog(context, diet, dateStr),
              ),
            );
          },
        );
      },
    );
  }

  void _showRestoreDialog(BuildContext context, Map<String, dynamic> diet, String dateStr) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          "Ripristina Dieta",
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        content: Text(
          "Vuoi sostituire la dieta attuale con questa versione salvata?",
          style: TextStyle(color: KyboColors.textSecondary(context)),
        ),
        actions: [
          PillButton(
            label: "Annulla",
            onPressed: () => Navigator.pop(c),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 44,
          ),
          PillButton(
            label: "Ripristina",
            onPressed: () {
              context.read<DietProvider>().loadHistoricalDiet(diet, diet['id']);
              Navigator.pop(c);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Dieta ripristinata con successo!"),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: KyboColors.success,
                  shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
                ),
              );
            },
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }

  /// [FIX HS1] Prima cancellava subito al tap, senza conferma (a differenza
  /// del Ripristina che ce l'ha) — un tap accidentale perdeva per sempre una
  /// dieta storica. Aggiunge anche un feedback di successo (HS2).
  Future<void> _confirmDeleteDiet(
    BuildContext context,
    FirestoreService firestore,
    Map<String, dynamic> diet,
    String dateStr,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          "Elimina Dieta",
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        content: Text(
          "Vuoi eliminare definitivamente la dieta del $dateStr? L'azione non è reversibile.",
          style: TextStyle(color: KyboColors.textSecondary(context)),
        ),
        actions: [
          PillButton(
            label: "Annulla",
            onPressed: () => Navigator.pop(c, false),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 44,
          ),
          PillButton(
            label: "Elimina",
            onPressed: () => Navigator.pop(c, true),
            backgroundColor: KyboColors.error,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await firestore.deleteDiet(diet['id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Dieta eliminata."),
            behavior: SnackBarBehavior.floating,
            backgroundColor: KyboColors.success,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMapper.toUserMessage(e))),
        );
      }
    }
  }
}

// [DISABLED workout feature 2026-05-25] Lista cronologia allenamenti
// nascosta dal segmented switch in HistoryScreen. Wrappata in block comment
// per evitare warning di tipo "WorkoutProvider non importato".
// Per riattivare: rimuovere il blocco /* */ qui sotto e ripristinare
// l'import in cima al file.
/*
class _WorkoutsHistoryList extends StatefulWidget {
  const _WorkoutsHistoryList();

  @override
  State<_WorkoutsHistoryList> createState() => _WorkoutsHistoryListState();
}

class _WorkoutsHistoryListState extends State<_WorkoutsHistoryList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<WorkoutProvider>().fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonCardList();
        }
        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.error_outline,
            color: Colors.red,
            text: ErrorMapper.toUserMessage(snapshot.error!),
          );
        }
        final workouts = snapshot.data ?? [];
        if (workouts.isEmpty) {
          return _EmptyState(
            icon: Icons.fitness_center,
            color: KyboColors.textMuted(context),
            text: "Nessuna scheda allenamento nello storico.",
          );
        }

        return ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final w = workouts[index];
            final assignedRaw = w['assigned_at'];
            DateTime? assigned;
            if (assignedRaw is String) {
              assigned = DateTime.tryParse(assignedRaw);
            }
            final dateStr = assigned != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(assigned)
                : '';
            final name = (w['plan_name'] ?? w['name'] ?? 'Scheda').toString();
            final days = w['days'] as List? ?? const [];

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: KyboColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
              child: ListTile(
                leading: Icon(Icons.fitness_center, color: KyboColors.accent),
                title: Text(
                  name,
                  style: TextStyle(
                    color: KyboColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  [
                    if (dateStr.isNotEmpty) 'Assegnata il $dateStr',
                    '${days.length} giorni',
                  ].join(' · '),
                  style: TextStyle(color: KyboColors.textSecondary(context)),
                ),
                onTap: () => _showWorkoutDetails(context, w),
              ),
            );
          },
        );
      },
    );
  }

  void _showWorkoutDetails(BuildContext context, Map<String, dynamic> w) {
    final name = (w['plan_name'] ?? w['name'] ?? 'Scheda').toString();
    final days = (w['days'] as List? ?? const []);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(name, style: TextStyle(color: KyboColors.textPrimary(context))),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: days.length,
            itemBuilder: (c, i) {
              final day = Map<String, dynamic>.from(days[i] as Map);
              final dayName = (day['day_name'] ?? 'Giorno ${i + 1}').toString();
              final exercises = day['exercises'] as List? ?? const [];
              return ExpansionTile(
                title: Text(
                  dayName,
                  style: TextStyle(color: KyboColors.textPrimary(context)),
                ),
                children: exercises.map<Widget>((e) {
                  final ex = Map<String, dynamic>.from(e as Map);
                  final name = (ex['name'] ?? '').toString();
                  final sets = ex['sets'];
                  final reps = ex['reps'];
                  final detail = [
                    if (sets != null) '$sets serie',
                    if (reps != null) '$reps ripetizioni',
                  ].join(' · ');
                  return ListTile(
                    dense: true,
                    title: Text(name, style: TextStyle(color: KyboColors.textPrimary(context))),
                    subtitle: detail.isEmpty
                        ? null
                        : Text(detail, style: TextStyle(color: KyboColors.textSecondary(context))),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          PillButton(
            label: "Chiudi",
            onPressed: () => Navigator.pop(c),
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }
}
*/

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: KyboColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}
