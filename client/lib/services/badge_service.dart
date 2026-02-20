import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';

class BadgeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<BadgeModel> _badges = [];
  List<BadgeModel> get badges => _badges;

  BadgeService() {
    _initBadges();
  }

  void _initBadges() {
    // Load static registry
    _badges = List.from(BadgeModel.registry);
    _loadUserBadges();
  }

  Future<void> _loadUserBadges() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      
      if (data != null && data.containsKey('unlocked_badges')) {
        final unlockedMap = data['unlocked_badges'] as Map<String, dynamic>;
        
        for (var badge in _badges) {
           if (unlockedMap.containsKey(badge.id)) {
             badge.isUnlocked = true;
             // unlockedMap[badge.id] could be timestamp or boolean, let's assume timestamp string if possible
             final val = unlockedMap[badge.id];
             if (val is String) {
               badge.unlockedAt = DateTime.tryParse(val);
             } else if (val is Timestamp) {
               badge.unlockedAt = val.toDate();
             }
           }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading badges: $e");
    }
  }

  /// Check conditions and unlock badge if met
  Future<void> unlockBadge(String badgeId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final badgeIndex = _badges.indexWhere((b) => b.id == badgeId);
    if (badgeIndex == -1) return;

    final badge = _badges[badgeIndex];
    if (badge.isUnlocked) return; // Already unlocked

    // Local update
    badge.isUnlocked = true;
    badge.unlockedAt = DateTime.now();
    notifyListeners();

    // Persist to Firestore
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'unlocked_badges.$badgeId': FieldValue.serverTimestamp(),
      });
      
      debugPrint("🏆 Badge Unlocked: ${badge.title}");
    } catch (e) {
      debugPrint("Error unlocking badge: $e");
      // Revert local state if save fails? usually safe to keep local state for UX
    }
  }
  
  /// Chiamato ad ogni accesso. Sblocca 'first_login' al primo accesso
  /// e tiene traccia dello streak consecutivo per 'streak_3'.
  Future<void> checkLoginStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Sblocca sempre first_login (se non già sbloccato)
    await unlockBadge('first_login');

    try {
      final ref = _firestore.collection('users').doc(user.uid);
      final doc = await ref.get();
      final data = doc.data() ?? {};

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

      final lastLoginStr = data['streak_last_login'] as String?;
      final currentStreak = (data['streak_count'] as int?) ?? 0;

      int newStreak;

      if (lastLoginStr == null) {
        // Prima volta in assoluto
        newStreak = 1;
      } else if (lastLoginStr == todayStr) {
        // Già loggato oggi, non cambia nulla
        return;
      } else {
        // Controlla se ieri
        final lastLogin = DateTime.tryParse(lastLoginStr);
        if (lastLogin != null) {
          final diff = today.difference(lastLogin).inDays;
          if (diff == 1) {
            // Giorno consecutivo
            newStreak = currentStreak + 1;
          } else {
            // Streak interrotto
            newStreak = 1;
          }
        } else {
          newStreak = 1;
        }
      }

      // Salva in Firestore
      await ref.update({
        'streak_last_login': todayStr,
        'streak_count': newStreak,
      });

      // Sblocca badge streak_3 se raggiunti 3 giorni consecutivi
      if (newStreak >= 3) {
        await unlockBadge('streak_3');
      }
    } catch (e) {
      debugPrint('Errore checkLoginStreak: $e');
    }
  }

  Future<void> onWeightLogged() async {
    await unlockBadge('weight_log_1');
  }

  Future<void> checkDailyGoals(int planned, int consumed) async {
    if (planned > 0 && consumed == planned) {
      await unlockBadge('diet_complete');
    }
  }

  Future<void> onShoppingListShared() async {
    await unlockBadge('shopping_list_shared');
  }

  /// Checks if user has completed ≥3 meals/day for at least 5 days this week
  Future<void> checkWeeklyChallenge(Map<String, dynamic> consumptionData) async {
    int daysWithEnoughMeals = 0;
    for (final entry in consumptionData.entries) {
      final dayCount = entry.value;
      if (dayCount is int && dayCount >= 3) {
        daysWithEnoughMeals++;
      }
    }
    if (daysWithEnoughMeals >= 5) {
      await unlockBadge('weekly_challenge');
    }
  }
}
