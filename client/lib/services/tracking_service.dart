// Gestisce tracking peso, statistiche giornaliere/settimanali, obiettivi e note pasti su Firestore.
// calculateWeeklyStats — aggrega i dati della settimana calcolando streak e aderenza; saveDailyStats — usa la data come ID documento per evitare duplicati.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';

class TrackingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  Future<void> saveDailyStats(DailyMealStats stats) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

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
        currentStreak = 0;
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

  Future<void> saveMealNote(MealNote note) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('meal_notes')
          .doc(note.id)
          .set(note.toJson());

      debugPrint("✅ Nota pasto salvata: ${note.mealType}");
    } catch (e) {
      debugPrint("❌ Errore salvataggio nota: $e");
      rethrow;
    }
  }

  Future<MealNote?> getMealNote(String day, String mealType) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final noteId = '${today}_${day}_$mealType';

    final doc = await _db
        .collection('users')
        .doc(user.uid)
        .collection('meal_notes')
        .doc(noteId)
        .get();

    if (!doc.exists) return null;
    return MealNote.fromJson(doc.data()!);
  }

  Stream<List<MealNote>> getTodayNotes() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final today = DateTime.now().toIso8601String().split('T')[0];

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('meal_notes')
        .where('date', isGreaterThanOrEqualTo: today)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MealNote.fromJson(doc.data())).toList());
  }
}
