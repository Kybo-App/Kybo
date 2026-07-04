// Vista giornaliera della dieta con selezione porzioni, consumo pasti, swap e diario alimentare.
// _showSwapDialog — mostra le sostituzioni disponibili per un piatto tramite codice CAD.
// _showNoteDialog — apre il diario per annotare umore e note sul pasto.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/diet_provider.dart';
import '../widgets/meal_card.dart';
import '../models/active_swap.dart';
import '../models/pantry_item.dart';
import '../models/diet_models.dart';
import '../core/error_handler.dart';
import '../logic/diet_calculator.dart';
import '../widgets/design_system.dart';
import '../services/tracking_service.dart';
import '../models/tracking_models.dart';
import 'chat_screen.dart';

class DietView extends StatefulWidget {
  final String day;
  final DietPlan? dietPlan;
  final bool isLoading;
  final Map<String, ActiveSwap> activeSwaps;
  final List<PantryItem> pantryItems;
  final bool isTranquilMode;
  final VoidCallback? onUploadDiet;

  const DietView({
    super.key,
    required this.day,
    required this.dietPlan,
    required this.isLoading,
    required this.activeSwaps,
    required this.pantryItems,
    required this.isTranquilMode,
    this.onUploadDiet,
  });

  @override
  State<DietView> createState() => _DietViewState();
}

class _DietViewState extends State<DietView> {
  int _portionMultiplier = 1;

  bool _isToday(BuildContext context, String dayName) {
    final provider = context.read<DietProvider>();
    final days = provider.getDays();
    final now = DateTime.now();
    int index = now.weekday - 1;
    if (index >= 0 && index < days.length) {
      return days[index].toLowerCase() == dayName.toLowerCase();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentWeekPlan = context.read<DietProvider>().currentWeekPlan;

    if (widget.dietPlan == null || currentWeekPlan.isEmpty) {
      // [FIX DV1] Prima questo empty-state era cablato sul caso "utente con
      // nutrizionista" anche per gli utenti indipendenti: messaggio sbagliato
      // ("il tuo nutrizionista...") e CTA verso una chat non funzionante
      // (initializeChat esce subito senza parent_id, sendMessage no-op).
      final user = FirebaseAuth.instance.currentUser;
      return StreamBuilder<DocumentSnapshot>(
        stream: user == null
            ? null
            : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          bool hasNutritionist = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            hasNutritionist = ((data?['parent_id'] != null &&
                    (data?['parent_id'].toString().isNotEmpty ?? false)) ||
                (data?['nutritionist_id'] != null &&
                    (data?['nutritionist_id'].toString().isNotEmpty ?? false)) ||
                (data?['created_by'] != null &&
                    (data?['created_by'].toString().isNotEmpty ?? false)));
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined,
                      size: 64, color: KyboColors.textMuted(context)),
                  const SizedBox(height: 16),
                  Text(
                    "Nessuna dieta caricata",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: KyboColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasNutritionist
                        ? "Il tuo nutrizionista non ti ha ancora\ncaricato un piano alimentare."
                        : "Non hai ancora caricato un piano\nalimentare. Puoi caricarne uno tuo.",
                    style: TextStyle(
                        fontSize: 14, color: KyboColors.textSecondary(context)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: Icon(hasNutritionist
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.upload_file_rounded),
                    label: Text(hasNutritionist
                        ? 'Contatta il nutrizionista'
                        : 'Carica la tua dieta'),
                    style: FilledButton.styleFrom(
                      backgroundColor: KyboColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      if (hasNutritionist) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        );
                      } else {
                        widget.onUploadDiet?.call();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final mealsOfDay = currentWeekPlan[widget.day];

    if (mealsOfDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bed_outlined, size: 60, color: KyboColors.textMuted(context)),
            const SizedBox(height: 10),
            Text(
              "Riposo (nessun piano per ${widget.day})",
              style: TextStyle(color: KyboColors.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    final bool isCurrentDay = _isToday(context, widget.day);
    final provider = context.read<DietProvider>();
    final orderedMeals = provider.getMeals();

    final knownMeals = orderedMeals.where((m) => mealsOfDay.containsKey(m)).toList();
    final extraMeals = mealsOfDay.keys.where((m) => !orderedMeals.contains(m)).toList();
    final displayMeals = [...knownMeals, ...extraMeals];

    return Container(
      color: KyboColors.background(context),
      child: RefreshIndicator(
        onRefresh: () async => provider.refreshAvailability(),
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          children: [
            _buildPortionSelector(context),
            ...displayMeals.map((mealType) {
              return MealCard(
                day: widget.day,
                mealName: mealType,
                foods: mealsOfDay[mealType]!,
                activeSwaps: widget.activeSwaps,
                availabilityMap: context.watch<DietProvider>().availabilityMap,
                isTranquilMode: widget.isTranquilMode,
                isToday: isCurrentDay,
                isRelaxable: provider.isRelaxable,
                orderedMeals: orderedMeals,
                portionMultiplier: _portionMultiplier,
                onEat: (index) => _handleConsume(context, widget.day, mealType, index),
                onSwap: (key, cadCode) => _showSwapDialog(context, key, cadCode),
                onNote: () => _showNoteDialog(context, widget.day, mealType),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPortionSelector(BuildContext context) {
    const multipliers = [1, 2, 4, 6];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 16, color: KyboColors.textMuted(context)),
          const SizedBox(width: 8),
          Text(
            'Porzioni:',
            style: TextStyle(fontSize: 13, color: KyboColors.textMuted(context)),
          ),
          const SizedBox(width: 10),
          ...multipliers.map((m) {
            final selected = _portionMultiplier == m;
            return GestureDetector(
              onTap: () => setState(() => _portionMultiplier = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? KyboColors.primary : KyboColors.surface(context),
                  borderRadius: KyboBorderRadius.pill,
                  border: Border.all(
                    color: selected ? KyboColors.primary : KyboColors.border(context),
                  ),
                ),
                child: Text(
                  '×$m',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : KyboColors.textSecondary(context),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _handleConsume(
    BuildContext context,
    String day,
    String mealType,
    int index,
  ) async {
    final provider = context.read<DietProvider>();
    try {
      await provider.consumeMeal(day, mealType, index);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pasto consumato!"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      if (e is UnitMismatchException) {
        _showConversionDialog(context, provider, e);
      } else if (e is IngredientException) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: KyboColors.surface(context),
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: Text(
              "Ingrediente Mancante",
              style: TextStyle(color: KyboColors.textPrimary(context)),
            ),
            content: Text(
              "${e.message}\n\nVuoi segnarlo come consumato ugualmente?",
              style: TextStyle(color: KyboColors.textSecondary(context)),
            ),
            actions: [
              PillButton(
                label: "No",
                onPressed: () => Navigator.pop(ctx),
                backgroundColor: KyboColors.surface(context),
                textColor: KyboColors.textPrimary(context),
                height: 44,
              ),
              PillButton(
                label: "Sì, consuma",
                onPressed: () async {
                  Navigator.pop(ctx);
                  // [FIX DV4] Prima non veniva né atteso né gestito: un
                  // errore nel force-consume spariva in silenzio e non
                  // mostrava mai lo snackbar "Pasto consumato".
                  try {
                    await provider.consumeMeal(day, mealType, index, force: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Pasto consumato!"),
                          duration: Duration(seconds: 1),
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
                },
                backgroundColor: KyboColors.primary,
                textColor: Colors.white,
                height: 44,
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ErrorMapper.toUserMessage(e))));
      }
    }
  }

  void _showConversionDialog(
    BuildContext context,
    DietProvider provider,
    UnitMismatchException e,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          "Conversione Unità",
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "La dieta usa '${e.requiredUnit}' ma in dispensa hai '${e.item.unit}'.",
              style: TextStyle(color: KyboColors.textSecondary(context)),
            ),
            const SizedBox(height: 10),
            Text(
              "A quanti ${e.item.unit} corrisponde 1 ${e.requiredUnit}?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: KyboColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            PillTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              suffix: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(e.item.unit),
              ),
            ),
          ],
        ),
        actions: [
          PillButton(
            label: "Annulla",
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 44,
          ),
          PillButton(
            label: "Salva",
            onPressed: () {
              double? val = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              if (val != null && val > 0) {
                provider.resolveUnitMismatch(
                  e.item.name,
                  e.requiredUnit,
                  e.item.unit,
                  val,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Conversione salvata. Riprova a consumare."),
                  ),
                );
              }
            },
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
      // [FIX DV2] Controller di dialog mai disposato (pattern ricorrente
      // F6/SL1/ST5/P1).
    ).then((_) => controller.dispose());
  }

  void _showSwapDialog(BuildContext context, String swapKey, int cadCode) {
    final subs = widget.dietPlan?.substitutions;
    final String lookupCode = cadCode.toString();

    if (subs == null ||
        !subs.containsKey(lookupCode) ||
        subs[lookupCode]!.options.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: KyboColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          title: Text(
            "Nessuna Sostituzione",
            style: TextStyle(color: KyboColors.textPrimary(context)),
          ),
          content: Text(
            "Il nutrizionista non ha indicato alternative per questo alimento.",
            style: TextStyle(color: KyboColors.textSecondary(context)),
          ),
          actions: [
            PillButton(
              label: "OK",
              onPressed: () => Navigator.pop(ctx),
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 44,
            ),
          ],
        ),
      );
      return;
    }

    final substitutionGroup = subs[lookupCode]!;
    final List<SubstitutionOption> options = substitutionGroup.options;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: KyboColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (ctx, idx) {
                    final opt = options[idx];
                    return PillListTile(
                      title: opt.name,
                      subtitle: opt.qty,
                      leading: Icon(Icons.swap_horiz, color: KyboColors.warning),
                      onTap: () {
                        final newSwap = ActiveSwap(
                          name: opt.name,
                          qty: opt.qty,
                          unit: "",
                          swappedIngredients: [],
                        );
                        context.read<DietProvider>().swapMeal(swapKey, newSwap);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNoteDialog(BuildContext context, String day, String mealType) {
    final trackingService = TrackingService();
    final noteController = TextEditingController();
    String? selectedMood;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final noteId = '${today}_${day}_$mealType';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: KyboColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          title: Row(
            children: [
              Icon(Icons.edit_note, color: KyboColors.roleAdmin),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diario - $mealType',
                  style: TextStyle(color: KyboColors.textPrimary(context)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: noteController,
                maxLines: 3,
                maxLength: 500, // ep6.3: limite + contatore live nativo
                // [FIX DV3] Il "Salva" non faceva nulla in silenzio a testo
                // vuoto, senza essere disabilitato.
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  hintText: 'Come ti sei sentito? Cosa hai mangiato?',
                  hintStyle: TextStyle(color: KyboColors.textMuted(context)),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Come stai?',
                style: TextStyle(color: KyboColors.textSecondary(context)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['😊', '😐', '😔'].map((emoji) {
                  final isSelected = selectedMood == emoji;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedMood = emoji),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? KyboColors.roleAdmin.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? KyboColors.roleAdmin
                              : KyboColors.border(context),
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            PillButton(
              label: 'Annulla',
              onPressed: () => Navigator.pop(ctx),
              backgroundColor: KyboColors.surface(context),
              textColor: KyboColors.textPrimary(context),
              height: 44,
            ),
            PillButton(
              label: 'Salva',
              onPressed: noteController.text.trim().isEmpty
                  ? null
                  : () async {
                      final note = MealNote(
                        id: noteId,
                        date: DateTime.now(),
                        day: day,
                        mealType: mealType,
                        note: noteController.text.trim(),
                        mood: selectedMood,
                      );
                      await trackingService.saveMealNote(note);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nota salvata! 📝')),
                        );
                      }
                    },
              backgroundColor: KyboColors.roleAdmin,
              textColor: Colors.white,
              height: 44,
            ),
          ],
        ),
      ),
      // [FIX DV2] Controller di dialog mai disposato (pattern ricorrente
      // F6/SL1/ST5/P1).
    ).then((_) => noteController.dispose());
  }
}
