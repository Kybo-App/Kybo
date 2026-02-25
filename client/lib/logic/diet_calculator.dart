// Calcolo disponibilità ingredienti e parsing unità per la dieta.
// calculateAvailabilityIsolate — simulazione frigo per i giorni futuri (eseguibile in Isolate).
// buildGroups — raggruppa piatti per header N/A; parseQty/parseUnit — parsing stringa quantità.
import 'package:kybo/constants.dart'
    show DietUnits, UnitConversions;
import 'package:kybo/models/pantry_item.dart';

class UnitMismatchException implements Exception {
  final PantryItem item;
  final String requiredUnit;
  UnitMismatchException({required this.item, required this.requiredUnit});
  @override
  String toString() => "Unità diverse: ${item.unit} vs $requiredUnit";
}

class IngredientException implements Exception {
  final String message;
  IngredientException(this.message);
  @override
  String toString() => message;
}

class DietCalculator {
  static Map<String, bool> calculateAvailabilityIsolate(
    Map<String, dynamic> payload,
  ) {
    final dietData = payload['dietData'] as Map<String, dynamic>;
    final pantryItemsRaw = payload['pantryItems'] as List<dynamic>;
    final activeSwapsRaw = payload['activeSwaps'] as Map<String, dynamic>;

    Map<String, double> simulatedFridge = {};
    for (var item in pantryItemsRaw) {
      String iName = item['name'].toString().trim().toLowerCase();
      double iQty = double.tryParse(item['quantity'].toString()) ?? 0.0;
      String iUnit = item['unit'].toString().toLowerCase();

      if (iUnit == 'kg' || iUnit == 'l') iQty *= 1000;
      if (iUnit == 'gr') iUnit = 'g';
      simulatedFridge[iName] = iQty;
    }

    Map<String, bool> newMap = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int todayIndex = today.weekday - 1;

    final List<String> daysToCheck = (payload['days'] as List<dynamic>?)?.cast<String>() ?? [];
    final List<String> mealsToCheck = (payload['meals'] as List<dynamic>?)?.cast<String>() ?? [];

    for (int d = 0; d < daysToCheck.length; d++) {
      String day = daysToCheck[d];

      if (d < todayIndex) continue;

      if (!dietData.containsKey(day)) continue;

      final mealsOfDay = dietData[day] as Map<String, dynamic>;

      for (var mType in mealsToCheck) {
        if (!mealsOfDay.containsKey(mType)) continue;
        List<dynamic> dishes = List.from(mealsOfDay[mType]);
        List<List<int>> groups = buildGroups(dishes);

        for (int gIdx = 0; gIdx < groups.length; gIdx++) {
          List<int> indices = groups[gIdx];
          if (indices.isEmpty) continue;

          bool isConsumed = false;
          if (dishes[indices[0]]['consumed'] == true) {
            isConsumed = true;
          }

          if (isConsumed) {
            for (int originalIdx in indices) {
              newMap["${day}_${mType}_$originalIdx"] = false;
            }
            continue;
          }

          final firstDish = dishes[indices[0]];
          final String? instanceId = firstDish['instance_id']?.toString();
          final int cadCode = firstDish['cad_code'] ?? 0;

          String swapKey = (instanceId != null && instanceId.isNotEmpty)
              ? "$day::$mType::$instanceId"
              : "$day::$mType::$cadCode";

          bool isSwapped = activeSwapsRaw.containsKey(swapKey);

          if (isSwapped) {
            final swapData = activeSwapsRaw[swapKey];
            List<dynamic> swapItems = [];
            if (swapData['swappedIngredients'] != null &&
                (swapData['swappedIngredients'] as List).isNotEmpty) {
              swapItems = swapData['swappedIngredients'];
            } else {
              swapItems = [
                {
                  'name': swapData['name'],
                  'qty': "${swapData['qty']} ${swapData['unit']}",
                },
              ];
            }

            bool groupCovered = true;
            for (var item in swapItems) {
              if (!_checkAndConsumeSimulated(item, simulatedFridge)) {
                groupCovered = false;
              }
            }
            for (int originalIdx in indices) {
              newMap["${day}_${mType}_$originalIdx"] = groupCovered;
            }
          } else {
            for (int i in indices) {
              final dish = dishes[i];
              bool isCovered = true;
              if ((dish['qty']?.toString() ?? "") != "N/A") {
                List<dynamic> itemsToCheck = [];
                if (dish['ingredients'] != null &&
                    (dish['ingredients'] as List).isNotEmpty) {
                  itemsToCheck = dish['ingredients'];
                } else {
                  itemsToCheck = [
                    {'name': dish['name'], 'qty': dish['qty']},
                  ];
                }
                for (var item in itemsToCheck) {
                  if (!_checkAndConsumeSimulated(item, simulatedFridge)) {
                    isCovered = false;
                  }
                }
              }
              newMap["${day}_${mType}_$i"] = isCovered;
            }
          }
        }
      }
    }
    return newMap;
  }

  static List<List<int>> buildGroups(List<dynamic> dishes) {
    List<List<int>> groups = [];
    List<int> currentGroupIndices = [];
    for (int i = 0; i < dishes.length; i++) {
      final d = dishes[i];
      String qty = d['qty']?.toString() ?? "";
      bool isHeader = (qty == "N/A");
      if (isHeader) {
        if (currentGroupIndices.isNotEmpty) {
          groups.add(List.from(currentGroupIndices));
        }
        currentGroupIndices = [i];
      } else {
        if (currentGroupIndices.isNotEmpty) {
          currentGroupIndices.add(i);
        } else {
          groups.add([i]);
        }
      }
    }
    if (currentGroupIndices.isNotEmpty) {
      groups.add(List.from(currentGroupIndices));
    }
    return groups;
  }

  static bool _checkAndConsumeSimulated(
    Map<String, dynamic> item,
    Map<String, double> fridge,
  ) {
    String iName = item['name'].toString().trim().toLowerCase();
    String iRawQty = item['qty'].toString().toLowerCase();
    double iQty = parseQty(iRawQty);

    if (iRawQty.contains('kg') ||
        (iRawQty.contains('l') && !iRawQty.contains('ml'))) {
      iQty *= UnitConversions.kgToGrams;
    }
    if (iRawQty.contains('vasetto')) iQty = UnitConversions.vasettoGrams;

    String? foundKey;
    for (var key in fridge.keys) {
      if (key.contains(iName) || iName.contains(key)) {
        foundKey = key;
        break;
      }
    }
    if (foundKey != null && fridge[foundKey]! > 0) {
      if (fridge[foundKey]! >= iQty) {
        fridge[foundKey] = fridge[foundKey]! - iQty;
        return true;
      } else {
        fridge[foundKey] = 0;
        return false;
      }
    }
    return false;
  }

  static double normalizeToGrams(double qty, String unit) {
    final u = unit.trim().toLowerCase();
    if (u == 'kg' || u == 'l') return qty * UnitConversions.kgToGrams;
    if (u == 'g' || u == 'ml' || u == 'mg' || u == 'gr' || u == 'grammi') {
      return qty;
    }
    if (u.contains('vasetto')) return qty * UnitConversions.vasettoGrams;
    if (u.contains('cucchiain')) return qty * UnitConversions.cucchiainoMl;
    if (u.contains('cucchiaio')) return qty * UnitConversions.cucchiaioMl;
    if (u.contains('tazza')) return qty * UnitConversions.tazzaMl;
    if (u.contains('bicchiere')) return qty * UnitConversions.bicchiereMl;
    return -1.0;
  }

  static double parseQty(String raw) {
    if (raw.toLowerCase().contains("q.b")) return 0.0;

    final regExp = RegExp(r'(\d+[.,]?\d*)');
    final match = regExp.firstMatch(raw);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1.0;
    }
    return 1.0;
  }

  static String parseUnit(String raw, String name) {
    String lower = raw.toLowerCase().trim();

    if (lower.contains(DietUnits.KG)) return DietUnits.KG;
    if (lower.contains('mg')) return 'mg';
    if (lower.contains(DietUnits.ML)) return DietUnits.ML;

    if (lower.contains(' ${DietUnits.LITER} ') ||
        lower.endsWith(' ${DietUnits.LITER}')) {
      return DietUnits.LITER;
    }

    if (RegExp(r'\b(g|gr)\b').hasMatch(lower)) return DietUnits.GRAMS;

    if (lower.contains(DietUnits.VASETTO)) return DietUnits.VASETTO;
    if (lower.contains(DietUnits.CUCCHIAINO)) return DietUnits.CUCCHIAINO;
    if (lower.contains(DietUnits.CUCCHIAIO)) return DietUnits.CUCCHIAIO;
    if (lower.contains(DietUnits.TAZZA)) return DietUnits.TAZZA;
    if (lower.contains(DietUnits.BICCHIERE)) return DietUnits.BICCHIERE;
    if (lower.contains(DietUnits.FETTE)) return DietUnits.FETTE;

    if (lower.contains('vasetti')) return DietUnits.VASETTO;
    if (lower.contains('cucchiai')) return DietUnits.CUCCHIAIO;
    if (lower.contains('grammi')) return DietUnits.GRAMS;

    return "";
  }
}
