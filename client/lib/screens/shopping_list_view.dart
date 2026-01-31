import 'package:flutter/material.dart';
import 'package:kybo/models/diet_models.dart';
import '../models/active_swap.dart';
import '../models/pantry_item.dart';
import '../constants.dart' show AppColors, italianDays, orderedMealTypes;
import '../logic/diet_calculator.dart';

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

class _ShoppingListViewState extends State<ShoppingListView> {
  final Set<String> _selectedMealKeys = {};

  List<String> _getOrderedDays() {
    int todayIndex = DateTime.now().weekday - 1;
    if (todayIndex < 0 || todayIndex > 6) todayIndex = 0;
    return [
      ...italianDays.sublist(todayIndex),
      ...italianDays.sublist(0, todayIndex),
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
              title: const Text("Genera Lista Spesa"),
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

                    mealNames.sort((a, b) {
                      int idxA = orderedMealTypes.indexOf(a);
                      int idxB = orderedMealTypes.indexOf(b);
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
                      leading: Checkbox(
                        value: areAllSelected,
                        activeColor: AppColors.primary,
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
                          color: i == 0 ? AppColors.primary : Colors.black87,
                        ),
                      ),
                      children: mealNames.map((meal) {
                        final key = "$day::$meal";
                        final isSelected = _selectedMealKeys.contains(key);
                        return CheckboxListTile(
                          title: Text(meal),
                          value: isSelected,
                          dense: true,
                          activeColor: AppColors.primary,
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annulla"),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    _generateListFromSelection();
                    Navigator.pop(context);
                  },
                  child: const Text("Importa"),
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
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasCheckedItems = widget.shoppingList.any((i) => i.startsWith("OK_"));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, size: 28, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text(
                    "Lista della Spesa",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

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
                            color: Colors.grey[300],
                          ),
                          const Text("Lista Vuota"),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.shoppingList.length,
                      itemBuilder: (context, index) {
                        String raw = widget.shoppingList[index];
                        bool isChecked = raw.startsWith("OK_");
                        String display = isChecked ? raw.substring(3) : raw;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Dismissible(
                            key: Key(raw + index.toString()),
                            onDismissed: (_) {
                              var list = List<String>.from(widget.shoppingList);
                              list.removeAt(index);
                              widget.onUpdateList(list);
                            },
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: Icon(Icons.delete, color: Colors.red[800]),
                            ),
                            child: CheckboxListTile(
                              value: isChecked,
                              activeColor: AppColors.primary,
                              checkColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              title: Text(
                                display,
                                style: TextStyle(
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isChecked
                                      ? Colors.grey
                                      : const Color(0xFF2D3436),
                                  fontWeight: isChecked
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                              ),
                              onChanged: (val) {
                                var list = List<String>.from(
                                  widget.shoppingList,
                                );
                                list[index] =
                                    val == true ? "OK_$display" : display;
                                widget.onUpdateList(list);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // FOOTER CON BOTTONI
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            hasCheckedItems ? AppColors.primary : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: hasCheckedItems ? _moveCheckedToPantry : null,
                      icon: const Icon(Icons.kitchen, color: Colors.white),
                      label: const Text(
                        "Sposta nel Frigo",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.accent),
                      ),
                      onPressed: _showImportDialog,
                      icon: const Icon(Icons.download, color: AppColors.accent),
                      label: const Text(
                        "Importa da Dieta",
                        style: TextStyle(color: AppColors.accent),
                      ),
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
