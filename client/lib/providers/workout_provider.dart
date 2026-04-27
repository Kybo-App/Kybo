// Provider per gestire la scheda allenamento assegnata all'utente.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/workout_model.dart';
import '../core/env.dart';

class WorkoutProvider extends ChangeNotifier {
  WorkoutPlan? _plan;
  bool _isLoading = true;
  String? _error;

  WorkoutPlan? get plan => _plan;
  bool get isLoading => _isLoading;
  bool get hasPlan => _plan != null;
  String? get error => _error;

  Future<void> loadPlan() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${Env.apiUrl}/workouts/my-plan'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final planData = data['plan'];
        if (planData != null) {
          _plan = WorkoutPlan.fromMap(Map<String, dynamic>.from(planData));
        } else {
          _plan = null;
        }
      } else {
        _error = 'Errore ${response.statusCode}';
      }
    } catch (e) {
      debugPrint("Error loading workout plan: $e");
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Storico schede allenamento assegnate all'utente.
  /// Mirror del pattern diete: ogni scheda assegnata resta consultabile anche
  /// dopo che il PT ne carica una nuova.
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('${Env.apiUrl}/workouts/history'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final list = (data['history'] as List? ?? []);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Segna l'allenamento di oggi come completato. Ritorna gli XP guadagnati.
  /// Lancia eccezione se già completato oggi (409) o nessuna scheda (404).
  Future<int> completeDay() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Non autenticato');

    final response = await http.post(
      Uri.parse('${Env.apiUrl}/workouts/complete-day'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['xp_awarded'] as num).toInt();
    } else if (response.statusCode == 409) {
      throw Exception('Hai già completato l\'allenamento oggi!');
    } else {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(body['detail'] ?? 'Errore sconosciuto');
    }
  }

  /// Invia il feedback emoji per l'allenamento di oggi. Fire-and-forget:
  /// gli errori vengono solo loggati per non bloccare l'utente.
  Future<void> submitFeedback(String rating) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return;
      await http.post(
        Uri.parse('${Env.apiUrl}/workouts/feedback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'rating': rating}),
      );
    } catch (_) {
      // silenzioso: il feedback è opzionale
    }
  }
}
