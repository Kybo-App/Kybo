/// Provider per gestire la scheda allenamento assegnata all'utente.
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
}
