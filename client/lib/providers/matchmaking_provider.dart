import 'package:flutter/foundation.dart';
import '../core/error_handler.dart';
import '../services/api_client.dart';

class MatchmakingProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<dynamic> _myRequests = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get myRequests => _myRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMyRequests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.get('/matchmaking/my-requests') as Map<String, dynamic>;
      _myRequests = data['requests'] as List<dynamic>? ?? [];
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = ErrorMapper.toUserMessage(e);
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
      await _api.post('/matchmaking/requests', body: {
        'coach_type': coachType,
        'goal': goal,
        'notes': notes,
      });
      await loadMyRequests();
    } catch (e) {
      _error = e is ApiException ? e.message : ErrorMapper.toUserMessage(e);
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
      await _api.post(
        '/matchmaking/requests/$reqId/accept',
        body: {'offer_id': offerId},
      );
      await loadMyRequests();
    } catch (e) {
      _error = e is ApiException ? e.message : ErrorMapper.toUserMessage(e);
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }

  /// Cancella una richiesta ancora aperta. Le offerte pending vengono
  /// rifiutate lato server nella stessa transazione.
  Future<void> cancelRequest(String reqId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.delete('/matchmaking/requests/$reqId');
      await loadMyRequests();
    } catch (e) {
      _error = e is ApiException ? e.message : ErrorMapper.toUserMessage(e);
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }
}
