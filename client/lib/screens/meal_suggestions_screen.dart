import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/shortcuts_service.dart';
import '../widgets/design_system.dart';

/// Modello per un singolo suggerimento pasto da Gemini AI.
class SuggestedDish {
  final String name;
  final String qty;
  final String mealType;
  final String description;
  final List<String> ingredients;
  final String? caloriesEstimate;

  const SuggestedDish({
    required this.name,
    required this.qty,
    required this.mealType,
    required this.description,
    required this.ingredients,
    this.caloriesEstimate,
  });

  factory SuggestedDish.fromJson(Map<String, dynamic> json) {
    return SuggestedDish(
      name: json['name'] ?? '',
      qty: json['qty'] ?? '',
      mealType: json['meal_type'] ?? '',
      description: json['description'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      caloriesEstimate: json['calories_estimate'],
    );
  }
}

/// Schermata Suggerimenti Pasti AI — generati da Gemini in base alla
/// dieta corrente, allergeni e mood recente dell'utente.
class MealSuggestionsScreen extends StatefulWidget {
  const MealSuggestionsScreen({super.key});

  @override
  State<MealSuggestionsScreen> createState() => _MealSuggestionsScreenState();
}

class _MealSuggestionsScreenState extends State<MealSuggestionsScreen> {
  static const _mealTypes = ['Tutti', 'Colazione', 'Pranzo', 'Merenda', 'Cena'];
  static const _mealColors = {
    'Colazione': Color(0xFFFF9800),
    'Pranzo': Color(0xFF4CAF50),
    'Merenda': Color(0xFF9C27B0),
    'Cena': Color(0xFF2196F3),
    'Spuntino': Color(0xFF00BCD4),
  };

  final ApiClient _api = ApiClient();

  String _selectedMealType = 'Tutti';
  int _count = 6;
  List<SuggestedDish> _suggestions = [];
  String _contextUsed = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
    // Dona shortcut a Siri ogni volta che l'utente apre questa schermata
    ShortcutsService().donateShortcut(ShortcutsService.suggestionsActivity);
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final queryParams = StringBuffer('/meal-suggestions?count=$_count');
      if (_selectedMealType != 'Tutti') {
        queryParams.write('&meal_type=${Uri.encodeComponent(_selectedMealType)}');
      }

      final data = await _api.get(queryParams.toString()) as Map<String, dynamic>;
      final rawList = data['suggestions'] as List<dynamic>? ?? [];
      setState(() {
        _suggestions = rawList
            .whereType<Map<String, dynamic>>()
            .map(SuggestedDish.fromJson)
            .toList();
        _contextUsed = data['context_used'] ?? '';
        _loading = false;
      });
    } on ApiException catch (e) {
      debugPrint('⚠️ Errore API suggerimenti: ${e.statusCode} - ${e.message}');
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on NetworkException catch (_) {
      setState(() {
        _error = 'Nessuna connessione internet.';
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Errore imprevisto suggerimenti: $e');
      setState(() {
        _error = 'Errore imprevisto: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: KyboColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [KyboColors.primary, KyboColors.primaryDark],
                ),
                borderRadius: KyboBorderRadius.small,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Suggerimenti AI',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: KyboColors.primary),
            tooltip: 'Aggiorna suggerimenti',
            onPressed: _loading ? null : _fetchSuggestions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(context),
          if (_contextUsed.isNotEmpty && !_loading)
            _buildContextBadge(context),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  // ─── Filtri tipo pasto ──────────────────────────────────────────────────────
  Widget _buildFilters(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _mealTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = _mealTypes[i];
          final selected = _selectedMealType == type;
          return GestureDetector(
            onTap: () {
              if (_selectedMealType != type) {
                setState(() => _selectedMealType = type);
                _fetchSuggestions();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [KyboColors.primary, KyboColors.primaryDark])
                    : null,
                color: selected ? null : KyboColors.surface(context),
                borderRadius: KyboBorderRadius.pill,
                border: Border.all(
                  color: selected
                      ? KyboColors.primary
                      : KyboColors.border(context),
                  width: 1,
                ),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : KyboColors.textSecondary(context),
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Badge contesto usato ───────────────────────────────────────────────────
  Widget _buildContextBadge(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Basato su: $_contextUsed',
              style: TextStyle(
                fontSize: 11,
                color: KyboColors.textMuted(context),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Contenuto principale ───────────────────────────────────────────────────
  Widget _buildContent(BuildContext context) {
    if (_loading) return _buildLoading(context);
    if (_error != null) return _buildError(context);
    if (_suggestions.isEmpty) return _buildEmpty(context);

    return KyboBreakpoints.isTablet(context)
        ? _buildGrid(context)
        : _buildList(context);
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: KyboColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(KyboColors.primary),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Gemini AI sta elaborando\ni tuoi suggerimenti...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KyboColors.textSecondary(context),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KyboColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: KyboColors.error, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Ops, qualcosa è andato storto',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KyboColors.textMuted(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchSuggestions,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: KyboColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: KyboBorderRadius.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 64,
            color: KyboColors.textMuted(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun suggerimento disponibile',
            style: TextStyle(
              color: KyboColors.textMuted(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Carica una dieta per suggerimenti personalizzati',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KyboColors.textMuted(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _suggestions.length,
      itemBuilder: (context, i) => _buildSuggestionCard(context, _suggestions[i]),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _suggestions.length,
      itemBuilder: (context, i) => _buildSuggestionCard(context, _suggestions[i]),
    );
  }

  // ─── Card singolo suggerimento ──────────────────────────────────────────────
  Widget _buildSuggestionCard(BuildContext context, SuggestedDish dish) {
    final mealColor = _mealColors[dish.mealType] ?? KyboColors.primary;

    return Container(
      margin: KyboBreakpoints.isTablet(context)
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: KyboColors.border(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: meal type chip + calorie
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: mealColor.withValues(alpha: 0.12),
                    borderRadius: KyboBorderRadius.pill,
                  ),
                  child: Text(
                    dish.mealType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: mealColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                if (dish.caloriesEstimate != null && dish.caloriesEstimate!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: KyboColors.success.withValues(alpha: 0.1),
                      borderRadius: KyboBorderRadius.pill,
                    ),
                    child: Text(
                      dish.caloriesEstimate!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: KyboColors.success,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Nome piatto + quantità
            Text(
              dish.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: KyboColors.textPrimary(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (dish.qty.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                dish.qty,
                style: TextStyle(
                  fontSize: 12,
                  color: KyboColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Descrizione
            Text(
              dish.description,
              style: TextStyle(
                fontSize: 12,
                color: KyboColors.textSecondary(context),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Ingredienti
            if (dish.ingredients.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: KyboColors.border(context), height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: dish.ingredients.take(5).map((ing) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: KyboColors.background(context),
                      borderRadius: KyboBorderRadius.small,
                      border: Border.all(color: KyboColors.border(context)),
                    ),
                    child: Text(
                      ing,
                      style: TextStyle(
                        fontSize: 10,
                        color: KyboColors.textSecondary(context),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
