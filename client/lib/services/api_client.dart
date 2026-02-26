// HTTP client con retry e exponential backoff per le chiamate API.
// _retryableRequest — esegue richieste con retry su errori di rete; _performUpload — upload multipart con token Firebase.
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:flutter/foundation.dart';
import '../core/env.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException: $message (Code: $statusCode)';
}

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

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);

  Future<http.Response> _retryableRequest(
    Future<http.Response> Function() requestFn, {
    int maxRetries = _maxRetries,
  }) async {
    final r = RetryOptions(
      maxAttempts: maxRetries,
      delayFactor: _baseDelay,
      randomizationFactor: 0.25,
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

      return await _parseResponse(response);
    } on SocketException {
      throw NetworkException("Nessuna connessione internet.");
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException("Errore GET: $e", 500);
    }
  }

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

      return await _parseResponse(response);
    } on SocketException {
      throw NetworkException("Nessuna connessione internet.");
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException("Errore POST: $e", 500);
    }
  }

  Future<dynamic> _parseResponse(http.Response response) async {
    // [SECURITY] 401 → forza signOut: il token è scaduto/revocato.
    // authStateChanges() in AuthGate reindirizza automaticamente al login.
    if (response.statusCode == 401) {
      await FirebaseAuth.instance.signOut();
      throw ApiException('Sessione scaduta. Effettua nuovamente il login.', 401);
    }
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
    Function(int sent, int total)? onProgress,
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
        retryIf: (e) =>
            e is SocketException ||
            e is TimeoutException ||
            e is NetworkException,
      );
    } catch (e) {
      debugPrint("🛑 ApiClient Error: $e");
      rethrow;
    }
  }

  Future<dynamic> _performUpload(
    String endpoint,
    String filePath,
    Map<String, String>? fields,
  ) async {
    var uri = Uri.parse('${Env.apiUrl}$endpoint');
    var request = http.MultipartRequest('POST', uri);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      request.headers['Authorization'] = 'Bearer $token';
      debugPrint("🔑 Token iniettato per l'upload");
    }

    request.headers.addAll({'Accept': 'application/json'});

    if (fields != null) {
      request.fields.addAll(fields);
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException("Il file da caricare non esiste");
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    debugPrint("🚀 Uploading to $uri...");

    try {
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw NetworkException("Il server non risponde. Connessione lenta.");
        },
      );

      var response = await http.Response.fromStream(streamedResponse);
      debugPrint("📥 Response Status: ${response.statusCode}");

      if (response.statusCode == 401) {
        await FirebaseAuth.instance.signOut();
        throw ApiException('Sessione scaduta. Effettua nuovamente il login.', 401);
      }
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
        String errorMsg = "Errore sconosciuto";
        try {
          final errorJson = json.decode(utf8.decode(response.bodyBytes));
          if (errorJson is Map && errorJson.containsKey('detail')) {
            errorMsg = errorJson['detail'].toString();
          }
        } catch (_) {
          errorMsg = "Errore HTTP ${response.statusCode}";
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
