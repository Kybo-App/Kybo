// Servizio sfide giornaliere: mostra 3 missioni al giorno, il completamento
// e l'XP assegnato sono autoritativi lato server (vedi audit SV1) — il
// client non scrive più su Firestore per queste sfide.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/time_helper.dart';
import 'api_client.dart';
import 'xp_service.dart';

class ChallengeModel {
  final String id;
  final String baseId;
  final String title;
  final String description;
  final IconData icon;
  final int xpReward;
  final ChallengeType type;
  bool isCompleted;

  ChallengeModel({
    required this.id,
    required this.baseId,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.type,
    this.isCompleted = false,
  });
}

enum ChallengeType {
  meals,
  weight,
  explore,
  social,
}

class ChallengeService extends ChangeNotifier {
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

  /// Pool di sfide possibili (contenuto display: titolo/descrizione/icona).
  /// L'importo XP e la selezione giornaliera autoritativi sono ricalcolati
  /// dal server con lo stesso algoritmo (vedi gamification.py).
  static final List<ChallengeModel> _challengePool = [
    ChallengeModel(
      id: 'complete_2_meals', baseId: 'complete_2_meals',
      title: 'Pasti del Giorno',
      description: 'Completa almeno 2 pasti oggi.',
      icon: Icons.restaurant_rounded,
      xpReward: 20,
      type: ChallengeType.meals,
    ),
    ChallengeModel(
      id: 'complete_all_meals', baseId: 'complete_all_meals',
      title: 'Giornata Completa',
      description: 'Completa tutti i pasti di oggi.',
      icon: Icons.check_circle_rounded,
      xpReward: 30,
      type: ChallengeType.meals,
    ),
    ChallengeModel(
      id: 'log_weight', baseId: 'log_weight',
      title: 'Controllo Peso',
      description: 'Registra il tuo peso oggi.',
      icon: Icons.monitor_weight_rounded,
      xpReward: 15,
      type: ChallengeType.weight,
    ),
    ChallengeModel(
      id: 'visit_stats', baseId: 'visit_stats',
      title: 'Analisti dei Dati',
      description: 'Visita la sezione statistiche.',
      icon: Icons.bar_chart_rounded,
      xpReward: 10,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'use_timer', baseId: 'use_timer',
      title: 'Tempo di Cottura',
      description: 'Usa il timer di cottura.',
      icon: Icons.timer_rounded,
      xpReward: 15,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'share_list', baseId: 'share_list',
      title: 'Condividi la Lista',
      description: 'Condividi la lista della spesa.',
      icon: Icons.share_rounded,
      xpReward: 20,
      type: ChallengeType.social,
    ),
    ChallengeModel(
      id: 'add_pantry', baseId: 'add_pantry',
      title: 'Rifornimento',
      description: 'Aggiungi un articolo alla dispensa.',
      icon: Icons.add_shopping_cart_rounded,
      xpReward: 10,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'use_ai', baseId: 'use_ai',
      title: 'Chiedi all\'AI',
      description: 'Chiedi suggerimenti all\'intelligenza artificiale.',
      icon: Icons.auto_awesome_rounded,
      xpReward: 15,
      type: ChallengeType.explore,
    ),
    ChallengeModel(
      id: 'complete_1_meal', baseId: 'complete_1_meal',
      title: 'Primo Pasto',
      description: 'Completa almeno un pasto oggi.',
      icon: Icons.lunch_dining_rounded,
      xpReward: 10,
      type: ChallengeType.meals,
    ),
  ];

  ChallengeModel? _poolTemplate(String baseId) {
    for (final c in _challengePool) {
      if (c.baseId == baseId) return c;
    }
    return null;
  }

  /// Carica le sfide di oggi dal server (autoritativo per XP e stato di
  /// completamento). Se la rete non è disponibile, genera un fallback
  /// locale solo per mostrare qualcosa in UI: il completamento resta
  /// comunque delegato al server (vedi completeChallenge), quindi un uso
  /// offline non assegna XP finché la connessione non torna.
  Future<void> loadOrGenerateDailyChallenges() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final todayStr = _getTodayString();
    if (_currentDate == todayStr && _dailyChallenges.isNotEmpty) return;

    try {
      final data = await ApiClient().get('/gamification/challenges/today') as Map<String, dynamic>;
      final date = data['date'] as String? ?? todayStr;
      final challenges = (data['challenges'] as List<dynamic>? ?? []);

      _dailyChallenges = challenges.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final baseId = map['base_id'] as String? ?? '';
        final template = _poolTemplate(baseId);
        return ChallengeModel(
          id: map['id'] as String? ?? '',
          baseId: baseId,
          title: template?.title ?? baseId,
          description: template?.description ?? '',
          icon: template?.icon ?? Icons.star_rounded,
          xpReward: (map['xp_reward'] as num?)?.toInt() ?? template?.xpReward ?? 0,
          type: template?.type ?? ChallengeType.explore,
          isCompleted: map['is_completed'] == true,
        );
      }).toList();
      _challengeStreak = (data['challenge_streak'] as num?)?.toInt() ?? 0;
      _currentDate = date;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading challenges: $e");
      _dailyChallenges = _generateChallenges(todayStr);
      _currentDate = todayStr;
      notifyListeners();
    }
  }

  /// Fallback locale usato solo se il server non è raggiungibile.
  List<ChallengeModel> _generateChallenges(String dateStr) {
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;

    final pool = List<ChallengeModel>.from(_challengePool);
    final selected = <ChallengeModel>[];
    final usedTypes = <ChallengeType>{};

    for (int i = 0; i < 3 && pool.isNotEmpty; i++) {
      final index = (dayOfYear * 7 + i * 13 + dayOfYear ~/ 3) % pool.length;
      final challenge = pool[index];

      if (usedTypes.where((t) => t == challenge.type).length >= 2 && pool.length > 1) {
        pool.removeAt(index);
        i--;
        continue;
      }

      selected.add(ChallengeModel(
        id: '${challenge.baseId}_$dateStr',
        baseId: challenge.baseId,
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

  /// Completa una sfida lato server (idempotente, XP a importo fisso
  /// server-side) — sostituisce la vecchia scrittura diretta su Firestore
  /// che veniva negata dalle rules e permetteva di ri-guadagnare XP a ogni
  /// riavvio dell'app (SV1).
  Future<void> completeChallenge(String challengeId) async {
    final index = _dailyChallenges.indexWhere((c) => c.id == challengeId);
    if (index == -1 || _dailyChallenges[index].isCompleted) return;

    try {
      final data = await ApiClient().post(
        '/gamification/challenge/complete',
        body: {'challenge_id': challengeId},
      ) as Map<String, dynamic>;

      final completedIds = (data['completed_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();

      for (final c in _dailyChallenges) {
        c.isCompleted = completedIds.contains(c.baseId);
      }
      _challengeStreak = (data['challenge_streak'] as num?)?.toInt() ?? _challengeStreak;

      final newXpTotal = (data['xp_total'] as num?)?.toInt();
      if (newXpTotal != null) {
        _xpService.setAuthoritativeXp(newXpTotal, reason: 'challenge_completed');
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error completing challenge: $e");
    }
  }

  /// Controlla se una sfida è stata soddisfatta automaticamente.
  /// Chiamato dai vari service/provider quando l'utente compie un'azione.
  Future<void> checkAutoComplete(String challengeBaseId) async {
    for (final challenge in _dailyChallenges) {
      if (!challenge.isCompleted && challenge.baseId == challengeBaseId) {
        await completeChallenge(challenge.id);
        break;
      }
    }
  }

  String _getTodayString() {
    return TimeHelper().getLogicalTodayString();
  }
}
