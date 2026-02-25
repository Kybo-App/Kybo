// Card per la visualizzazione di un pasto giornaliero con supporto swap, consumo, note e modalità tranquilla.
// _scaleQty — moltiplica la parte numerica iniziale di una stringa quantità per il portionMultiplier.
import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import '../models/active_swap.dart';
import '../models/diet_models.dart';

class MealCard extends StatelessWidget {
  final String day;
  final String mealName;
  final List<Dish> foods;
  final Map<String, ActiveSwap> activeSwaps;
  final Map<String, bool> availabilityMap;
  final bool isTranquilMode;
  final bool isToday;
  final bool Function(String) isRelaxable;
  final List<String> orderedMeals;
  final Function(int) onEat;
  final Function(String, int) onSwap;
  final Function(int, String, String) onEdit;
  final VoidCallback? onNote;
  final String? currentNote;
  final int portionMultiplier;

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
    this.onNote,
    this.currentNote,
    this.portionMultiplier = 1,
  });

  static String _scaleQty(String qty, int multiplier) {
    if (multiplier == 1 || qty.isEmpty || qty == 'A piacere') return qty;
    final match = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(qty.trim());
    if (match == null) return qty;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null) return qty;
    final unit = match.group(2) ?? '';
    final scaled = value * multiplier;
    final formatted = scaled == scaled.roundToDouble()
        ? scaled.round().toString()
        : scaled.toStringAsFixed(1);
    return unit.isEmpty ? formatted : '$formatted $unit'.trim();
  }

  @override
  Widget build(BuildContext context) {
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

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            Row(
                              children: [
                                if (onNote != null)
                                  InkWell(
                                    onTap: onNote,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: currentNote != null
                                            ? Colors.purple.withValues(alpha: 0.1)
                                            : KyboColors.surface(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        currentNote != null
                                            ? Icons.edit_note
                                            : Icons.note_add_outlined,
                                        color: currentNote != null
                                            ? Colors.purple
                                            : KyboColors.textMuted(context),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.restaurant,
                                  color: KyboColors.textMuted(context),
                                  size: 18,
                                ),
                              ],
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

                    Column(
                      children: List.generate(foods.length, (index) {
                        final originalFood = foods[index];
                        final int cadCode = originalFood.cadCode;
                        final String instanceId = originalFood.instanceId;

                        final String swapKey = (instanceId.isNotEmpty)
                            ? "$day::$mealName::$instanceId"
                            : "$day::$mealName::$cadCode";

                        final bool isSwapped = activeSwaps.containsKey(swapKey);
                        final activeSwap =
                            isSwapped ? activeSwaps[swapKey] : null;

                        final String displayName =
                            isSwapped ? activeSwap!.name : originalFood.name;

                        final String displayQtyRaw = isSwapped
                            ? "${activeSwap!.qty} ${activeSwap.unit}"
                            : originalFood.qty;

                        final bool isConsumed = originalFood.isConsumed;

                        assert(
                          orderedMeals.contains(mealName),
                          '❌ BUG: Meal name "$mealName" non standardizzato! Controlla normalize_meal_name()',
                        );
                        String availKey = "${day}_${mealName}_$index";
                        bool isAvailable = availabilityMap[availKey] ?? false;

                        final List<Ingredient>? ingredients = isSwapped
                            ? null
                            : originalFood.ingredients;

                        final bool hasIngredients =
                            ingredients != null && ingredients.isNotEmpty;

                        final bool shouldShowIngredients = hasIngredients &&
                            (ingredients.length > 1 ||
                                !ingredients.first.name
                                    .toLowerCase()
                                    .contains(displayName.toLowerCase()));

                        bool isRelaxableItem = isRelaxable(displayName);

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
                          qtyDisplay = _scaleQty(effectiveQty.trim(), portionMultiplier);
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
                                      if (shouldShowIngredients)
                                        ...ingredients.map((ing) {
                                          String iName = ing.name;
                                          String iQty = ing.qty;
                                          bool iRelax = isRelaxable(iName);
                                          if (isTranquilMode && iRelax) {
                                            iQty = "";
                                          } else {
                                            iQty = _scaleQty(iQty, portionMultiplier);
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

                                if (!isConsumed) ...[
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
