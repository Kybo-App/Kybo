// Calcolatrice nutrizionale: inserimento ingredienti con quantità e macro per 100g, calcolo totali in tempo reale.
// _calculateTotals — ricalcola kcal/proteine/carboidrati/grassi sommando tutti gli ingredienti validi.
import 'package:flutter/material.dart';
import '../core/app_localizations.dart';
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
    _addIngredient();
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.calculate_rounded, color: KyboColors.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              l10n.calculatorTitle,
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
          l10n.calculatorDescription,
          style: TextStyle(color: KyboColors.textSecondary),
        ),
        const SizedBox(height: 24),

        _buildTotalsCard(l10n),
        const SizedBox(height: 24),

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
                        l10n.calculatorIngredients,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: KyboColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      PillButton(
                        label: l10n.calculatorAddIngredient,
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
                      return _buildIngredientRow(idx, _ingredients[idx], l10n);
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

  Widget _buildTotalsCard(AppLocalizations l10n) {
    return PillCard(
      backgroundColor: KyboColors.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroStat(l10n.calculatorKcal, _totalKcal, "kcal", Colors.grey[800]!),
          _buildMacroStat(l10n.calculatorProtein, _totalProtein, "g", KyboColors.protein),
          _buildMacroStat(l10n.calculatorCarbs, _totalCarbs, "g", KyboColors.carbs),
          _buildMacroStat(l10n.calculatorFat, _totalFat, "g", KyboColors.fat),
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

  Widget _buildIngredientRow(
      int index, _IngredientRow ingredient, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        Expanded(
          flex: 2,
          child: PillTextField(
            labelText: l10n.calculatorIngredientName,
            hintText: l10n.calculatorIngredientHint,
            onChanged: (val) => ingredient.name = val,
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: PillTextField(
            labelText: l10n.calculatorQuantity,
            hintText: "100",
            keyboardType: TextInputType.number,
            onChanged: (val) {
              ingredient.quantity = double.tryParse(val) ?? 0;
              _calculateTotals();
            },
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: PillTextField(
            labelText: l10n.calculatorKcal100,
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
            labelText: l10n.calculatorProt100,
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
            labelText: l10n.calculatorCarb100,
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
            labelText: l10n.calculatorFat100,
            keyboardType: TextInputType.number,
            onChanged: (val) {
              ingredient.fat100 = double.tryParse(val) ?? 0;
              _calculateTotals();
            },
          ),
        ),

        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            color: KyboColors.error,
            onPressed: () => _removeIngredient(index),
            tooltip: l10n.remove,
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
