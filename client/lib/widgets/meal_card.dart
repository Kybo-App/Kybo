import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/active_swap.dart';

class MealCard extends StatelessWidget {
  final String day;
  final String mealName;
  final List<dynamic> foods;
  final Map<String, ActiveSwap> activeSwaps;
  final Map<String, bool> availabilityMap;
  final bool isTranquilMode;
  final bool isToday;
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
    required this.onEat,
    required this.onSwap,
    required this.onEdit,
  });

  // Lista di alimenti "rilassabili" (Frutta e Verdura)
  static const Set<String> _relaxableFoods = {
    'mela',
    'mele',
    'pera',
    'pere',
    'banana',
    'banane',
    'arancia',
    'arance',
    'mandarino',
    'mandarini',
    'kiwi',
    'ananas',
    'fragola',
    'fragole',
    'ciliegia',
    'ciliegie',
    'albicocca',
    'albicocche',
    'pesca',
    'pesche',
    'anguria',
    'melone',
    'uva',
    'prugna',
    'prugne',
    'limone',
    'pompelmo',
    'frutti di bosco',
    'insalata',
    'lattuga',
    'rucola',
    'spinaci',
    'bieta',
    'zucchina',
    'zucchine',
    'melanzana',
    'melanzane',
    'peperone',
    'peperoni',
    'pomodoro',
    'pomodori',
    'carota',
    'carote',
    'sedano',
    'finocchio',
    'finocchi',
    'cetriolo',
    'cetrioli',
    'cavolfiore',
    'broccolo',
    'broccoli',
    'verza',
    'cime di rapa',
    'fagiolini',
    'verdura',
    'verdure',
    'minestrone',
    'passato di verdura',
    'ortaggi',
  };

  @override
  Widget build(BuildContext context) {
    bool allConsumed =
        foods.isNotEmpty && foods.every((f) => f['consumed'] == true);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Laterale Decorativa
              Container(
                width: 6,
                color: allConsumed ? Colors.grey[300] : AppColors.primary,
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
                                  ? Colors.grey
                                  : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (allConsumed)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.grey,
                              size: 20,
                            )
                          else
                            Icon(
                              Icons.restaurant,
                              color: Colors.grey[400],
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 0.5),

                    // Lista Piatti (Usiamo Column per evitare crash IntrinsicHeight)
                    Column(
                      children: List.generate(foods.length, (index) {
                        final food = foods[index];
                        final String name = food['name'].toString();
                        final String nameLower = name.toLowerCase();
                        final bool isConsumed = food['consumed'] == true;
                        final int cadCode = food['cad_code'] ?? 0;
                        final String swapKey = "${day}_${mealName}_$cadCode";

                        String availKey = "${day}_${mealName}_$index";
                        bool isAvailable = availabilityMap[availKey] ?? true;

                        // Controllo Ingredienti Composti
                        final List<dynamic>? ingredients = food['ingredients'];
                        final bool hasIngredients =
                            ingredients != null && ingredients.isNotEmpty;

                        // Logica Relax per il piatto principale
                        bool isRelaxableItem = _relaxableFoods.any(
                          (tag) => nameLower.contains(tag),
                        );

                        String qtyDisplay;
                        if (isTranquilMode && isRelaxableItem) {
                          qtyDisplay = "A piacere";
                        } else {
                          qtyDisplay =
                              "${food['qty'] ?? ''} ${food['unit'] ?? ''}"
                                  .trim();
                        }

                        return Container(
                          decoration: BoxDecoration(
                            border: index != foods.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[100]!,
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
                              crossAxisAlignment: CrossAxisAlignment
                                  .start, // Allinea in alto per liste lunghe
                              children: [
                                // Icona Stato (Centrata verticalmente rispetto alla prima riga)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    isConsumed
                                        ? Icons.check
                                        : (isAvailable
                                              ? Icons.check_circle
                                              : Icons.circle_outlined),
                                    color: isConsumed
                                        ? Colors.grey[300]
                                        : (isAvailable
                                              ? AppColors.primary
                                              : Colors.grey[400]),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Testi (Nome Piatto + Lista Ingredienti)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          decoration: isConsumed
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isConsumed
                                              ? Colors.grey
                                              : const Color(0xFF2D3436),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // [FIX] Se ci sono ingredienti, mostrali in lista. Altrimenti mostra qtà semplice.
                                      if (hasIngredients)
                                        ...ingredients.map((ing) {
                                          String iName = ing['name'].toString();
                                          String iQty = ing['qty'].toString();

                                          // Relax Mode anche per ingredienti interni
                                          bool iRelax = _relaxableFoods.any(
                                            (tag) => iName
                                                .toLowerCase()
                                                .contains(tag),
                                          );
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
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
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
                                                ? Colors.grey[400]
                                                : (qtyDisplay == "A piacere"
                                                      ? AppColors.primary
                                                      : Colors.grey[600]),
                                            fontSize: 13,
                                            fontStyle: qtyDisplay == "A piacere"
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Azioni (Swap e Consuma)
                                if (!isConsumed) ...[
                                  // Swap
                                  if (cadCode > 0)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.swap_horiz_rounded,
                                      ),
                                      color: Colors.grey[400],
                                      splashRadius: 20,
                                      constraints:
                                          const BoxConstraints(), // Riduce padding extra
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      onPressed: () => onSwap(swapKey, cadCode),
                                    ),

                                  // Consuma (Solo se è Oggi)
                                  if (isToday)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: InkWell(
                                        onTap: () => onEat(index),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
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
