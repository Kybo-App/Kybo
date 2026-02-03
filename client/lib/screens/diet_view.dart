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

class DietView extends StatelessWidget {
  final String day;
  final DietPlan? dietPlan; // [FIX] Accetta l'oggetto DietPlan
  final bool isLoading;
  final Map<String, ActiveSwap> activeSwaps;
  // substitutions rimosso perché incluso in dietPlan
  final List<PantryItem> pantryItems;
  final bool isTranquilMode;

  const DietView({
    super.key,
    required this.day,
    required this.dietPlan, // [FIX] Aggiornato
    required this.isLoading,
    required this.activeSwaps,
    // substitutions rimosso
    required this.pantryItems,
    required this.isTranquilMode,
  });

  bool _isToday(BuildContext context, String dayName) {
    final provider = context.read<DietProvider>();
    final days = provider.getDays();
    final now = DateTime.now();
    int index = now.weekday - 1; // 0 = Monday
    if (index >= 0 && index < days.length) {
      return days[index].toLowerCase() == dayName.toLowerCase();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // [FIX] Controllo sull'oggetto e sulla mappa interna
    if (dietPlan == null || dietPlan!.plan.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 60, color: KyboColors.textMuted(context)),
            const SizedBox(height: 10),
            Text(
              "Nessuna dieta caricata.",
              style: TextStyle(color: KyboColors.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    // [FIX] Accesso tipizzato alla mappa plan
    final mealsOfDay = dietPlan!.plan[day];

    if (mealsOfDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bed_outlined, size: 60, color: KyboColors.textMuted(context)),
            const SizedBox(height: 10),
            Text(
              "Riposo (nessun piano per $day)",
              style: TextStyle(color: KyboColors.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    final bool isCurrentDay = _isToday(context, day);
    final provider = context.read<DietProvider>();
    final orderedMeals = provider.getMeals();
    // relaxableFoods rimosso qui, usiamo provider.isRelaxable direttamente nel MealCard

    // [FIX] Calcola la lista finale dei pasti da mostrare
    // 1. Pasti conosciuti (nell'ordine corretto) che esistono nel piano di oggi
    final knownMeals = orderedMeals.where((m) => mealsOfDay.containsKey(m)).toList();
    // 2. Pasti extra nel piano (non presenti in config)
    final extraMeals = mealsOfDay.keys.where((m) => !orderedMeals.contains(m)).toList();
    // 3. Unione
    final displayMeals = [...knownMeals, ...extraMeals];

    return Container(
      color: KyboColors.background(context),
      child: RefreshIndicator(
        onRefresh: () async => provider.refreshAvailability(),
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          children: displayMeals.map((mealType) {

            return MealCard(
              day: day,
              mealName: mealType,
              foods: mealsOfDay[mealType]!,
              activeSwaps: activeSwaps,
              availabilityMap: context.watch<DietProvider>().availabilityMap,
              isTranquilMode: isTranquilMode,
              isToday: isCurrentDay,
              isRelaxable: provider.isRelaxable, // [FIX] Callback intelligente
              orderedMeals: orderedMeals,
              onEat: (index) => _handleConsume(context, day, mealType, index),
              onSwap: (key, cadCode) => _showSwapDialog(context, key, cadCode),
              onEdit: (index, name, qty) => provider
                  .updateDietMeal(day, mealType, index, name, qty),
            );
          }).toList(),
        ),
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
                onPressed: () {
                  Navigator.pop(ctx);
                  provider.consumeMeal(day, mealType, index, force: true);
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
    // ... (Logica invariata, ma usa e.item che ora è typed se DietLogic è aggiornato)
    // Per sicurezza, assumiamo che DietLogic lanci l'eccezione corretta
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
    );
  }

  // [FIX] Logica Swap aggiornata per usare DietPlan (Oggetti) invece di Map
  void _showSwapDialog(BuildContext context, String swapKey, int cadCode) {
    // Accesso sicuro tramite dietPlan
    final subs = dietPlan?.substitutions;
    final String lookupCode = cadCode.toString();

    // Controllo esistenza sostituzioni
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

    // [FIX] Estrazione dati tipizzati
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
}
