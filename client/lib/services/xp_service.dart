// Servizio XP: gestisce punti esperienza giornalieri e totali, livelli e storico.
// addXp — chiede al server di assegnare XP per un evento (nessuna scrittura diretta
// di xp_total: il client non è più autoritativo, vedi audit XP1/SRV-RW1).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/time_helper.dart';
import 'api_client.dart';
import 'badge_service.dart';

/// Costanti XP per ogni azione.
class XpRewards {
  static const int mealConsumed = 10;
  static const int weightLogged = 15;
  static const int allMealsComplete = 50;
  static const int badgeUnlocked = 25;
  static const int challengeCompleted = 20;
  static const int allChallengesBonus = 30;
}

class XpEntry {
  final int amount;
  final String reason;
  final DateTime timestamp;

  XpEntry({
    required this.amount,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'reason': reason,
    'ts': timestamp.toIso8601String(),
  };

  factory XpEntry.fromJson(Map<String, dynamic> json) => XpEntry(
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    reason: json['reason'] as String? ?? '',
    timestamp: DateTime.tryParse(json['ts'] ?? '') ?? DateTime.now(),
  );
}

class XpService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _totalXp = 0;
  int _todayXp = 0;
  List<XpEntry> _recentEntries = [];

  int get totalXp => _totalXp;
  int get todayXp => _todayXp;
  List<XpEntry> get recentEntries => List.unmodifiable(_recentEntries);

  /// Livello corrente basato su XP.
  BadgeLevel get currentLevel => badgeLevelFor(_totalXp);

  /// Progresso verso il prossimo livello (0.0 - 1.0).
  double get progressToNextLevel {
    final level = currentLevel;
    final levelIndex = kBadgeLevels.indexOf(level);
    if (levelIndex == kBadgeLevels.length - 1) return 1.0;

    final xpInLevel = _totalXp - level.minXp;
    final xpNeeded = level.maxXp - level.minXp;
    return xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 1.0;
  }

  /// XP necessari per il prossimo livello.
  int get xpForNextLevel {
    final level = currentLevel;
    final levelIndex = kBadgeLevels.indexOf(level);
    if (levelIndex == kBadgeLevels.length - 1) return 0;
    return level.maxXp - _totalXp;
  }

  /// Indice numerico del livello corrente (1-indexed).
  int get levelNumber {
    final level = currentLevel;
    return kBadgeLevels.indexOf(level) + 1;
  }

  /// Carica XP da Firestore.
  Future<void> loadXp() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null) {
        _totalXp = (data['xp_total'] as num?)?.toInt() ?? 0;

        final todayStr = _getTodayString();
        if (data['xp_today_date'] == todayStr) {
          _todayXp = (data['xp_today'] as num?)?.toInt() ?? 0;
        } else {
          _todayXp = 0;
        }

        // Carica ultime entries di oggi
        await _loadRecentEntries();
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading XP: $e");
      notifyListeners();
    }
  }

  /// Eventi XP che il server sa assegnare (importo deciso server-side).
  static const Set<String> _validEvents = {
    'meal_consumed',
    'all_meals_complete',
    'weight_logged',
  };

  /// Richiede al server di assegnare XP per un evento verificato.
  /// Non scrive più xp_total direttamente: il client non è autoritativo
  /// sull'economia XP (vedi audit XP1/SRV-RW1) — l'importo e il cap
  /// giornaliero sono decisi dal server.
  Future<void> addXp(String reason) async {
    if (!_validEvents.contains(reason)) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final previousTotal = _totalXp;

    try {
      final data = await ApiClient().post(
        '/gamification/xp/event',
        body: {'event_type': reason},
      ) as Map<String, dynamic>;

      _applyServerXp(data, reason: reason, previousTotal: previousTotal);
      debugPrint("⭐ XP evento '$reason' | Totale: $_totalXp | Oggi: $_todayXp");
    } catch (e) {
      debugPrint("Error awarding XP ($reason): $e");
    }
  }

  /// Allinea lo stato locale a un totale XP autorevole ritornato dal server
  /// (es. dopo un riscatto premio, vedi rewards_screen.dart). Non scrive su
  /// Firestore: il server ha già applicato la modifica.
  void setAuthoritativeXp(int newTotal, {String reason = 'reward_claimed'}) {
    final delta = newTotal - _totalXp;
    _totalXp = newTotal;
    if (delta != 0) {
      _recentEntries.insert(0, XpEntry(amount: delta, reason: reason, timestamp: DateTime.now()));
      if (_recentEntries.length > 20) {
        _recentEntries = _recentEntries.sublist(0, 20);
      }
    }
    notifyListeners();
    debugPrint("💸 XP aggiornato da server ($reason) | Totale: $_totalXp");
  }

  void _applyServerXp(Map<String, dynamic> data, {required String reason, required int previousTotal}) {
    _totalXp = (data['xp_total'] as num?)?.toInt() ?? _totalXp;
    _todayXp = (data['xp_today'] as num?)?.toInt() ?? _todayXp;

    final delta = _totalXp - previousTotal;
    if (delta > 0) {
      _recentEntries.insert(0, XpEntry(amount: delta, reason: reason, timestamp: DateTime.now()));
      if (_recentEntries.length > 20) {
        _recentEntries = _recentEntries.sublist(0, 20);
      }
    }

    notifyListeners();
  }

  /// Carica le entries XP recenti (di oggi) dallo storico scritto dal server.
  Future<void> _loadRecentEntries() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_history')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(todayMidnight))
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();

      _recentEntries = snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['created_at'];
        final timestamp = ts is Timestamp ? ts.toDate() : DateTime.now();
        return XpEntry(
          amount: (data['amount'] as num?)?.toInt() ?? 0,
          reason: data['reason'] as String? ?? '',
          timestamp: timestamp,
        );
      }).toList();
    } catch (e) {
      debugPrint("Error loading XP entries: $e");
    }
  }

  String _getTodayString() {
    return TimeHelper().getLogicalTodayString();
  }

  /// Descrizione leggibile dell'azione XP.
  static String reasonLabel(String reason) {
    switch (reason) {
      case 'meal_consumed':
        return 'Pasto consumato';
      case 'all_meals_complete':
        return 'Tutti i pasti completati';
      case 'weight_logged':
        return 'Peso registrato';
      case 'badge_unlocked':
        return 'Badge sbloccato';
      case 'challenge_completed':
        return 'Sfida completata';
      case 'all_challenges_bonus':
        return 'Bonus sfide completate';
      case 'streak_bonus':
        return 'Bonus streak';
      case 'shopping_list':
        return 'Lista spesa usata';
      case 'reward_claimed':
        return 'Premio riscattato';
      default:
        return reason;
    }
  }
}
