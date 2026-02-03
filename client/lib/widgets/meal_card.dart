import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import '../models/active_swap.dart';
import '../models/diet_models.dart'; // [IMPORTANTE] Serve per capire cos'è un Dish

class MealCard extends StatelessWidget {
  final String day;
  final String mealName;
  final List<Dish> foods; // [FIX] Ora è tipizzato correttamente
  final Map<String, ActiveSwap> activeSwaps;
  final Map<String, bool> availabilityMap;
  final bool isTranquilMode;
  final bool isToday;
  final bool Function(String) isRelaxable; // Callback per check relaxable
  final List<String> orderedMeals; // Pasti ordinati dalla config dieta
  final Function(int) onEat;
  final Function(String, int) onSwap;
  final Function(int, String, String) onEdit;

  const MealCard({
    super.key,
    required this.day,
    required this.mealName,
    required this.foods,
    required this.activeSwaps,
    required this.availabilityMap,
    required this.isTranquilMode,
    required this.isToday,
    required this.isRelaxable,
    required this.orderedMeals,
    required this.onEat,
    required this.onSwap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // [FIX] Usa .isConsumed invece di ['consumed']
    bool allConsumed = foods.isNotEmpty && foods.every((f) => f.isConsumed);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.large,
        border: Border.all(
          color: KyboColors.border(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: KyboBorderRadius.large,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Laterale Decorativa
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: allConsumed 
                        ? [KyboColors.textMuted(context), KyboColors.textMuted(context)]
                        : [KyboColors.primary, KyboColors.primaryDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Contenuto Card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Pasto
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            mealName.toUpperCase(),
                            style: TextStyle(
                              color: allConsumed 
                                  ? KyboColors.textMuted(context) 
                                  : KyboColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (allConsumed)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: KyboColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle,
                                color: KyboColors.success,
                                size: 16,
                              ),
                            )
                          else
                            Icon(
                              Icons.restaurant,
                              color: KyboColors.textMuted(context),
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: KyboColors.border(context),
                    ),

                    // Lista Piatti
                    Column(
                      children: List.generate(foods.length, (index) {
                        final originalFood =
                            foods[index]; // Ora è un oggetto Dish
                        final int cadCode = originalFood.cadCode;
                        final String instanceId = originalFood.instanceId;

                        // Generazione chiave robusta
                        final String swapKey = (instanceId.isNotEmpty)
                            ? "$day::$mealName::$instanceId"
                            : "$day::$mealName::$cadCode";

                        // --- LOGICA SWAP ---
                        final bool isSwapped = activeSwaps.containsKey(swapKey);
                        final activeSwap =
                            isSwapped ? activeSwaps[swapKey] : null;

                        // Dati da visualizzare (Swap o Originale)
                        // [FIX] Usa .name e .qty invece di ['name']
                        final String displayName =
                            isSwapped ? activeSwap!.name : originalFood.name;

                        final String displayQtyRaw = isSwapped
                            ? "${activeSwap!.qty} ${activeSwap.unit}"
                            : originalFood
                                .qty; // originalFood.qty include già l'unità nel nuovo modello

                        final bool isConsumed = originalFood.isConsumed;

                        assert(
                          orderedMeals.contains(mealName),
                          '❌ BUG: Meal name "$mealName" non standardizzato! Controlla normalize_meal_name()',
                        );
                        String availKey = "${day}_${mealName}_$index";
                        bool isAvailable = availabilityMap[availKey] ?? false;

                        // Ingredienti
                        final List<Ingredient>? ingredients = isSwapped
                            ? null
                            : originalFood
                                .ingredients; // Ora è List<Ingredient>

                        final bool hasIngredients =
                            ingredients != null && ingredients.isNotEmpty;

                        // Mostra ingredienti solo se:
                        // - Ci sono 2+ ingredienti, OPPURE
                        // - C'è 1 ingrediente con nome diverso dal piatto
                        final bool shouldShowIngredients = hasIngredients &&
                            (ingredients.length > 1 ||
                                !ingredients.first.name
                                    .toLowerCase()
                                    .contains(displayName.toLowerCase()));

                        // Logica Relax
                        final String nameLower = displayName.toLowerCase();
                        bool isRelaxableItem = isRelaxable(displayName);

                        // Se abbiamo 1 ingrediente uguale al piatto, usa la sua qty
                        String effectiveQty = displayQtyRaw;
                        if (hasIngredients &&
                            !shouldShowIngredients &&
                            ingredients.first.qty.isNotEmpty) {
                          effectiveQty = ingredients.first.qty;
                        }

                        String qtyDisplay;
                        if (isTranquilMode && isRelaxableItem) {
                          qtyDisplay = "A piacere";
                        } else {
                          qtyDisplay = effectiveQty.trim();
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: isSwapped
                                ? KyboColors.warning.withValues(alpha: 0.08)
                                : null,
                            border: index != foods.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color: KyboColors.border(context),
                                      width: 0.5,
                                    ),
                                  )
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isConsumed
                                            ? KyboColors.success.withValues(alpha: 0.1)
                                            : (isAvailable
                                                ? KyboColors.primary.withValues(alpha: 0.1)
                                                : Colors.transparent),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isConsumed
                                            ? Icons.check_circle
                                            : (isAvailable
                                                ? Icons.check_circle_outline
                                                : Icons.circle_outlined),
                                        color: isConsumed
                                            ? KyboColors.success
                                            : (isAvailable
                                                ? KyboColors.primary
                                                : KyboColors.textMuted(context)),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),

                                // Testi
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                              child: Text(
                                                displayName,
                                                style: TextStyle(
                                                  decoration: isConsumed
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                  color: isConsumed
                                                      ? KyboColors.textMuted(context)
                                                      : (isSwapped
                                                          ? KyboColors.warning
                                                          : KyboColors.textPrimary(context)),
                                                  fontWeight: isSwapped
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Mostra ingredienti se rilevanti (non se è solo 1 uguale al piatto)
                                      if (shouldShowIngredients)
                                        ...ingredients.map((ing) {
                                          String iName = ing.name;
                                          String iQty = ing.qty;
                                          bool iRelax = isRelaxable(iName);
                                          if (isTranquilMode && iRelax) {
                                            iQty = "";
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            child: Text(
                                              "• $iName ${iQty.isNotEmpty ? '($iQty)' : ''}",
                                              style: TextStyle(
                                                color: isConsumed
                                                    ? KyboColors.textMuted(context)
                                                    : KyboColors.textSecondary(context),
                                                fontSize: 13,
                                              ),
                                            ),
                                          );
                                        })
                                      else
                                        Text(
                                          qtyDisplay,
                                          style: TextStyle(
                                            color: isConsumed
                                                ? KyboColors.textMuted(context)
                                                : (qtyDisplay == "A piacere"
                                                    ? KyboColors.primary
                                                    : KyboColors.textSecondary(context)),
                                            fontSize: 13,
                                            fontWeight: qtyDisplay == "A piacere"
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                            fontStyle: qtyDisplay == "A piacere"
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Azioni
                                if (!isConsumed) ...[
                                  // Swap
                                  if (cadCode > 0)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: isSwapped
                                            ? KyboColors.warning.withValues(alpha: 0.1)
                                            : KyboColors.surface(context),
                                        borderRadius: KyboBorderRadius.medium,
                                        border: Border.all(
                                          color: isSwapped
                                              ? KyboColors.warning
                                              : KyboColors.border(context),
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.swap_horiz,
                                          color: isSwapped
                                              ? KyboColors.warning
                                              : KyboColors.textMuted(context),
                                          size: 20,
                                        ),
                                        splashRadius: 20,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                        onPressed: () => onSwap(swapKey, cadCode),
                                      ),
                                    ),

                                  // Consuma
                                  if (isToday)
                                    InkWell(
                                      onTap: () => onEat(index),
                                      borderRadius: KyboBorderRadius.medium,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              KyboColors.primary,
                                              KyboColors.primaryDark,
                                            ],
                                          ),
                                          borderRadius: KyboBorderRadius.medium,
                                          boxShadow: [
                                            BoxShadow(
                                              color: KyboColors.primary.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
