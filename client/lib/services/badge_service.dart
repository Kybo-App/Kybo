import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';

// ─── Sistema Livelli ─────────────────────────────────────────────────────────

class BadgeLevel {
  final String name;
  final String emoji;
  final int minBadges; // badge minimi per raggiungere questo livello
  final int maxBadges; // badge necessari per il prossimo livello (esclusivo)

  const BadgeLevel({
    required this.name,
    required this.emoji,
    required this.minBadges,
    required this.maxBadges,
  });
}

const List<BadgeLevel> kBadgeLevels = [
  BadgeLevel(name: 'Principiante', emoji: '🌱', minBadges: 0, maxBadges: 1),
  BadgeLevel(name: 'Curioso',      emoji: '🥗', minBadges: 1, maxBadges: 3),
  BadgeLevel(name: 'Costante',     emoji: '💪', minBadges: 3, maxBadges: 5),
  BadgeLevel(name: 'Campione',     emoji: '🏆', minBadges: 5, maxBadges: 6),
  BadgeLevel(name: 'Esperto Kybo', emoji: '⭐', minBadges: 6, maxBadges: 7), // 7 = oltre il massimo
];

BadgeLevel badgeLevelFor(int unlockedCount) {
  for (final level in kBadgeLevels.reversed) {
    if (unlockedCount >= level.minBadges) return level;
  }
  return kBadgeLevels.first;
}

// ─────────────────────────────────────────────────────────────────────────────

class BadgeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<BadgeModel> _badges = [];
  List<BadgeModel> get badges => _badges;

  // Livello corrente — aggiornato ogni volta che si sblocca un badge
  BadgeLevel get currentLevel => badgeLevelFor(unlockedCount);
  int get unlockedCount => _badges.where((b) => b.isUnlocked).length;

  // Badge appena sbloccato — usato per mostrare il popup nella UI
  BadgeModel? _justUnlocked;
  BadgeModel? get justUnlocked => _justUnlocked;

  // Level-up appena avvenuto — usato per mostrare la celebrazione
  BadgeLevel? _justLeveledUp;
  BadgeLevel? get justLeveledUp => _justLeveledUp;

  void clearJustUnlocked() {
    _justUnlocked = null;
    _justLeveledUp = null;
  }

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

  /// Sblocca un badge se non già sbloccato.
  /// Imposta justUnlocked e justLeveledUp per trigger UI.
  Future<void> unlockBadge(String badgeId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final badgeIndex = _badges.indexWhere((b) => b.id == badgeId);
    if (badgeIndex == -1) return;

    final badge = _badges[badgeIndex];
    if (badge.isUnlocked) return; // Already unlocked

    // Livello PRIMA dello sblocco
    final levelBefore = currentLevel;

    // Local update
    badge.isUnlocked = true;
    badge.unlockedAt = DateTime.now();
    _justUnlocked = badge;

    // Livello DOPO lo sblocco
    final levelAfter = currentLevel;
    if (levelAfter.name != levelBefore.name) {
      _justLeveledUp = levelAfter;
    }

    notifyListeners();

    // Persist to Firestore
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'unlocked_badges.$badgeId': FieldValue.serverTimestamp(),
      });
      debugPrint("🏆 Badge sbloccato: ${badge.title} | Livello: ${levelAfter.emoji} ${levelAfter.name}");
    } catch (e) {
      debugPrint("Error unlocking badge: $e");
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
