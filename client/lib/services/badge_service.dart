// Gestisce il sistema di badge, livelli e contatori utente: sblocco, persistenza
// e streak di accesso. Contatori/sblocchi/streak sono scritti dal server
// (Admin SDK) su chiamata del client, non più direttamente su Firestore —
// vedi audit SV2 (i campi non-whitelisted venivano negati in silenzio, e
// unlocked_badges era comunque forgiabile dal client).
// Supporta badge progressivi con contatori, feature-discovery, badge segreti e integrazione XP.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';
import 'api_client.dart';

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

  /// Incrementa un contatore lato server (whitelist di chiavi valide) e
  /// sblocca automaticamente i badge progressivi collegati (SV2).
  Future<void> _incrementCounter(String key) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final data = await ApiClient().post(
        '/gamification/badge/counter',
        body: {'key': key, 'mode': 'increment'},
      ) as Map<String, dynamic>;
      _applyCounterResult(key, data);
    } catch (e) {
      debugPrint("Error incrementing counter $key: $e");
    }
  }

  /// Imposta un contatore a un valore fisso lato server (per totali noti
  /// solo al client, es. numero articoli in dispensa).
  Future<void> _setCounter(String key, int value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final data = await ApiClient().post(
        '/gamification/badge/counter',
        body: {'key': key, 'mode': 'set', 'value': value},
      ) as Map<String, dynamic>;
      _applyCounterResult(key, data);
    } catch (e) {
      debugPrint("Error setting counter $key: $e");
    }
  }

  void _applyCounterResult(String key, Map<String, dynamic> data) {
    final newValue = (data['value'] as num?)?.toInt();
    if (newValue != null) {
      _counters[key] = newValue;
    }
    final unlocked = (data['unlocked'] as List<dynamic>? ?? []);
    for (final badgeId in unlocked) {
      _markUnlockedLocally(badgeId.toString());
    }
    notifyListeners();
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

  /// Sblocca un badge lato server (idempotente, solo ID validati — SV2).
  /// Applica lo stato locale solo dopo la conferma del server, per evitare
  /// di mostrare una celebrazione per uno sblocco poi rifiutato.
  Future<void> unlockBadge(String badgeId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final badgeIndex = _badges.indexWhere((b) => b.id == badgeId);
    if (badgeIndex == -1 || _badges[badgeIndex].isUnlocked) return;

    try {
      final data = await ApiClient().post(
        '/gamification/badge/unlock',
        body: {'badge_id': badgeId},
      ) as Map<String, dynamic>;

      if (data['newly_unlocked'] == true) {
        _markUnlockedLocally(badgeId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error unlocking badge: $e");
    }
  }

  /// Applica localmente uno sblocco già confermato dal server.
  void _markUnlockedLocally(String badgeId) {
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

    debugPrint("🏆 Badge sbloccato: ${badge.title} | Livello: ${levelAfter.emoji} ${levelAfter.name}");
  }

  // ──────────────────────────────────────────────
  //  TRIGGER METHODS
  // ──────────────────────────────────────────────

  /// Calcola/aggiorna lo streak di accesso interamente lato server (usa la
  /// data del server, non manipolabile cambiando l'orologio del device).
  /// Sblocca anche first_login/holiday_spirit/streak_* in un'unica chiamata.
  Future<void> checkLoginStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final data = await ApiClient().post('/gamification/streak/checkin') as Map<String, dynamic>;

      final newStreak = (data['streak_count'] as num?)?.toInt();
      if (newStreak != null) {
        _counters['streak_days'] = newStreak;
      }

      final unlocked = (data['unlocked'] as List<dynamic>? ?? []);
      for (final badgeId in unlocked) {
        _markUnlockedLocally(badgeId.toString());
      }
      if (unlocked.isNotEmpty) {
        notifyListeners();
      }
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

  // [DEAD 2026-05-30] checkWeeklyChallenge — trigger mai chiamato. Il
  // badge 'weekly_challenge' resta non sbloccabile finché un caller non
  // invoca questo metodo passando i consumi della settimana.
  // Future<void> checkWeeklyChallenge(Map<String, dynamic> consumptionData) async {
  //   int daysWithEnoughMeals = 0;
  //   for (final entry in consumptionData.entries) {
  //     final dayCount = entry.value;
  //     if (dayCount is int && dayCount >= 3) {
  //       daysWithEnoughMeals++;
  //     }
  //   }
  //   if (daysWithEnoughMeals >= 5) {
  //     await unlockBadge('weekly_challenge');
  //   }
  // }

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

  // [DEAD 2026-05-30] onMealSwapped — trigger mai chiamato. Il badge
  // segreto 'swap_master' non è raggiungibile finché un caller (es. dentro
  // diet_provider.swapMeal) invoca questo metodo.
  // Future<void> onMealSwapped() async {
  //   await _incrementCounter('meal_swaps');
  // }

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

  // [DEAD 2026-05-30] checkPerfectWeek — trigger mai chiamato. Il badge
  // 'perfect_week' non è raggiungibile finché un caller (es. tracking
  // service quando aggrega la settimana) invoca questo metodo.
  // Future<void> checkPerfectWeek(int consecutivePerfectDays) async {
  //   if (consecutivePerfectDays >= 7) {
  //     await unlockBadge('perfect_week');
  //   }
  // }
}
