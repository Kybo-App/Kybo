// Provider per gestire la scheda allenamento assegnata all'utente.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/workout_model.dart';
import '../services/api_client.dart';

class WorkoutProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  WorkoutPlan? _plan;
  bool _isLoading = true;
  // [UX R2/R5] Prima un errore di rete lasciava _plan null in silenzio e la
  // schermata mostrava "Nessuna scheda assegnata" — messaggio FALSO su un
  // errore. Ora la view distingue errore (con retry) da "davvero senza piano".
  Object? _error;

  WorkoutPlan? get plan => _plan;
  bool get isLoading => _isLoading;
  bool get hasPlan => _plan != null;
  Object? get error => _error;

  Future<void> loadPlan() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final data = await _api.get('/workouts/my-plan') as Map<String, dynamic>;
      final planData = data['plan'];
      if (planData != null) {
        _plan = WorkoutPlan.fromMap(Map<String, dynamic>.from(planData));
      } else {
        _plan = null;
      }
    } catch (e) {
      debugPrint("Error loading workout plan: $e");
      _error = e;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Storico schede allenamento assegnate all'utente.
  /// Mirror del pattern diete: ogni scheda assegnata resta consultabile anche
  /// dopo che il PT ne carica una nuova.
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    if (FirebaseAuth.instance.currentUser == null) return [];

    try {
      final data = await _api.get('/workouts/history') as Map<String, dynamic>;
      final list = (data['history'] as List? ?? []);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Segna l'allenamento di oggi come completato. Ritorna gli XP guadagnati.
  /// Lancia eccezione se già completato oggi (409) o nessuna scheda (404).
  Future<int> completeDay() async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Non autenticato');
    }

    try {
      final data = await _api.post('/workouts/complete-day') as Map<String, dynamic>;
      return (data['xp_awarded'] as num).toInt();
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw Exception('Hai già completato l\'allenamento oggi!');
      }
      throw Exception(e.message);
    }
  }

  /// Invia il feedback emoji per l'allenamento di oggi. Fire-and-forget:
  /// gli errori vengono solo loggati per non bloccare l'utente.
  Future<void> submitFeedback(String rating) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) return;
      await _api.post('/workouts/feedback', body: {'rating': rating});
    } catch (_) {
      // silenzioso: il feedback è opzionale
    }
  }
}
