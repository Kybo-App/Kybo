import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kybo/core/env.dart';

class MatchmakingProvider extends ChangeNotifier {
  String get _baseUrl => Env.isProd
      ? "https://kybo-prod.onrender.com"
      : "https://kybo-test.onrender.com";

  List<dynamic> _myRequests = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get myRequests => _myRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  String _safeBody(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is String) {
        return detail.length > 200 ? detail.substring(0, 200) : detail;
      }
    } catch (_) {}
    return 'Errore ${response.statusCode}';
  }

  Future<void> loadMyRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/matchmaking/my-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _myRequests = data['requests'] as List<dynamic>? ?? [];
      } else {
        _error = _safeBody(response);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRequest(String coachType, String goal, String notes) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/matchmaking/requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coach_type': coachType,
          'goal': goal,
          'notes': notes,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(_safeBody(response));
      }
      await loadMyRequests();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<void> acceptOffer(String reqId, String offerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/matchmaking/requests/$reqId/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'offer_id': offerId}),
      );

      if (response.statusCode != 200) {
        throw Exception(_safeBody(response));
      }
      await loadMyRequests();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }
}
