import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';

/// Service per gestire tracking peso, statistiche e obiettivi
class TrackingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- WEIGHT TRACKING ---
  /// Salva una nuova misurazione del peso
  Future<void> saveWeight(double weightKg, {String? note}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final entry = WeightEntry(
        date: DateTime.now(),
        weightKg: weightKg,
        note: note,
      );

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('weight_history')
          .add(entry.toJson());

      debugPrint("✅ Peso salvato: $weightKg kg");
    } catch (e) {
      debugPrint("❌ Errore salvataggio peso: $e");
      rethrow;
    }
  }

  /// Stream dello storico pesi (ultimi 30 giorni)
  Stream<List<WeightEntry>> getWeightHistory({int days = 30}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final cutoff = DateTime.now().subtract(Duration(days: days));

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('weight_history')
        .where('date', isGreaterThan: cutoff.toIso8601String())
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WeightEntry.fromJson(doc.data()))
            .toList());
  }

  /// Ultimo peso registrato
  Future<WeightEntry?> getLatestWeight() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('weight_history')
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return WeightEntry.fromJson(snapshot.docs.first.data());
  }

  // --- DAILY STATS ---
  /// Salva le statistiche dei pasti del giorno
  Future<void> saveDailyStats(DailyMealStats stats) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Usa la data come ID documento per evitare duplicati
      final docId = stats.date.toIso8601String().split('T')[0];

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('daily_stats')
          .doc(docId)
          .set(stats.toJson(), SetOptions(merge: true));

      debugPrint("✅ Stats giornaliere salvate per $docId");
    } catch (e) {
      debugPrint("❌ Errore salvataggio stats: $e");
      rethrow;
    }
  }

  /// Stream statistiche settimanali (ultimi 7 giorni)
  Stream<List<DailyMealStats>> getWeeklyStats() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekAgoStr = weekAgo.toIso8601String().split('T')[0];

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('daily_stats')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: weekAgoStr)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DailyMealStats.fromJson({...doc.data(), 'date': doc.id}))
            .toList());
  }

  /// Calcola statistiche aggregate della settimana
  Future<WeeklyStats> calculateWeeklyStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return WeeklyStats(
        weekStart: DateTime.now(),
        totalMealsPlanned: 0,
        totalMealsConsumed: 0,
        daysWithFullAdherence: 0,
        currentStreak: 0,
      );
    }

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekAgoStr = weekAgo.toIso8601String().split('T')[0];

    final snapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('daily_stats')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: weekAgoStr)
        .get();

    int totalPlanned = 0;
    int totalConsumed = 0;
    int fullAdherenceDays = 0;
    int currentStreak = 0;

    for (final doc in snapshot.docs) {
      final stats = DailyMealStats.fromJson({...doc.data(), 'date': doc.id});
      totalPlanned += stats.mealsPlanned;
      totalConsumed += stats.mealsConsumed;
      
      if (stats.mealsPlanned > 0 && stats.mealsConsumed == stats.mealsPlanned) {
        fullAdherenceDays++;
        currentStreak++;
      } else {
        currentStreak = 0; // Reset streak
      }
    }

    return WeeklyStats(
      weekStart: weekAgo,
      totalMealsPlanned: totalPlanned,
      totalMealsConsumed: totalConsumed,
      daysWithFullAdherence: fullAdherenceDays,
      currentStreak: currentStreak,
    );
  }

  // --- USER GOALS ---
  /// Salva/aggiorna un obiettivo
  Future<void> saveGoal(UserGoal goal) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(goal.id)
          .set(goal.toJson());

      debugPrint("✅ Obiettivo salvato: ${goal.title}");
    } catch (e) {
      debugPrint("❌ Errore salvataggio obiettivo: $e");
      rethrow;
    }
  }

  /// Stream obiettivi attivi
  Stream<List<UserGoal>> getGoals() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .where('is_completed', isEqualTo: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserGoal.fromJson(doc.data())).toList());
  }

  /// Aggiorna progresso obiettivo
  Future<void> updateGoalProgress(String goalId, double newValue) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(goalId);

      final doc = await docRef.get();
      if (!doc.exists) return;

      final goal = UserGoal.fromJson(doc.data()!);
      final isComplete = newValue >= goal.targetValue;

      await docRef.update({
        'current_value': newValue,
        'is_completed': isComplete,
      });

      debugPrint("✅ Obiettivo aggiornato: $newValue/${goal.targetValue}");
    } catch (e) {
      debugPrint("❌ Errore aggiornamento obiettivo: $e");
      rethrow;
    }
  }
}
