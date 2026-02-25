// Modelli core della dieta: DietConfig, Ingredient, Dish, SubstitutionGroup, DietPlan.
// DietPlan.fromJson — supporta formato multi-settimana ('weeks') e legacy ('plan').
// Dish.fromJson — genera UUID per instanceId se assente per evitare bug nelle sostituzioni.
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Configurazione dinamica della dieta estratta dal parser AI.
/// Contiene giorni, pasti e alimenti "rilassabili" specifici per questa dieta.
class DietConfig {
  final List<String> days;
  final List<String> meals;
  final Set<String> relaxableFoods;

  DietConfig({
    required this.days,
    required this.meals,
    required this.relaxableFoods,
  });

  factory DietConfig.fromJson(Map<String, dynamic> json) {
    return DietConfig(
      days: (json['days'] as List<dynamic>?)?.cast<String>() ?? [],
      meals: (json['meals'] as List<dynamic>?)?.cast<String>() ?? [],
      relaxableFoods: (json['relaxable_foods'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'days': days,
        'meals': meals,
        'relaxable_foods': relaxableFoods.toList(),
      };

  /// Verifica se la config è vuota (fallback necessario).
  bool get isEmpty => days.isEmpty && meals.isEmpty;
}

class Ingredient {
  final String name;
  final String qty;

  Ingredient({required this.name, required this.qty});

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name']?.toString() ?? '',
      qty: json['qty']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty};
}

class Dish {
  final String instanceId;
  final String name;
  final String qty;
  final int cadCode;
  final bool isComposed;
  final List<Ingredient> ingredients;

  bool isConsumed;

  Dish({
    required this.instanceId,
    required this.name,
    required this.qty,
    required this.cadCode,
    required this.isComposed,
    required this.ingredients,
    this.isConsumed = false,
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    final rawId = json['instance_id']?.toString() ?? '';
    final instanceId = rawId.isNotEmpty ? rawId : _uuid.v4();

    return Dish(
      instanceId: instanceId,
      name: json['name']?.toString() ?? 'Sconosciuto',
      qty: json['qty']?.toString() ?? '',
      cadCode: (json['cad_code'] is int) ? json['cad_code'] : 0,
      isComposed: json['is_composed'] ?? false,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e))
              .toList() ??
          [],
      isConsumed: json['consumed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'instance_id': instanceId,
        'name': name,
        'qty': qty,
        'cad_code': cadCode,
        'is_composed': isComposed,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'consumed': isConsumed,
      };
}

class SubstitutionOption {
  final String name;
  final String qty;

  SubstitutionOption({required this.name, required this.qty});

  factory SubstitutionOption.fromJson(Map<String, dynamic> json) {
    return SubstitutionOption(
      name: json['name']?.toString() ?? '',
      qty: json['qty']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty};
}

class SubstitutionGroup {
  final String name;
  final List<SubstitutionOption> options;

  SubstitutionGroup({required this.name, required this.options});

  factory SubstitutionGroup.fromJson(Map<String, dynamic> json) {
    return SubstitutionGroup(
      name: json['name']?.toString() ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => SubstitutionOption.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'options': options.map((e) => e.toJson()).toList()};
}

class DietPlan {
  /// Lista di tutte le settimane: weeks[0] = settimana 1, weeks[1] = settimana 2, ...
  /// Struttura per settimana: Giorno -> Pasto -> Lista di Piatti.
  final List<Map<String, Map<String, List<Dish>>>> weeks;
  final Map<String, SubstitutionGroup> substitutions;

  /// Configurazione dinamica (giorni, pasti, relaxable foods).
  /// Estratta dal parser AI, può essere null per retrocompatibilità.
  final DietConfig? config;

  DietPlan({
    required this.weeks,
    required this.substitutions,
    this.config,
  });

  /// Restituisce il piano della prima settimana (backward compat).
  Map<String, Map<String, List<Dish>>> get plan =>
      weeks.isNotEmpty ? weeks[0] : {};

  /// Numero totale di settimane nel piano.
  int get weekCount => weeks.length;

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    List<Map<String, Map<String, List<Dish>>>> parsedWeeks = [];

    if (json['weeks'] != null && (json['weeks'] as List).isNotEmpty) {
      for (final weekJson in (json['weeks'] as List)) {
        parsedWeeks.add(_parseWeekPlan(weekJson as Map<String, dynamic>));
      }
    } else if (json['plan'] != null) {
      parsedWeeks = [_parseWeekPlan(json['plan'] as Map<String, dynamic>)];
    }

    Map<String, SubstitutionGroup> parsedSubs = {};
    if (json['substitutions'] != null) {
      (json['substitutions'] as Map<String, dynamic>).forEach((k, v) {
        parsedSubs[k] = SubstitutionGroup.fromJson(v);
      });
    }

    DietConfig? parsedConfig;
    if (json['config'] != null) {
      parsedConfig = DietConfig.fromJson(json['config']);
    }

    return DietPlan(
      weeks: parsedWeeks,
      substitutions: parsedSubs,
      config: parsedConfig,
    );
  }

  /// Parsa un singolo piano settimanale: {giorno: {pasto: [piatti]}}.
  static Map<String, Map<String, List<Dish>>> _parseWeekPlan(
      Map<String, dynamic> weekJson) {
    final Map<String, Map<String, List<Dish>>> weekPlan = {};
    weekJson.forEach((day, meals) {
      final Map<String, List<Dish>> dayMeals = {};
      (meals as Map<String, dynamic>).forEach((mealType, dishes) {
        dayMeals[mealType] =
            (dishes as List<dynamic>).map((d) => Dish.fromJson(d)).toList();
      });
      weekPlan[day] = dayMeals;
    });
    return weekPlan;
  }

  /// Fondamentale per il salvataggio su Firestore/Locale.
  Map<String, dynamic> toJson() {
    final List<dynamic> jsonWeeks = weeks.map((weekPlan) {
      final Map<String, dynamic> jsonWeek = {};
      weekPlan.forEach((day, meals) {
        final Map<String, dynamic> jsonMeals = {};
        meals.forEach((type, dishes) {
          jsonMeals[type] = dishes.map((d) => d.toJson()).toList();
        });
        jsonWeek[day] = jsonMeals;
      });
      return jsonWeek;
    }).toList();

    final Map<String, dynamic> jsonSubs = {};
    substitutions.forEach((k, v) {
      jsonSubs[k] = v.toJson();
    });

    return {
      'plan': jsonWeeks.isNotEmpty ? jsonWeeks[0] : {},
      'weeks': jsonWeeks,
      'substitutions': jsonSubs,
      if (config != null) 'config': config!.toJson(),
    };
  }
}
