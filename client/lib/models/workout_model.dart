// Modelli dati per le schede allenamento.

class WorkoutExercise {
  final String name;
  final int? sets;
  final String? reps;
  final int? restSeconds;
  final String? notes;
  final int order;

  WorkoutExercise({
    required this.name,
    this.sets,
    this.reps,
    this.restSeconds,
    this.notes,
    this.order = 0,
  });

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      name: map['name'] ?? '',
      sets: map['sets'] as int?,
      reps: map['reps'] as String?,
      restSeconds: map['rest_seconds'] as int?,
      notes: map['notes'] as String?,
      order: (map['order'] as int?) ?? 0,
    );
  }
}

class WorkoutDay {
  final String dayName;
  final List<WorkoutExercise> exercises;
  final String? notes;

  WorkoutDay({
    required this.dayName,
    required this.exercises,
    this.notes,
  });

  factory WorkoutDay.fromMap(Map<String, dynamic> map) {
    final exercises = (map['exercises'] as List? ?? [])
        .map((e) => WorkoutExercise.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return WorkoutDay(
      dayName: map['day_name'] ?? '',
      exercises: exercises,
      notes: map['notes'] as String?,
    );
  }
}

class WorkoutPlan {
  final String? planId;
  final String planName;
  final List<WorkoutDay> days;
  final String? assignedBy;

  WorkoutPlan({
    this.planId,
    required this.planName,
    required this.days,
    this.assignedBy,
  });

  factory WorkoutPlan.fromMap(Map<String, dynamic> map) {
    final days = (map['days'] as List? ?? [])
        .map((d) => WorkoutDay.fromMap(Map<String, dynamic>.from(d)))
        .toList();

    return WorkoutPlan(
      planId: map['plan_id'] as String?,
      planName: map['plan_name'] ?? 'Scheda',
      days: days,
      assignedBy: map['assigned_by'] as String?,
    );
  }
}
