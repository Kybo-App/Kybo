// Logica pura per la gestione della dieta: risoluzione ingredienti, validazione e consumo dalla dispensa.
// resolveIngredients — restituisce lista ingredienti da usare (swap attivo o piatto originale).
// validateItem — lancia eccezione se la dispensa non ha quantità sufficiente.
// consumeItem — sottrae la quantità dalla dispensa e rimuove l'item se esaurito.
import '../models/pantry_item.dart';
import '../models/active_swap.dart';
import 'diet_calculator.dart';
import '../models/diet_models.dart';

class DietLogic {
  /// Determina QUALI ingredienti consumare (Originali o Swap).
  static List<Map<String, String>> resolveIngredients({
    required Dish dish,
    required String day,
    required String mealType,
    required Map<String, ActiveSwap> activeSwaps,
  }) {
    final String instanceId = dish.instanceId;
    final int cadCode = dish.cadCode;

    String swapKey = (instanceId.isNotEmpty)
        ? "$day::$mealType::$instanceId"
        : "$day::$mealType::$cadCode";

    List<Map<String, String>> result = [];

    if (activeSwaps.containsKey(swapKey)) {
      final activeSwap = activeSwaps[swapKey]!;
      final List<dynamic> swapIngs = activeSwap.swappedIngredients ?? [];

      if (swapIngs.isNotEmpty) {
        for (var ing in swapIngs) {
          result.add({
            'name': ing['name'].toString(),
            'qty': ing['qty'].toString(),
          });
        }
      } else {
        result.add({
          'name': activeSwap.name,
          'qty': activeSwap.qty,
        });
      }
    } else {
      if (dish.isComposed || dish.ingredients.isNotEmpty) {
        for (var ing in dish.ingredients) {
          result.add({
            'name': ing.name,
            'qty': ing.qty,
          });
        }
      } else {
        result.add({
          'name': dish.name,
          'qty': dish.qty,
        });
      }
    }
    return result;
  }

  /// Valida se c'è abbastanza cibo in dispensa; lancia eccezione se insufficiente.
  static void validateItem({
    required String name,
    required String rawQtyString,
    required List<PantryItem> pantryItems,
    required Map<String, double> conversions,
  }) {
    if (rawQtyString == "N/A" || name.toLowerCase().contains("libero")) return;

    double reqQty = DietCalculator.parseQty(rawQtyString);
    String reqUnit = DietCalculator.parseUnit(rawQtyString, name);
    String normalizedName = name.trim().toLowerCase();

    int index = pantryItems.indexWhere((p) {
      final pName = p.name.toLowerCase();
      return (pName == normalizedName ||
          pName.contains(normalizedName) ||
          normalizedName.contains(pName));
    });

    if (index == -1) {
      throw IngredientException("Prodotto non trovato in dispensa: $name");
    }

    PantryItem pItem = pantryItems[index];

    if (pItem.unit.trim().toLowerCase() == reqUnit.trim().toLowerCase()) {
      if (pItem.quantity < reqQty) {
        throw IngredientException(
          "Quantità insufficiente di $name. Hai ${pItem.quantity} ${pItem.unit}, servono $reqQty.",
        );
      }
      return;
    }

    double conversionFactor = 1.0;
    String convKey =
        "${normalizedName}_${reqUnit.trim().toLowerCase()}_to_${pItem.unit.trim().toLowerCase()}";

    if (conversions.containsKey(convKey)) {
      conversionFactor = conversions[convKey]!;
    } else {
      double pVal = DietCalculator.normalizeToGrams(1, pItem.unit);
      double rVal = DietCalculator.normalizeToGrams(1, reqUnit);
      if (pVal <= 0 || rVal <= 0) {
        throw UnitMismatchException(item: pItem, requiredUnit: reqUnit);
      }
    }

    double reqQtyInPantryUnit = reqQty;
    if (conversions.containsKey(convKey)) {
      reqQtyInPantryUnit = reqQty * conversionFactor;
    } else {
      double rGrams = DietCalculator.normalizeToGrams(reqQty, reqUnit);
      double pGrams = DietCalculator.normalizeToGrams(1, pItem.unit);
      if (pGrams > 0) reqQtyInPantryUnit = rGrams / pGrams;
    }

    if (pItem.quantity < reqQtyInPantryUnit) {
      throw IngredientException("Quantità insufficiente di $name.");
    }
  }

  /// Esegue il consumo modificando la lista pantryItems passata per riferimento.
  /// Restituisce true se l'item è stato modificato/rimosso.
  static bool consumeItem({
    required String name,
    required String rawQtyString,
    required List<PantryItem> pantryItems,
    required Map<String, double> conversions,
  }) {
    if (rawQtyString == "N/A") return false;
    double reqQty = DietCalculator.parseQty(rawQtyString);
    String reqUnit = DietCalculator.parseUnit(rawQtyString, name);
    String normalizedName = name.trim().toLowerCase();

    int index = pantryItems.indexWhere((p) {
      final pName = p.name.toLowerCase();
      return (pName.contains(normalizedName) || normalizedName.contains(pName));
    });

    if (index != -1) {
      var item = pantryItems[index];
      double qtyToSubtract = reqQty;

      if (item.unit.toLowerCase() != reqUnit.toLowerCase()) {
        String convKey =
            "${normalizedName}_${reqUnit.trim().toLowerCase()}_to_${item.unit.trim().toLowerCase()}";
        if (conversions.containsKey(convKey)) {
          qtyToSubtract = reqQty * conversions[convKey]!;
        } else {
          double rGrams = DietCalculator.normalizeToGrams(reqQty, reqUnit);
          double pGramsOne = DietCalculator.normalizeToGrams(1, item.unit);
          if (rGrams > 0 && pGramsOne > 0) qtyToSubtract = rGrams / pGramsOne;
        }
      }

      item.quantity -= qtyToSubtract;
      if (item.quantity <= 0.01) {
        pantryItems.removeAt(index);
      }
      return true;
    }
    return false;
  }
}
