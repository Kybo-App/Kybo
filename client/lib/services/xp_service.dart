// Servizio XP: gestisce punti esperienza giornalieri e totali, livelli e storico su Firestore.
// addXp — aggiunge XP con motivo, aggiorna Firestore e notifica i listener.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/time_helper.dart';
import 'badge_service.dart';

/// Costanti XP per ogni azione.
class XpRewards {
  static const int mealConsumed = 10;
  static const int weightLogged = 15;
  static const int allMealsComplete = 50;
  static const int streakDay = 5;
  static const int shoppingListUsed = 10;
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
  String _todayDate = '';
  List<XpEntry> _recentEntries = [];
  bool _isLoaded = false;

  int get totalXp => _totalXp;
  int get todayXp => _todayXp;
  List<XpEntry> get recentEntries => List.unmodifiable(_recentEntries);
  bool get isLoaded => _isLoaded;

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
        _todayDate = todayStr;

        // Carica ultime entries di oggi
        await _loadRecentEntries();
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading XP: $e");
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Aggiunge XP e salva su Firestore.
  Future<void> addXp(int amount, String reason) async {
    if (amount <= 0) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final todayStr = _getTodayString();

    // Reset giornaliero se la data è cambiata
    if (_todayDate != todayStr) {
      _todayXp = 0;
      _todayDate = todayStr;
      _recentEntries.clear();
    }

    _totalXp += amount;
    _todayXp += amount;

    final entry = XpEntry(
      amount: amount,
      reason: reason,
      timestamp: DateTime.now(),
    );
    _recentEntries.insert(0, entry);
    if (_recentEntries.length > 20) {
      _recentEntries = _recentEntries.sublist(0, 20);
    }

    notifyListeners();

    try {
      // Aggiorna totali
      await _firestore.collection('users').doc(user.uid).update({
        'xp_total': _totalXp,
        'xp_today': _todayXp,
        'xp_today_date': todayStr,
      });

      // Salva entry nello storico
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_history')
          .doc(todayStr)
          .set({
        'entries': FieldValue.arrayUnion([entry.toJson()]),
      }, SetOptions(merge: true));

      debugPrint("⭐ +$amount XP ($reason) | Totale: $_totalXp | Oggi: $_todayXp");
    } catch (e) {
      debugPrint("Error saving XP: $e");
    }
  }

  /// Sottrae XP per riscatto premio. Aggiorna locale + Firestore.
  Future<bool> spendXp(int amount, String reason) async {
    if (amount <= 0) return false;
    if (_totalXp < amount) return false;

    final user = _auth.currentUser;
    if (user == null) return false;

    _totalXp -= amount;
    notifyListeners();

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'xp_total': _totalXp,
      });

      debugPrint("💸 -$amount XP ($reason) | Totale: $_totalXp");
      return true;
    } catch (e) {
      // Rollback locale in caso di errore
      _totalXp += amount;
      notifyListeners();
      debugPrint("Error spending XP: $e");
      return false;
    }
  }

  /// Carica le entries recenti di oggi da Firestore.
  Future<void> _loadRecentEntries() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final todayStr = _getTodayString();
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_history')
          .doc(todayStr)
          .get();

      if (doc.exists && doc.data() != null) {
        final entries = doc.data()!['entries'] as List<dynamic>?;
        if (entries != null) {
          _recentEntries = entries
              .map((e) => XpEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      }
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
