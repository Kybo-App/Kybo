// Gestisce il sistema di badge, livelli e contatori utente: sblocco, persistenza su Firestore e streak di accesso.
// Supporta badge progressivi con contatori, feature-discovery, badge segreti e integrazione XP.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';

class BadgeLevel {
  final String name;
  final String emoji;
  final int minXp;
  final int maxXp;

  const BadgeLevel({
    required this.name,
    required this.emoji,
    required this.minXp,
    required this.maxXp,
  });
}

const List<BadgeLevel> kBadgeLevels = [
  BadgeLevel(name: 'Principiante', emoji: '🌱', minXp: 0, maxXp: 100),
  BadgeLevel(name: 'Curioso',      emoji: '🥗', minXp: 100, maxXp: 300),
  BadgeLevel(name: 'Impegnato',    emoji: '💪', minXp: 300, maxXp: 750),
  BadgeLevel(name: 'Costante',     emoji: '🔥', minXp: 750, maxXp: 1500),
  BadgeLevel(name: 'Campione',     emoji: '🏆', minXp: 1500, maxXp: 3000),
  BadgeLevel(name: 'Esperto',      emoji: '🌟', minXp: 3000, maxXp: 6000),
  BadgeLevel(name: 'Leggenda Kybo', emoji: '⭐', minXp: 6000, maxXp: 99999),
];

BadgeLevel badgeLevelFor(int xp) {
  for (final level in kBadgeLevels.reversed) {
    if (xp >= level.minXp) return level;
  }
  return kBadgeLevels.first;
}

class BadgeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<BadgeModel> _badges = [];
  List<BadgeModel> get badges => _badges;

  /// Contatori persistenti per badge progressivi.
  Map<String, int> _counters = {};
  Map<String, int> get counters => _counters;

  /// XP totali dell'utente (sincronizzati con XpService, ma letti anche qui per i livelli).
  int _totalXp = 0;
  int get totalXp => _totalXp;
  set totalXp(int value) {
    _totalXp = value;
    notifyListeners();
  }

  BadgeLevel get currentLevel => badgeLevelFor(_totalXp);
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

      if (data != null) {
        // Carica badge sbloccati
        if (data.containsKey('unlocked_badges')) {
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
        }

        // Carica contatori
        if (data.containsKey('badge_counters')) {
          final countersMap = data['badge_counters'] as Map<String, dynamic>;
          _counters = countersMap.map((k, v) => MapEntry(k, (v as num).toInt()));
        }

        // Carica XP totali per il livello
        _totalXp = (data['xp_total'] as num?)?.toInt() ?? 0;

        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading badges: $e");
    }
  }

  /// Incrementa un contatore e controlla se nuovi badge sono sbloccabili.
  Future<void> _incrementCounter(String key, {int amount = 1}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _counters[key] = (_counters[key] ?? 0) + amount;
    final newValue = _counters[key]!;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'badge_counters.$key': newValue,
      });
    } catch (e) {
      debugPrint("Error incrementing counter $key: $e");
    }

    // Controlla badge progressivi collegati a questo contatore
    await _checkCounterBadges(key, newValue);
  }

  /// Imposta un contatore a un valore fisso (per streak che si resettano).
  Future<void> _setCounter(String key, int value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _counters[key] = value;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'badge_counters.$key': value,
      });
    } catch (e) {
      debugPrint("Error setting counter $key: $e");
    }

    await _checkCounterBadges(key, value);
  }

  /// Controlla tutti i badge che dipendono da un contatore specifico.
  Future<void> _checkCounterBadges(String counterKey, int newValue) async {
    for (final badge in _badges) {
      if (badge.counterKey == counterKey &&
          !badge.isUnlocked &&
          newValue >= badge.requiredCount) {
        await unlockBadge(badge.id);
      }
    }
  }

  /// Restituisce il progresso corrente per un badge progressivo (0.0 - 1.0).
  double getProgress(BadgeModel badge) {
    if (badge.isUnlocked) return 1.0;
    if (badge.counterKey == null) return 0.0;
    final current = _counters[badge.counterKey] ?? 0;
    return (current / badge.requiredCount).clamp(0.0, 1.0);
  }

  /// Restituisce il valore corrente di un contatore.
  int getCounterValue(String? counterKey) {
    if (counterKey == null) return 0;
    return _counters[counterKey] ?? 0;
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

  // ──────────────────────────────────────────────
  //  TRIGGER METHODS
  // ──────────────────────────────────────────────

  Future<void> checkLoginStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await unlockBadge('first_login');

    // Controlla badge festivo
    final now = DateTime.now();
    if (now.month == 12 && now.day == 25) {
      await unlockBadge('holiday_spirit');
    }

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

      // Aggiorna contatore streak per badge progressivi
      await _setCounter('streak_days', newStreak);

    } catch (e) {
      debugPrint('Errore checkLoginStreak: $e');
    }
  }

  /// Streak corrente letto dai contatori locali.
  int get currentStreak => _counters['streak_days'] ?? 0;

  Future<void> onWeightLogged() async {
    await _incrementCounter('weight_logs');
  }

  Future<void> checkDailyGoals(int planned, int consumed) async {
    if (planned > 0 && consumed == planned) {
      await _incrementCounter('meals_complete_days');

      // Controlla badge nottambulo
      final now = DateTime.now();
      if (now.hour >= 0 && now.hour < 5) {
        await unlockBadge('night_owl');
      }
    }
  }

  Future<void> onShoppingListShared() async {
    await _incrementCounter('shopping_shares');
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

  // ── Feature-discovery triggers ───────────────

  Future<void> onCookingTimerUsed() async {
    await unlockBadge('cooking_timer_used');
  }

  Future<void> onAiSuggestionsUsed() async {
    await unlockBadge('ai_explorer');
  }

  Future<void> onChatMessageSent() async {
    await unlockBadge('first_chat_message');
  }

  Future<void> onScaleConnected() async {
    await unlockBadge('scale_connected');
  }

  Future<void> onPantryItemAdded(int totalItems) async {
    // Imposta il contatore al valore totale attuale
    await _setCounter('pantry_items_added', totalItems);
  }

  Future<void> onStatsViewed() async {
    await _incrementCounter('stats_views');
  }

  Future<void> onMealSwapped() async {
    await _incrementCounter('meal_swaps');
  }

  // ── Weight-goal triggers ─────────────────────

  Future<void> checkWeightGoalProgress(
    double currentWeight,
    double startWeight,
    double targetWeight,
  ) async {
    if (startWeight == targetWeight) return;

    final totalChange = (startWeight - targetWeight).abs();
    final currentChange = (startWeight - currentWeight).abs();
    final percentage = (currentChange / totalChange * 100).clamp(0.0, 100.0);

    // Verifica direzione corretta (perdita o guadagno)
    final isCorrectDirection = startWeight > targetWeight
        ? currentWeight <= startWeight
        : currentWeight >= startWeight;

    if (!isCorrectDirection) return;

    if (percentage >= 25) await unlockBadge('weight_goal_25');
    if (percentage >= 50) await unlockBadge('weight_goal_50');
    if (percentage >= 100) await unlockBadge('weight_goal_100');
  }

  Future<void> checkPerfectWeek(int consecutivePerfectDays) async {
    if (consecutivePerfectDays >= 7) {
      await unlockBadge('perfect_week');
    }
  }
}
