import 'package:flutter/material.dart';
import 'package:kybo/models/diet_models.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../providers/diet_provider.dart';
import '../models/active_swap.dart';
import '../models/pantry_item.dart';
import '../widgets/design_system.dart';
import '../logic/diet_calculator.dart';
import '../services/badge_service.dart';
import '../services/pricing_service.dart';

class ShoppingListView extends StatefulWidget {
  final List<String> shoppingList;
  final DietPlan? dietPlan; // <--- CAMBIATO: da Map a DietPlan
  final Map<String, ActiveSwap> activeSwaps;
  final List<PantryItem> pantryItems;
  final Function(List<String>) onUpdateList;
  final Function(String name, double qty, String unit) onAddToPantry;

  const ShoppingListView({
    super.key,
    required this.shoppingList,
    required this.dietPlan, // <--- Aggiornato
    required this.activeSwaps,
    required this.pantryItems,
    required this.onUpdateList,
    required this.onAddToPantry,
  });

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

// Grocery category keywords for grouping
const _categoryKeywords = {
  'Frutta & Verdura': [
    // Frutta
    'mela', 'mele', 'pera', 'pere', 'banana', 'banane', 'arancia', 'arance',
    'limone', 'limoni', 'uva', 'fragola', 'fragole', 'kiwi', 'ananas',
    'mango', 'avocado', 'pesca', 'pesche', 'albicocca', 'albicocche',
    'ciliegia', 'ciliegie', 'cocomero', 'anguria', 'melone', 'lampone',
    'lamponi', 'mirtillo', 'mirtilli', 'fico', 'fichi', 'prugna', 'prugne',
    'susina', 'susine', 'melagrana', 'melograno', 'clementina', 'clementine',
    'mandarino', 'mandarini', 'pompelmo', 'nettarina', 'papaya', 'maracuja',
    'ribes', 'mora', 'more', 'castagna', 'castagne',
    // Verdura
    'pomodoro', 'pomodori', 'insalata', 'lattuga', 'spinaci', 'spinaco',
    'broccoli', 'broccolo', 'carota', 'carote', 'zucchina', 'zucchine',
    'melanzana', 'melanzane', 'peperone', 'peperoni', 'cipolla', 'cipolle',
    'aglio', 'patata', 'patate', 'cetriolo', 'cetrioli', 'rucola',
    'radicchio', 'zucca', 'bietola', 'bietole', 'porro', 'porri',
    'finocchio', 'finocchi', 'sedano', 'cavolfiore', 'cavolfiori',
    'cavolo', 'cavoli', 'carciofo', 'carciofi', 'fagiolino', 'fagiolini',
    'asparago', 'asparagi', 'scarola', 'indivia', 'rapanello', 'rapanelli',
    'barbabietola', 'mais', 'granoturco', 'crescione', 'catalogna',
    'cicoria', 'verza', 'crauti', 'daikon', 'topinambur', 'rapa', 'rape',
    'verdura', 'frutta',
  ],
  'Carne & Pesce': [
    'pollo', 'manzo', 'maiale', 'tacchino', 'vitello', 'agnello', 'coniglio',
    'salmone', 'tonno', 'merluzzo', 'branzino', 'orata', 'gambero', 'gamberi',
    'calamaro', 'polpo', 'vongole', 'cozze', 'sgombro', 'alici', 'baccalà',
    'pesce', 'carne', 'bistecca', 'filetto', 'prosciutto', 'bresaola',
    'mortadella', 'salame', 'speck', 'pancetta', 'wurstel', 'cotechino',
  ],
  'Latticini & Uova': [
    'latte', 'yogurt', 'formaggio', 'mozzarella', 'ricotta', 'parmigiano',
    'grana', 'burro', 'uovo', 'uova', 'panna', 'kefir', 'gorgonzola',
    'fontina', 'pecorino', 'feta', 'mascarpone', 'scamorza', 'provolone',
    'crescenza', 'stracchino',
  ],
  'Cereali & Pane': [
    'pane', 'pasta', 'riso', 'farro', 'quinoa', 'avena', 'orzo',
    'fette biscottate', 'crackers', 'cereali', 'farina', 'piadina',
    'tortilla', 'cous cous', 'polenta', 'miglio', 'gnocchi', 'grissini',
    'gallette', 'pan carré', 'focaccia',
  ],
  'Legumi': [
    'fagioli', 'ceci', 'lenticchie', 'piselli', 'soia', 'edamame', 'tofu',
    'lupini', 'fave', 'azuki',
  ],
  'Condimenti & Oli': [
    'olio', 'aceto', 'sale', 'pepe', 'spezie', 'erbe', 'salsa', 'maionese',
    'senape', 'ketchup', 'curcuma', 'paprika', 'origano', 'basilico',
    'rosmarino', 'timo', 'prezzemolo', 'menta', 'curry', 'zenzero',
    'cannella', 'noce moscata', 'dado', 'brodo',
  ],
  'Frutta Secca & Semi': [
    'mandorle', 'noci', 'nocciole', 'anacardi', 'pistacchi', 'semi',
    'tahini', 'burro di arachidi', 'arachidi', 'pinoli', 'uvetta', 'datteri',
  ],
  'Bevande': [
    'acqua', 'succo', 'tè', 'caffè', 'latte vegetale', 'tisana',
    'bevanda', 'infuso',
  ],
};

String _categorizeItem(String itemName) {
  final lower = itemName.toLowerCase();
  for (final entry in _categoryKeywords.entries) {
    if (entry.value.any((kw) => lower.contains(kw))) {
      return entry.key;
    }
  }
  return 'Altro';
}

class _ShoppingListViewState extends State<ShoppingListView> {
  final Set<String> _selectedMealKeys = {};
  bool _groupByCategory = false;

  // ─── Banner budget stimato ───────────────────────────────────────────────
  Widget _buildBudgetBanner(BuildContext context) {
    final provider = context.watch<DietProvider>();

    // Nessun articolo → non mostrare
    if (widget.shoppingList.isEmpty) return const SizedBox.shrink();

    final activeItems = widget.shoppingList
        .where((i) => !i.startsWith('OK_'))
        .toList();
    if (activeItems.isEmpty) return const SizedBox.shrink();

    final estimatedCost = PricingService.estimateTotalCost(activeItems);
    final budget = provider.weeklyBudget;
    final ratio = budget != null && budget > 0
        ? (estimatedCost / budget).clamp(0.0, 1.0)
        : null;
    final overBudget = budget != null && estimatedCost > budget;

    final Color barColor = overBudget
        ? KyboColors.error
        : ratio != null && ratio > 0.8
            ? KyboColors.warning
            : KyboColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: barColor.withValues(alpha: 0.08),
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: barColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.euro_rounded, color: barColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Spesa stimata: €${estimatedCost.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showBudgetDialog(context, provider),
                child: Row(
                  children: [
                    Text(
                      budget != null
                          ? 'Budget: €${budget.toStringAsFixed(0)}'
                          : 'Imposta budget',
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textMuted(context),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: KyboColors.textMuted(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: barColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 5,
              ),
            ),
            if (overBudget)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Superi il budget di €${(estimatedCost - budget).toStringAsFixed(2).replaceAll('.', ',')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: KyboColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ─── Dialog impostazione budget ──────────────────────────────────────────
  void _showBudgetDialog(BuildContext context, DietProvider provider) {
    final controller = TextEditingController(
      text: provider.weeklyBudget != null
          ? provider.weeklyBudget!.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KyboColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.euro_rounded,
                  color: KyboColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Budget Spesa',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imposta un budget settimanale per la spesa.\nKybo ti avviserà se la lista stimata lo supera.',
              style: TextStyle(
                color: KyboColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: KyboColors.textMuted(context)),
                prefixText: '€ ',
                prefixStyle: TextStyle(
                  color: KyboColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                border: OutlineInputBorder(
                  borderRadius: KyboBorderRadius.medium,
                  borderSide: BorderSide(color: KyboColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: KyboBorderRadius.medium,
                  borderSide:
                      const BorderSide(color: KyboColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (provider.weeklyBudget != null)
            TextButton(
              onPressed: () {
                provider.setWeeklyBudget(null);
                Navigator.pop(ctx);
              },
              child: Text(
                'Rimuovi',
                style: TextStyle(color: KyboColors.error),
              ),
            ),
          PillButton(
            label: 'Annulla',
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 40,
          ),
          PillButton(
            label: 'Salva',
            onPressed: () {
              final val = double.tryParse(
                  controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                provider.setWeeklyBudget(val);
              }
              Navigator.pop(ctx);
            },
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 40,
          ),
        ],
      ),
    );
  }

  Future<void> _shareList() async {
    if (widget.shoppingList.isEmpty) return;

    final lines = widget.shoppingList.map((item) {
      final display = item.startsWith('OK_') ? '✓ ${item.substring(3)}' : '• $item';
      return display;
    }).join('\n');

    final text = 'Lista della Spesa Kybo:\n\n$lines';
    await Share.share(text, subject: 'Lista della Spesa');

    if (mounted) {
      context.read<BadgeService>().onShoppingListShared();
    }
  }

  /// Restituisce i giorni dalla config della dieta usando il Provider per consistenza
  List<String> _getDays() {
    // [FIX] Usa la logica centralizzata del Provider (Global Config -> Diet Config -> Fallback)
    return context.read<DietProvider>().getDays();
  }

  /// Restituisce i pasti dalla config della dieta
  List<String> _getMeals() {
    return context.read<DietProvider>().getMeals();
  }

  List<String> _getOrderedDays() {
    final days = _getDays();
    int todayIndex = DateTime.now().weekday - 1;
    if (todayIndex < 0 || todayIndex >= days.length) todayIndex = 0;
    return [
      ...days.sublist(todayIndex),
      ...days.sublist(0, todayIndex),
    ];
  }

  void _showImportDialog() {
    if (widget.dietPlan == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Carica prima una dieta!")));
      return;
    }

    final orderedDays = _getOrderedDays();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: KyboColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
              title: Text(
                "Genera Lista Spesa",
                style: TextStyle(color: KyboColors.textPrimary(context)),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: orderedDays.length,
                  itemBuilder: (context, i) {
                    final day = orderedDays[i];
                    final dayPlan = widget.dietPlan!.plan[day];
                    if (dayPlan == null) return const SizedBox.shrink();

                    List<String> mealNames = dayPlan.keys.where((k) {
                      var foods = dayPlan[k];
                      return foods != null && foods.isNotEmpty;
                    }).toList();

                    // Ordina secondo i pasti dalla config dieta
                    final meals = _getMeals();
                    mealNames.sort((a, b) {
                      int idxA = meals.indexOf(a);
                      int idxB = meals.indexOf(b);
                      if (idxA == -1) idxA = 999;
                      if (idxB == -1) idxB = 999;
                      return idxA.compareTo(idxB);
                    });

                    if (mealNames.isEmpty) return const SizedBox.shrink();

                    final allDayKeys =
                        mealNames.map((m) => "$day::$m").toList();
                    bool areAllSelected = allDayKeys.every(
                      (k) => _selectedMealKeys.contains(k),
                    );

                    return ExpansionTile(
                      collapsedIconColor: KyboColors.textMuted(context),
                      iconColor: KyboColors.primary,
                      leading: Checkbox(
                        value: areAllSelected,
                        activeColor: KyboColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (bool? value) {
                          setStateDialog(() {
                            if (value == true) {
                              _selectedMealKeys.addAll(allDayKeys);
                            } else {
                              _selectedMealKeys.removeAll(allDayKeys);
                            }
                          });
                        },
                      ),
                      title: Text(
                        i == 0 ? "$day (Oggi)" : day,
                        style: TextStyle(
                          fontWeight:
                              i == 0 ? FontWeight.bold : FontWeight.normal,
                          color: i == 0 ? KyboColors.primary : KyboColors.textPrimary(context),
                        ),
                      ),
                      children: mealNames.map((meal) {
                        final key = "$day::$meal";
                        final isSelected = _selectedMealKeys.contains(key);
                        return CheckboxListTile(
                          title: Text(
                            meal,
                            style: TextStyle(color: KyboColors.textSecondary(context)),
                          ),
                          value: isSelected,
                          dense: true,
                          activeColor: KyboColors.primary,
                           checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.only(
                            left: 60,
                            right: 20,
                          ),
                          onChanged: (val) {
                            setStateDialog(() {
                              if (val == true) {
                                _selectedMealKeys.add(key);
                              } else {
                                _selectedMealKeys.remove(key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
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
                  label: "Importa",
                  onPressed: () {
                    _generateListFromSelection();
                    Navigator.pop(context);
                  },
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  height: 40,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Inserisci questo dentro _ShoppingListViewState

  void _generateListFromSelection() {
    if (widget.dietPlan == null) return;

    // Struttura: {'Nome Ingrediente': {'qty': 100.0, 'unit': 'g', 'meals': {'Lunedì::Pranzo', ...}}}
    final Map<String, Map<String, dynamic>> neededItems = {};

    try {
      for (String key in _selectedMealKeys) {
        var parts = key.split('::');
        if (parts.length < 2) continue;

        var day = parts[0];
        var meal = parts[1];
        final mealKey = "$day::$meal"; // Chiave unica per il pasto

        List<Dish>? foods = widget.dietPlan!.plan[day]?[meal];
        if (foods == null) continue;

        for (var dish in foods) {
          if (dish.isConsumed) continue;

          String swapKey = (dish.instanceId.isNotEmpty)
              ? "$day::$meal::${dish.instanceId}"
              : "$day::$meal::${dish.cadCode}";

          if (widget.activeSwaps.containsKey(swapKey)) {
            // --- LOGICA SWAP ---
            final swap = widget.activeSwaps[swapKey]!;
            if (swap.swappedIngredients != null &&
                swap.swappedIngredients!.isNotEmpty) {
              for (var ing in swap.swappedIngredients!) {
                String name = "";
                String qtyStr = "";

                if (ing is Map) {
                  name = ing['name']?.toString() ?? "";
                  qtyStr = ing['qty']?.toString() ?? "";
                } else {
                  name = ing.toString();
                }

                if (name.isNotEmpty) {
                  _addToAggregator(neededItems, name, qtyStr, mealKey);
                }
              }
            } else {
              // Swap semplice
              _addToAggregator(
                  neededItems, swap.name, "${swap.qty} ${swap.unit}", mealKey);
            }
          } else {
            // --- LOGICA PIATTO ORIGINALE ---
            if (dish.qty == "N/A") continue;

            // Mostra ingredienti se il piatto è composto O se ha ingredienti
            if (dish.isComposed || dish.ingredients.isNotEmpty) {
              for (var ing in dish.ingredients) {
                _addToAggregator(neededItems, ing.name, ing.qty, mealKey);
              }
            } else {
              _addToAggregator(neededItems, dish.name, dish.qty, mealKey);
            }
          }
        }
      }

      // Sottrai gli ingredienti già in dispensa
      _subtractPantryItems(neededItems);

      // Conversione finale per la lista (UI)
      List<String> result = neededItems.entries.map((e) {
        String name = e.key;
        double qty = e.value['qty'] ?? 0.0;
        String unit = e.value['unit'] ?? '';
        Set<String> meals = e.value['meals'] ?? <String>{};
        int mealCount = meals.length;

        // Formattazione pulita (100.0 -> 100)
        String qtyDisplay = qty.toStringAsFixed(1);
        if (qtyDisplay.endsWith(".0")) {
          qtyDisplay = qtyDisplay.substring(0, qtyDisplay.length - 2);
        }

        // Formato: "Nome (100 g) • 3 pasti"
        String mealInfo = mealCount > 1 ? " • $mealCount pasti" : "";
        return "$name ($qtyDisplay $unit)$mealInfo".trim();
      }).toList();

      result.sort();
      widget.onUpdateList(result);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aggiunti ${result.length} elementi!")),
      );

      setState(() {
        _selectedMealKeys.clear();
      });
    } catch (e, stack) {
      debugPrint("Errore ShoppingList: $e $stack");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore creazione lista.")),
      );
    }
  }

  void _addToAggregator(
    Map<String, Map<String, dynamic>> agg,
    String name,
    String qtyStr,
    String mealKey, // Chiave pasto (es. "Lunedì::Pranzo")
  ) {
    // Uso DietCalculator per parsing sicuro e standardizzato
    double qty = DietCalculator.parseQty(qtyStr);
    String unit = DietCalculator.parseUnit(qtyStr, name);

    String cleanName = name.trim();
    if (cleanName.isNotEmpty) {
      cleanName = "${cleanName[0].toUpperCase()}${cleanName.substring(1)}";
    }

    if (agg.containsKey(cleanName)) {
      agg[cleanName]!['qty'] += qty;

      // Aggiorna l'unità se quella salvata è generica o vuota
      String currentUnit = agg[cleanName]!['unit'];
      if ((currentUnit.isEmpty || currentUnit == 'pz') && unit.isNotEmpty) {
        agg[cleanName]!['unit'] = unit;
      }

      // Aggiungi il pasto al set (per contare i pasti unici)
      (agg[cleanName]!['meals'] as Set<String>).add(mealKey);
    } else {
      agg[cleanName] = {
        'qty': qty,
        'unit': unit,
        'meals': <String>{mealKey}, // Set per pasti unici
      };
    }
  }

  // [FIX] Sottrae dalla lista della spesa gli ingredienti già presenti in dispensa
  void _subtractPantryItems(Map<String, Map<String, dynamic>> neededItems) {
    for (var pantryItem in widget.pantryItems) {
      String pantryName = pantryItem.name.trim();
      if (pantryName.isNotEmpty) {
        pantryName = "${pantryName[0].toUpperCase()}${pantryName.substring(1)}";
      }

      if (neededItems.containsKey(pantryName)) {
        double neededQty = neededItems[pantryName]!['qty'] ?? 0.0;
        double pantryQty = pantryItem.quantity;

        // Sottrai la quantità in dispensa
        double remaining = neededQty - pantryQty;

        if (remaining <= 0) {
          // Abbiamo abbastanza in dispensa, rimuovi dalla lista
          neededItems.remove(pantryName);
        } else {
          // Aggiorna con la quantità rimanente da comprare
          neededItems[pantryName]!['qty'] = remaining;
        }
      }
    }
  }

  void _moveCheckedToPantry() {
    int count = 0;
    List<String> newList = [];
    for (String item in widget.shoppingList) {
      if (item.startsWith("OK_")) {
        String content = item.substring(3);
        // Rimuovi "• X pasti" prima del parsing
        content = content.replaceAll(RegExp(r'\s*•\s*\d+\s*past[io]$'), '');

        // Regex: "Nome (quantità unità)"
        final RegExp regExp = RegExp(
          r'^(.*?)\s*\((\d+(?:[.,]\d+)?)\s*([^)]*)\)$',
        );
        final match = regExp.firstMatch(content.trim());
        String name = content;
        double qty = 1.0;
        String unit = "pz";

        if (match != null) {
          name = match.group(1)?.trim() ?? content;
          String? qtyStr = match.group(2);
          String? unitStr = match.group(3);
          if (qtyStr != null) {
            qty = double.tryParse(qtyStr.replaceAll(',', '.')) ?? 1.0;
          }
          if (unitStr != null && unitStr.trim().isNotEmpty) {
            unit = unitStr.trim();
          }
        }
        widget.onAddToPantry(name, qty, unit);
        count++;
      } else {
        newList.add(item);
      }
    }

    if (count > 0) {
      widget.onUpdateList(newList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$count prodotti nel frigo!"),
          backgroundColor: KyboColors.primary,
        ),
      );
    }
  }

  Widget _buildListTile(String raw, int index) {
    bool isChecked = raw.startsWith("OK_");
    String display = isChecked ? raw.substring(3) : raw;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: KyboColors.border(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Dismissible(
        key: Key(raw + index.toString()),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          var list = List<String>.from(widget.shoppingList);
          list.removeAt(index);
          widget.onUpdateList(list);
        },
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [KyboColors.error, KyboColors.error.withValues(alpha: 0.8)],
            ),
            borderRadius: KyboBorderRadius.medium,
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: CheckboxListTile(
          value: isChecked,
          activeColor: KyboColors.primary,
          checkColor: Colors.white,
          checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            display,
            style: TextStyle(
              decoration: isChecked ? TextDecoration.lineThrough : null,
              color: isChecked ? KyboColors.textMuted(context) : KyboColors.textPrimary(context),
              fontWeight: isChecked ? FontWeight.normal : FontWeight.w500,
            ),
          ),
          onChanged: (val) {
            var list = List<String>.from(widget.shoppingList);
            list[index] = val == true ? "OK_$display" : display;
            widget.onUpdateList(list);
          },
        ),
      ),
    );
  }

  Widget _buildFlatList() {
    // Su tablet: 2 colonne affiancate
    if (KyboBreakpoints.isTablet(context)) {
      return _buildTwoColumnList(widget.shoppingList.asMap().entries.toList());
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.shoppingList.length,
      itemBuilder: (context, index) => _buildListTile(widget.shoppingList[index], index),
    );
  }

  /// Layout 2 colonne per tablet: divide gli item in colonna sinistra e destra
  Widget _buildTwoColumnList(List<MapEntry<int, String>> entries) {
    final leftItems = <MapEntry<int, String>>[];
    final rightItems = <MapEntry<int, String>>[];
    for (int i = 0; i < entries.length; i++) {
      if (i.isEven) {
        leftItems.add(entries[i]);
      } else {
        rightItems.add(entries[i]);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftItems
                  .map((e) => _buildListTile(e.value, e.key))
                  .toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: rightItems
                  .map((e) => _buildListTile(e.value, e.key))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    // Group items by category
    final Map<String, List<int>> groups = {};
    for (int i = 0; i < widget.shoppingList.length; i++) {
      final raw = widget.shoppingList[i];
      final display = raw.startsWith('OK_') ? raw.substring(3) : raw;
      final name = display.split('(').first.trim();
      final category = _categorizeItem(name);
      groups.putIfAbsent(category, () => []).add(i);
    }

    // Sort categories: "Altro" last
    final sortedCategories = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Altro') return 1;
        if (b == 'Altro') return -1;
        return a.compareTo(b);
      });

    final isTablet = KyboBreakpoints.isTablet(context);

    if (isTablet) {
      // Su tablet: 2 colonne di categorie affiancate
      final leftCats = <String>[];
      final rightCats = <String>[];
      for (int i = 0; i < sortedCategories.length; i++) {
        if (i.isEven) {
          leftCats.add(sortedCategories[i]);
        } else {
          rightCats.add(sortedCategories[i]);
        }
      }

      Widget buildCategoryColumn(List<String> cats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cats.map((category) {
          final indices = groups[category]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: KyboColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...indices.map((i) => _buildListTile(widget.shoppingList[i], i)),
            ],
          );
        }).toList(),
      );

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: buildCategoryColumn(leftCats)),
            const SizedBox(width: 12),
            Expanded(child: buildCategoryColumn(rightCats)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedCategories.length,
      itemBuilder: (context, catIndex) {
        final category = sortedCategories[catIndex];
        final indices = groups[category]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: catIndex == 0 ? 0 : 8, bottom: 6),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...indices.map((i) => _buildListTile(widget.shoppingList[i], i)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasCheckedItems = widget.shoppingList.any((i) => i.startsWith("OK_"));

    return Scaffold(
      backgroundColor: KyboColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KyboColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_cart, size: 24, color: KyboColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Lista della Spesa",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: KyboColors.textPrimary(context),
                      ),
                    ),
                  ),
                  // Group by category toggle
                  Tooltip(
                    message: _groupByCategory ? 'Vista lista' : 'Raggruppa per categoria',
                    child: IconButton(
                      icon: Icon(
                        _groupByCategory ? Icons.list_rounded : Icons.category_rounded,
                        color: _groupByCategory ? KyboColors.primary : KyboColors.textMuted(context),
                      ),
                      onPressed: () => setState(() => _groupByCategory = !_groupByCategory),
                    ),
                  ),
                  // Share button
                  if (widget.shoppingList.isNotEmpty)
                    Tooltip(
                      message: 'Condividi lista',
                      child: IconButton(
                        icon: Icon(Icons.share_rounded, color: KyboColors.textMuted(context)),
                        onPressed: _shareList,
                      ),
                    ),
                ],
              ),
            ),

            // BANNER BUDGET
            _buildBudgetBanner(context),

            // LISTA (Design Coerente con MealCard)
            Expanded(
              child: widget.shoppingList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt,
                            size: 60,
                            color: KyboColors.textMuted(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Lista Vuota",
                            style: TextStyle(
                              color: KyboColors.textSecondary(context),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _groupByCategory
                      ? _buildGroupedList()
                      : _buildFlatList(),
            ),

            // FOOTER CON BOTTONI
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KyboColors.surface(context),
                border: Border(top: BorderSide(color: KyboColors.border(context))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: "Sposta nel Frigo",
                      onPressed: hasCheckedItems ? _moveCheckedToPantry : null,
                      backgroundColor: hasCheckedItems ? KyboColors.primary : Colors.grey,
                      textColor: Colors.white,
                      icon: Icons.kitchen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: "Da Dieta",
                      onPressed: _showImportDialog,
                      backgroundColor: Colors.transparent,
                      textColor: KyboColors.primary,
                      icon: Icons.download,
                      borderColor: KyboColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
