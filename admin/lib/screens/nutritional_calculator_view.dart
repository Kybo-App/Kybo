import 'package:flutter/material.dart';
import '../widgets/design_system.dart';

class NutritionalCalculatorView extends StatefulWidget {
  const NutritionalCalculatorView({super.key});

  @override
  State<NutritionalCalculatorView> createState() =>
      _NutritionalCalculatorViewState();
}

class _NutritionalCalculatorViewState extends State<NutritionalCalculatorView> {
  final List<_IngredientRow> _ingredients = [];
  double _totalKcal = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;

  @override
  void initState() {
    super.initState();
    _addIngredient(); // Start with one row
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientRow());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    double kcal = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (var ingredient in _ingredients) {
      if (ingredient.isValid) {
        double factor = ingredient.quantity / 100.0;
        kcal += ingredient.kcal100 * factor;
        protein += ingredient.protein100 * factor;
        carbs += ingredient.carbs100 * factor;
        fat += ingredient.fat100 * factor;
      }
    }

    setState(() {
      _totalKcal = kcal;
      _totalProtein = protein;
      _totalCarbs = carbs;
      _totalFat = fat;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.calculate_rounded, color: KyboColors.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              "Calcolatrice Nutrizionale",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: KyboColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Inserisci gli ingredienti e le quantità per calcolare i macro totali del pasto.",
          style: TextStyle(color: KyboColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Totals Card
        _buildTotalsCard(),
        const SizedBox(height: 24),

        // Ingredients List
        Expanded(
          child: PillCard(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        "Ingredienti",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: KyboColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      PillButton(
                        label: "Aggiungi Ingrediente",
                        icon: Icons.add,
                        onPressed: _addIngredient,
                        height: 36,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ingredients.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
                    itemBuilder: (ctx, idx) {
                      return _buildIngredientRow(idx, _ingredients[idx]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsCard() {
    return PillCard(
      color: KyboColors.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroStat("Kcal", _totalKcal, "kcal", Colors.grey[800]!),
          _buildMacroStat("Proteine", _totalProtein, "g", KyboColors.protein),
          _buildMacroStat("Carboidrati", _totalCarbs, "g", KyboColors.carbs),
          _buildMacroStat("Grassi", _totalFat, "g", KyboColors.fat),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: KyboColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "${value.toStringAsFixed(1)}$unit",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(int index, _IngredientRow ingredient) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Index
        Padding(
          padding: const EdgeInsets.only(top: 18, right: 12),
          child: Text(
            "${index + 1}.",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: KyboColors.textMuted,
            ),
          ),
        ),

        // Name
        Expanded(
          flex: 2,
          child: PillTextField(
            label: "Nome Ingrediente",
            hint: "es. Pollo",
            onChanged: (val) => ingredient.name = val,
          ),
        ),
        const SizedBox(width: 12),

        // Quantity (g)
        Expanded(
          child: PillTextField(
            label: "Quantità (g)",
            hint: "100",
            keyboardType: TextInputType.number,
            onChanged: (val) {
              ingredient.quantity = double.tryParse(val) ?? 0;
              _calculateTotals();
            },
          ),
        ),
        const SizedBox(width: 12),

        // Macros (per 100g)
        Expanded(
          child: PillTextField(
            label: "Kcal/100g",
            keyboardType: TextInputType.number,
            onChanged: (val) {
              ingredient.kcal100 = double.tryParse(val) ?? 0;
              _calculateTotals();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PillTextField(
            label: "Prot/100g",
            keyboardType: TextInputType.number,
            onChanged: (val) {
              ingredient.protein100 = double.tryParse(val) ?? 0;
              _calculateTotals();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PillTextField(
            label: "Carb/100g",
            keyboardType: TextInputType.number,
            onChanged: (val) {
              ingredient.carbs100 = double.tryParse(val) ?? 0;
              _calculateTotals();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PillTextField(
            label: "Fat/100g",
            keyboardType: TextInputType.number,
            onChanged: (val) {
              ingredient.fat100 = double.tryParse(val) ?? 0;
              _calculateTotals();
            },
          ),
        ),

        const SizedBox(width: 12),
        // Delete Button
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            color: KyboColors.error,
            onPressed: () => _removeIngredient(index),
            tooltip: "Rimuovi",
          ),
        ),
      ],
    );
  }
}

class _IngredientRow {
  String name = "";
  double quantity = 0;
  double kcal100 = 0;
  double protein100 = 0;
  double carbs100 = 0;
  double fat100 = 0;

  bool get isValid => quantity > 0;
}
