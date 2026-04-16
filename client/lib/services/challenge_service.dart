// Servizio sfide giornaliere: genera 3 missioni al giorno, traccia il completamento e assegna XP.
// Le sfide si resettano a mezzanotte locale.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/time_helper.dart';
import 'xp_service.dart';

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int xpReward;
  final ChallengeType type;
  bool isCompleted;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.type,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon_code': icon.codePoint,
    'xp_reward': xpReward,
    'type': type.name,
    'is_completed': isCompleted,
  };

  factory ChallengeModel.fromJson(Map<String, dynamic> json) => ChallengeModel(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    icon: IconData(
      json['icon_code'] as int? ?? Icons.star.codePoint,
      fontFamily: 'MaterialIcons',
    ),
    xpReward: (json['xp_reward'] as num?)?.toInt() ?? 10,
    type: ChallengeType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ChallengeType.explore,
    ),
    isCompleted: json['is_completed'] ?? false,
  );
}

enum ChallengeType {
  meals,
  weight,
  explore,
  social,
}

class ChallengeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final XpService _xpService;

  List<ChallengeModel> _dailyChallenges = [];
  String _currentDate = '';
  int _challengeStreak = 0;

  List<ChallengeModel> get dailyChallenges => _dailyChallenges;
  int get completedCount => _dailyChallenges.where((c) => c.isCompleted).length;
  int get totalCount => _dailyChallenges.length;
  bool get allCompleted => totalCount > 0 && completedCount == totalCount;
  int get challengeStreak => _challengeStreak;

  ChallengeService(this._xpService);

  /// Pool di sfide possibili.
  static final List<ChallengeModel> _challengePool = [
    ChallengeModel(
      id: 'complete_2_meals',
      title: 'Pasti del Giorno',
      description: 'Completa almeno 2 pasti oggi.',
      icon: Icons.restaurant_rounded,
      xpReward: 20,
      type: ChallengeType.meals,
    ),
    ChallengeModel(
      id: 'complete_all_meals',
      title: 'Giornata Completa',
      description: 'Completa tutti i pasti di oggi.',
      icon: Icons.check_circle_rounded,
      xpReward: 30,
      type: ChallengeType.meals,
    ),
    ChallengeModel(
      id: 'log_weight',
      title: 'Controllo Peso',
      description: 'Registra il tuo peso oggi.',
      icon: Icons.monitor_weight_rounded,
      xpReward: 15,
      type: ChallengeType.weight,
    ),
    ChallengeModel(
      id: 'visit_stats',
      title: 'Analisti dei Dati',
      description: 'Visita la sezione statistiche.',
      icon: Icons.bar_chart_rounded,
      xpReward: 10,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'use_timer',
      title: 'Tempo di Cottura',
      description: 'Usa il timer di cottura.',
      icon: Icons.timer_rounded,
      xpReward: 15,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'share_list',
      title: 'Condividi la Lista',
      description: 'Condividi la lista della spesa.',
      icon: Icons.share_rounded,
      xpReward: 20,
      type: ChallengeType.social,
    ),
    ChallengeModel(
      id: 'add_pantry',
      title: 'Rifornimento',
      description: 'Aggiungi un articolo alla dispensa.',
      icon: Icons.add_shopping_cart_rounded,
      xpReward: 10,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'use_ai',
      title: 'Chiedi all\'AI',
      description: 'Chiedi suggerimenti all\'intelligenza artificiale.',
      icon: Icons.auto_awesome_rounded,
      xpReward: 15,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'complete_1_meal',
      title: 'Primo Pasto',
      description: 'Completa almeno un pasto oggi.',
      icon: Icons.lunch_dining_rounded,
      xpReward: 10,
      type: ChallengeType.meals,
    ),
  ];

  /// Genera o carica le sfide del giorno.
  Future<void> loadOrGenerateDailyChallenges() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final todayStr = _getTodayString();

    // Se già caricate per oggi, skip
    if (_currentDate == todayStr && _dailyChallenges.isNotEmpty) return;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('challenges')
          .doc(todayStr);

      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        // Carica sfide esistenti
        final data = doc.data()!;
        final challengesList = data['challenges'] as List<dynamic>? ?? [];
        _dailyChallenges = challengesList
            .map((c) => ChallengeModel.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        _challengeStreak = (data['challenge_streak'] as num?)?.toInt() ?? 0;
      } else {
        // Genera nuove sfide
        _dailyChallenges = _generateChallenges(todayStr);

        // Carica streak dalle sfide precedenti
        await _loadChallengeStreak();

        // Salva su Firestore
        await docRef.set({
          'challenges': _dailyChallenges.map((c) => c.toJson()).toList(),
          'date': todayStr,
          'challenge_streak': _challengeStreak,
        });
      }

      _currentDate = todayStr;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading challenges: $e");
      // Genera comunque le sfide localmente
      _dailyChallenges = _generateChallenges(todayStr);
      _currentDate = todayStr;
      notifyListeners();
    }
  }

  /// Genera 3 sfide pseudo-casuali basate sul giorno dell'anno.
  List<ChallengeModel> _generateChallenges(String dateStr) {
    // Usa il giorno dell'anno come seed per pseudo-casualità deterministica
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;

    final pool = List<ChallengeModel>.from(_challengePool);

    // Seleziona 3 sfide diverse
    final selected = <ChallengeModel>[];
    final usedTypes = <ChallengeType>{};

    // Cerca di ottenere variety di tipo
    for (int i = 0; i < 3 && pool.isNotEmpty; i++) {
      final index = (dayOfYear * 7 + i * 13 + dayOfYear ~/ 3) % pool.length;
      final challenge = pool[index];

      // Se abbiamo già 2 sfide dello stesso tipo, salta
      if (usedTypes.where((t) => t == challenge.type).length >= 2 && pool.length > 1) {
        pool.removeAt(index);
        i--;
        continue;
      }

      selected.add(ChallengeModel(
        id: '${challenge.id}_$dateStr',
        title: challenge.title,
        description: challenge.description,
        icon: challenge.icon,
        xpReward: challenge.xpReward,
        type: challenge.type,
      ));
      usedTypes.add(challenge.type);
      pool.removeAt(index);
    }

    return selected;
  }

  /// Completa una sfida e assegna XP.
  Future<void> completeChallenge(String challengeId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final challenge = _dailyChallenges.firstWhere(
      (c) => c.id == challengeId,
      orElse: () => ChallengeModel(
        id: '', title: '', description: '', icon: Icons.star,
        xpReward: 0, type: ChallengeType.explore,
      ),
    );

    if (challenge.id.isEmpty || challenge.isCompleted) return;

    challenge.isCompleted = true;

    // Assegna XP per la sfida
    await _xpService.addXp(challenge.xpReward, 'challenge_completed');

    // Se tutte completate, bonus XP
    if (allCompleted) {
      await _xpService.addXp(XpRewards.allChallengesBonus, 'all_challenges_bonus');
      _challengeStreak++;
    }

    notifyListeners();

    // Salva stato su Firestore
    try {
      final todayStr = _getTodayString();
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('challenges')
          .doc(todayStr)
          .update({
        'challenges': _dailyChallenges.map((c) => c.toJson()).toList(),
        'challenge_streak': _challengeStreak,
      });
    } catch (e) {
      debugPrint("Error completing challenge: $e");
    }
  }

  /// Controlla se una sfida è stata soddisfatta automaticamente.
  /// Chiamato dai vari service/provider quando l'utente compie un'azione.
  Future<void> checkAutoComplete(String challengeBaseId) async {
    for (final challenge in _dailyChallenges) {
      if (!challenge.isCompleted && challenge.id.startsWith(challengeBaseId)) {
        await completeChallenge(challenge.id);
        break;
      }
    }
  }

  Future<void> _loadChallengeStreak() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Controlla se ieri è stato completato tutto, usando la data LOGICA
      final yesterday = TimeHelper().getLogicalToday().subtract(const Duration(days: 1));
      final yesterdayStr = TimeHelper().getLogicalDateString(yesterday);

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('challenges')
          .doc(yesterdayStr)
          .get();

      if (doc.exists && doc.data() != null) {
        final challenges = (doc.data()!['challenges'] as List<dynamic>? ?? []);
        final allDone = challenges.every((c) => c['is_completed'] == true);
        if (allDone && challenges.isNotEmpty) {
          _challengeStreak = (doc.data()!['challenge_streak'] as num?)?.toInt() ?? 0;
        } else {
          _challengeStreak = 0;
        }
      } else {
        _challengeStreak = 0;
      }
    } catch (e) {
      debugPrint("Error loading challenge streak: $e");
      _challengeStreak = 0;
    }
  }

  String _getTodayString() {
    return TimeHelper().getLogicalTodayString();
  }
}
