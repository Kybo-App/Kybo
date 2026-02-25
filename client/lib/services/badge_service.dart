// Gestisce il sistema di badge e livelli utente: sblocco, persistenza su Firestore e streak di accesso.
// badgeLevelFor — calcola il livello corrente in base al numero di badge sbloccati; checkLoginStreak — aggiorna lo streak giornaliero e sblocca badge relativi.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';

class BadgeLevel {
  final String name;
  final String emoji;
  final int minBadges;
  final int maxBadges;

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
  BadgeLevel(name: 'Esperto Kybo', emoji: '⭐', minBadges: 6, maxBadges: 7),
];

BadgeLevel badgeLevelFor(int unlockedCount) {
  for (final level in kBadgeLevels.reversed) {
    if (unlockedCount >= level.minBadges) return level;
  }
  return kBadgeLevels.first;
}

class BadgeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<BadgeModel> _badges = [];
  List<BadgeModel> get badges => _badges;

  BadgeLevel get currentLevel => badgeLevelFor(unlockedCount);
  int get unlockedCount => _badges.where((b) => b.isUnlocked).length;

  BadgeModel? _justUnlocked;
  BadgeModel? get justUnlocked => _justUnlocked;

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

  Future<void> unlockBadge(String badgeId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final badgeIndex = _badges.indexWhere((b) => b.id == badgeId);
    if (badgeIndex == -1) return;

    final badge = _badges[badgeIndex];
    if (badge.isUnlocked) return;

    final levelBefore = currentLevel;

    badge.isUnlocked = true;
    badge.unlockedAt = DateTime.now();
    _justUnlocked = badge;

    final levelAfter = currentLevel;
    if (levelAfter.name != levelBefore.name) {
      _justLeveledUp = levelAfter;
    }

    notifyListeners();

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'unlocked_badges.$badgeId': FieldValue.serverTimestamp(),
      });
      debugPrint("🏆 Badge sbloccato: ${badge.title} | Livello: ${levelAfter.emoji} ${levelAfter.name}");
    } catch (e) {
      debugPrint("Error unlocking badge: $e");
    }
  }

  Future<void> checkLoginStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

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
        newStreak = 1;
      } else if (lastLoginStr == todayStr) {
        return;
      } else {
        final lastLogin = DateTime.tryParse(lastLoginStr);
        if (lastLogin != null) {
          final diff = today.difference(lastLogin).inDays;
          if (diff == 1) {
            newStreak = currentStreak + 1;
          } else {
            newStreak = 1;
          }
        } else {
          newStreak = 1;
        }
      }

      await ref.update({
        'streak_last_login': todayStr,
        'streak_count': newStreak,
      });

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
