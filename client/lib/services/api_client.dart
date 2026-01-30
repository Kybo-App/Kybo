import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:flutter/foundation.dart';
import '../core/env.dart';

// Eccezione per errori di business (es. 400, 500, dati non validi)
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException: $message (Code: $statusCode)';
}

// Eccezione per errori di rete (es. Timeout, DNS)
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // [NEW] Configurazione retry globale
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);

  /// Wrapper generico per richieste HTTP con retry e exponential backoff
  Future<http.Response> _retryableRequest(
    Future<http.Response> Function() requestFn, {
    int maxRetries = _maxRetries,
  }) async {
    final r = RetryOptions(
      maxAttempts: maxRetries,
      delayFactor: _baseDelay,
      randomizationFactor: 0.25, // Jitter per evitare thundering herd
    );

    return await r.retry(
      requestFn,
      retryIf: (e) =>
          e is SocketException ||
          e is TimeoutException ||
          e is NetworkException ||
          (e is http.ClientException),
      onRetry: (e) => debugPrint("🔄 Retry dopo errore: $e"),
    );
  }

  /// GET request con retry automatico
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse('${Env.apiUrl}$endpoint');
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : null;

      final response = await _retryableRequest(() async {
        return await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
            ...?headers,
          },
        ).timeout(const Duration(seconds: 30));
      });

      return _parseResponse(response);
    } on SocketException {
      throw NetworkException("Nessuna connessione internet.");
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException("Errore GET: $e", 500);
    }
  }

  /// POST request con retry automatico
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('${Env.apiUrl}$endpoint');
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : null;

      final response = await _retryableRequest(() async {
        return await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
            ...?headers,
          },
          body: body != null ? json.encode(body) : null,
        ).timeout(const Duration(seconds: 30));
      });

      return _parseResponse(response);
    } on SocketException {
      throw NetworkException("Nessuna connessione internet.");
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException("Errore POST: $e", 500);
    }
  }

  /// Parser comune per le risposte
  dynamic _parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      try {
        return json.decode(utf8.decode(response.bodyBytes));
      } catch (e) {
        throw ApiException("Risposta server non valida", response.statusCode);
      }
    } else {
      String errorMsg = "Errore HTTP ${response.statusCode}";
      try {
        final errorJson = json.decode(utf8.decode(response.bodyBytes));
        if (errorJson is Map && errorJson.containsKey('detail')) {
          errorMsg = errorJson['detail'].toString();
        }
      } catch (_) {}
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  Future<dynamic> uploadFile(
    String endpoint,
    String filePath, {
    Map<String, String>? fields,
    Function(int sent, int total)? onProgress, // ✅ AGGIUNGI questo parametro
  }) async {
    final r = RetryOptions(
      maxAttempts: 3,
      delayFactor: const Duration(seconds: 1),
    );

    try {
      return await r.retry(
        () async {
          return await _performUpload(endpoint, filePath, fields);
        },
        // Riprova solo su errori di rete puri, non su errori logici (4xx/5xx)
        retryIf: (e) =>
            e is SocketException ||
            e is TimeoutException ||
            e is NetworkException,
      );
    } catch (e) {
      // Logga l'errore grezzo per debug
      debugPrint("🛑 ApiClient Error: $e");
      rethrow; // Passa la palla al Repository -> Provider
    }
  }

  Future<dynamic> _performUpload(
    String endpoint,
    String filePath,
    Map<String, String>? fields,
  ) async {
    var uri = Uri.parse('${Env.apiUrl}$endpoint');
    var request = http.MultipartRequest('POST', uri);

    // --- FIX AUTH: INIEZIONE TOKEN ---
    // Recuperiamo il token fresco da Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      request.headers['Authorization'] = 'Bearer $token';
      debugPrint("🔑 Token iniettato per l'upload");
    }
    // ---------------------------------

    request.headers.addAll({'Accept': 'application/json'});

    if (fields != null) {
      request.fields.addAll(fields);
    }

    // Verifica esistenza file prima dell'invio
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException("Il file da caricare non esiste");
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    debugPrint("🚀 Uploading to $uri...");

    try {
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60), // Timeout generoso per upload
        onTimeout: () {
          throw NetworkException("Il server non risponde. Connessione lenta.");
        },
      );

      var response = await http.Response.fromStream(streamedResponse);
      debugPrint("📥 Response Status: ${response.statusCode}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        try {
          return json.decode(utf8.decode(response.bodyBytes));
        } catch (e) {
          throw ApiException(
            "Risposta server non valida (JSON corrotto)",
            response.statusCode,
          );
        }
      } else {
        // Gestione errori server
        String errorMsg = "Errore sconosciuto";
        try {
          final errorJson = json.decode(utf8.decode(response.bodyBytes));
          if (errorJson is Map && errorJson.containsKey('detail')) {
            errorMsg = errorJson['detail'].toString();
          }
        } catch (_) {
          // Fallback se non è JSON
          errorMsg = response.body.isNotEmpty
              ? response.body.substring(0, min(response.body.length, 200))
              : "Errore HTTP ${response.statusCode}";
        }
        throw ApiException(errorMsg, response.statusCode);
      }
    } on SocketException {
      throw NetworkException("Nessuna connessione internet.");
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException("Errore imprevisto: $e", 500);
    }
  }
}
