/// Modelli per tracking progressi e statistiche utente

/// Entry per tracking del peso
class WeightEntry {
  final DateTime date;
  final double weightKg;
  final String? note;

  WeightEntry({
    required this.date,
    required this.weightKg,
    this.note,
  });

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: DateTime.parse(json['date']),
      weightKg: (json['weight_kg'] as num).toDouble(),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight_kg': weightKg,
        if (note != null) 'note': note,
      };
}

/// Statistiche giornaliere dei pasti consumati
class DailyMealStats {
  final DateTime date;
  final int mealsPlanned;
  final int mealsConsumed;
  final Map<String, bool> mealCompletion; // es. {"Colazione": true, "Pranzo": false}

  DailyMealStats({
    required this.date,
    required this.mealsPlanned,
    required this.mealsConsumed,
    required this.mealCompletion,
  });

  double get adherencePercent =>
      mealsPlanned > 0 ? (mealsConsumed / mealsPlanned) * 100 : 0;

  factory DailyMealStats.fromJson(Map<String, dynamic> json) {
    return DailyMealStats(
      date: DateTime.parse(json['date']),
      mealsPlanned: json['meals_planned'] ?? 0,
      mealsConsumed: json['meals_consumed'] ?? 0,
      mealCompletion: Map<String, bool>.from(json['meal_completion'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'meals_planned': mealsPlanned,
        'meals_consumed': mealsConsumed,
        'meal_completion': mealCompletion,
      };
}

/// Statistiche settimanali aggregate
class WeeklyStats {
  final DateTime weekStart;
  final int totalMealsPlanned;
  final int totalMealsConsumed;
  final int daysWithFullAdherence; // Giorni con 100% aderenza
  final int currentStreak; // Streak giorni consecutivi 100%

  WeeklyStats({
    required this.weekStart,
    required this.totalMealsPlanned,
    required this.totalMealsConsumed,
    required this.daysWithFullAdherence,
    required this.currentStreak,
  });

  double get weeklyAdherencePercent =>
      totalMealsPlanned > 0 ? (totalMealsConsumed / totalMealsPlanned) * 100 : 0;

  factory WeeklyStats.fromJson(Map<String, dynamic> json) {
    return WeeklyStats(
      weekStart: DateTime.parse(json['week_start']),
      totalMealsPlanned: json['total_meals_planned'] ?? 0,
      totalMealsConsumed: json['total_meals_consumed'] ?? 0,
      daysWithFullAdherence: json['days_with_full_adherence'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'week_start': weekStart.toIso8601String(),
        'total_meals_planned': totalMealsPlanned,
        'total_meals_consumed': totalMealsConsumed,
        'days_with_full_adherence': daysWithFullAdherence,
        'current_streak': currentStreak,
      };
}

/// Obiettivo personalizzato dell'utente
class UserGoal {
  final String id;
  final String title;
  final String? description;
  final double targetValue;
  final double currentValue;
  final String unit; // "L", "kg", "pasti", etc.
  final bool isCompleted;

  UserGoal({
    required this.id,
    required this.title,
    this.description,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    this.isCompleted = false,
  });

  double get progressPercent =>
      targetValue > 0 ? (currentValue / targetValue * 100).clamp(0, 100) : 0;

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? '',
      isCompleted: json['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'target_value': targetValue,
        'current_value': currentValue,
        'unit': unit,
        'is_completed': isCompleted,
      };
}
