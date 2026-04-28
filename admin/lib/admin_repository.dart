// Repository centralizzato per tutte le chiamate HTTP al backend Kybo.
// _pollDietJob: polling asincrono sul job RQ fino a completamento o timeout (~5 min).
// _checkUnauthorized: forza signOut su 401, il StreamBuilder in AuthGate reindirizza.
// _safeBody: estrae solo il campo 'detail' dal JSON del server, non espone stack trace.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:kybo_admin/core/env.dart';

class AdminRepository {
  String get _baseUrl => Env.apiUrl;

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  // [SECURITY] 401 → forza signOut per invalidare la sessione lato client.
  // Il StreamBuilder su authStateChanges() in AuthGate reindirizza automaticamente.
  Future<void> _checkUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Sessione scaduta. Effettua nuovamente il login.');
    }
  }

  // [SECURITY] Estrae solo il campo 'detail' dalla risposta JSON del server,
  // evitando di esporre stack trace o dati interni nelle exception client.
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

  Future<bool> getMaintenanceStatus() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/config/maintenance'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['enabled'] ?? false;
    }
    return false;
  }

  Future<void> setMaintenanceStatus(bool enabled, {String? message}) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('$_baseUrl/admin/config/maintenance'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'enabled': enabled,
        if (message != null) 'message': message,
      }),
    );
  }

  Future<void> scheduleMaintenance(DateTime date, bool notifyUsers) async {
    final token = await _getToken();
    String isoDate = date.toUtc().toIso8601String();
    String formattedDate = DateFormat('EEEE, d MMM "at" HH:mm').format(date);

    final response = await http.post(
      Uri.parse('$_baseUrl/admin/schedule-maintenance'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'scheduled_time': isoDate,
        'message':
            "Scheduled Maintenance: The app will be unavailable on $formattedDate.",
        'notify': notifyUsers,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to schedule: ${_safeBody(response)}');
    }
  }

  Future<void> cancelMaintenanceSchedule() async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/cancel-maintenance'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to cancel: ${_safeBody(response)}');
    }
  }



  Future<Map<String, dynamic>> getAppConfig() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/config/app'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    return {};
  }

  Future<void> setAppConfig(Map<String, dynamic> config) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/config/app'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(config),
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to update app config: ${_safeBody(response)}');
    }
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String role,
    required String firstName,
    required String lastName,
    int? maxClients,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/create-user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'role': role,
        'first_name': firstName,
        'last_name': lastName,
        if (maxClients != null) 'max_clients': maxClients,
      }),
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to create user: ${_safeBody(response)}');
    }
  }

  Future<void> updateUser(
    String uid, {
    String? email,
    String? firstName,
    String? lastName,
    String? bio,
    String? specializations,
    String? phone,
    int? maxClients,
    String? studioName,
    String? role,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/update-user/$uid'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (email != null) 'email': email,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (bio != null) 'bio': bio,
        if (specializations != null) 'specializations': specializations,
        if (phone != null) 'phone': phone,
        if (maxClients != null) 'max_clients': maxClients,
        if (studioName != null) 'studio_name': studioName,
        if (role != null) 'role': role,
      }),
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to update user: ${_safeBody(response)}');
    }
  }

  Future<void> assignUserToNutritionist(
    String targetUid,
    String nutritionistId,
  ) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/assign-user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'target_uid': targetUid,
        'nutritionist_id': nutritionistId,
      }),
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to assign user: ${_safeBody(response)}');
    }
  }

  Future<void> unassignUser(String targetUid) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/unassign-user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'target_uid': targetUid}),
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to unassign user: ${_safeBody(response)}');
    }
  }

  Future<void> deleteUser(String uid) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/delete-user/$uid'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to delete user: ${_safeBody(response)}');
    }
  }

  Future<void> deleteDiet(String dietId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/delete-diet/$dietId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Failed to delete diet: ${_safeBody(response)}');
    }
  }

  Future<String> syncUsers() async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/sync-users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['message'] ?? "Sync completato.";
    }
    await _checkUnauthorized(response);
    throw Exception("Sync fallito: ${_safeBody(response)}");
  }

  Future<void> uploadDietForUser(String targetUid, PlatformFile file) async {
    final token = await _getToken();
    if (file.bytes == null) throw Exception("File corrotto");

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/upload-diet/$targetUid'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final streamResponse = await request.send();
    final body = await streamResponse.stream.bytesToString();

    if (streamResponse.statusCode == 200) {
      return;
    } else if (streamResponse.statusCode == 202) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final jobId = data['job_id'] as String;
      await _pollDietJob(jobId, token!);
    } else if (streamResponse.statusCode == 401) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Sessione scaduta. Effettua nuovamente il login.');
    } else {
      throw Exception('Errore ${streamResponse.statusCode}');
    }
  }

  Future<void> _pollDietJob(String jobId, String token) async {
    const pollInterval = Duration(seconds: 3);
    const maxAttempts = 100;

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(pollInterval);

      final response = await http.get(
        Uri.parse('$_baseUrl/diet/job/$jobId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 404) {
        throw Exception('Job scaduto o non trovato.');
      }
      if (response.statusCode == 503) {
        throw Exception('Servizio di coda non disponibile.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'done') return;
      if (status == 'failed') {
        final error = data['error'] as String? ?? 'Errore durante il parsing.';
        throw Exception(error);
      }
    }

    throw Exception('Timeout: elaborazione dieta troppo lunga.');
  }

  Future<void> uploadParserConfig(String targetUid, PlatformFile file) async {
    final token = await _getToken();
    if (file.bytes == null) throw Exception("File vuoto");
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/upload-parser/$targetUid'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: MediaType('text', 'plain'),
      ),
    );
    final response = await request.send();
    if (response.statusCode == 401) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Sessione scaduta. Effettua nuovamente il login.');
    }
    if (response.statusCode != 200) {
      throw Exception('Errore upload parser (${response.statusCode})');
    }
  }

  Future<void> logDataAccess(String targetUid) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/log-access'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'target_uid': targetUid,
        'reason': 'Manual Unlock from Admin Panel',
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception('Audit Log Failed: ${_safeBody(response)}');
    }
  }

  Future<List<dynamic>> getSecureUserHistory(String targetUid) async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/user-history/$targetUid'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception(
        "Errore Audit Gateway (${response.statusCode}): ${_safeBody(response)}",
      );
    }
  }

  Future<List<dynamic>> getSecureUsersList() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/users-secure'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Directory Secure (${response.statusCode})");
    }
  }

  Future<Map<String, dynamic>> getSecureUserDetails(String uid) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/user-details-secure/$uid'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Profilo Secure (${response.statusCode})");
    }
  }

  Future<Map<String, dynamic>> uploadChatAttachment(PlatformFile file) async {
    final token = await _getToken();
    var uri = Uri.parse('$_baseUrl/chat/upload-attachment');
    var request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: _getMediaType(file.extension),
      ));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path!,
        filename: file.name,
        contentType: _getMediaType(file.extension),
      ));
    } else {
       throw Exception("File vuoto o invalido");
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      await _checkUnauthorized(response);
      throw Exception("Upload fallito: ${_safeBody(response)}");
    }
  }

  MediaType? _getMediaType(String? extension) {
    if (extension == null) return null;
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> setup2FA() async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/2fa/setup'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Setup 2FA (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<Map<String, dynamic>> verify2FA({
    required String code,
    required String secret,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/2fa/verify'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'code': code,
        'secret': secret,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Verifica 2FA (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<bool> validate2FA(String code) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/2fa/validate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': code}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['valid'] == true;
    }
    return false;
  }

  Future<void> disable2FA(String code) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/2fa/disable'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': code}),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Disabilita 2FA (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<bool> get2FAStatus() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/2fa/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['enabled'] == true;
    }
    return false;
  }

  Future<List<String>> regenerateBackupCodes(String code) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/2fa/backup-codes/regenerate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': code}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return List<String>.from(data['backup_codes'] ?? []);
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Rigenera Backup (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<Map<String, dynamic>> getMonthlyReport({
    required String nutritionistId,
    required String month,
  }) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/reports/monthly?nutritionist_id=$nutritionistId&month=$month'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Report (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<List<dynamic>> listReports({
    String? nutritionistId,
    int limit = 12,
  }) async {
    final token = await _getToken();
    final queryParams = <String, String>{'limit': '$limit'};
    if (nutritionistId != null) queryParams['nutritionist_id'] = nutritionistId;
    final uri = Uri.parse('$_baseUrl/admin/reports/list').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['reports'] as List<dynamic>? ?? [];
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Lista Report (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<Map<String, dynamic>> generateReport({
    required String nutritionistId,
    required int year,
    required int month,
    bool forceRegenerate = false,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/reports/generate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'nutritionist_id': nutritionistId,
        'year': year,
        'month': month,
        'force_regenerate': forceRegenerate,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Generazione Report (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<Map<String, dynamic>> getServerMetrics() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/metrics/api'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception("Errore Metriche Server (${response.statusCode})");
    }
  }

  Future<Map<String, dynamic>> getHealthDetailed() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/health/detailed'),
    );

    if (response.statusCode == 200 || response.statusCode == 503) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception("Errore Health Check (${response.statusCode})");
    }
  }

  Future<Map<String, dynamic>> getGDPRDashboard() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/gdpr/admin/dashboard'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore GDPR Dashboard (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Gets current retention configuration
  Future<Map<String, dynamic>> getRetentionConfig() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/gdpr/admin/retention-config'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Retention Config (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Updates retention configuration
  Future<void> setRetentionConfig({
    required int retentionMonths,
    required bool isEnabled,
    required bool dryRun,
    List<String>? excludeRoles,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/gdpr/admin/retention-config'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'retention_months': retentionMonths,
        'is_enabled': isEnabled,
        'dry_run': dryRun,
        if (excludeRoles != null) 'exclude_roles': excludeRoles,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Salvataggio Config (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Purges inactive users (batch or single)
  Future<Map<String, dynamic>> purgeInactiveUsers({
    bool dryRun = true,
    String? targetUid,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/gdpr/admin/purge-inactive'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'dry_run': dryRun,
        if (targetUid != null) 'target_uid': targetUid,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Purge (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  // --- COMMUNICATION: BROADCAST ---

  /// Sends a broadcast message to all clients
  Future<Map<String, dynamic>> broadcastMessage(String message) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/communication/broadcast'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Broadcast (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  // --- COMMUNICATION: INTERNAL NOTES ---

  /// Fetches internal notes for a client
  Future<List<dynamic>> getClientNotes(String clientUid) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/communication/notes/$clientUid'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['notes'] as List<dynamic>? ?? [];
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Note (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Creates a new internal note for a client
  Future<Map<String, dynamic>> createClientNote({
    required String clientUid,
    required String content,
    String category = 'general',
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/communication/notes/$clientUid'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'content': content,
        'category': category,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Creazione Nota (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Updates an internal note
  Future<void> updateClientNote({
    required String clientUid,
    required String noteId,
    String? content,
    String? category,
    bool? pinned,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/communication/notes/$clientUid/$noteId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (content != null) 'content': content,
        if (category != null) 'category': category,
        if (pinned != null) 'pinned': pinned,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Aggiornamento Nota (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Deletes an internal note
  Future<void> deleteClientNote({
    required String clientUid,
    required String noteId,
  }) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/communication/notes/$clientUid/$noteId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Eliminazione Nota (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  // --- EMAIL ALERT CONFIG ---

  /// Restituisce la configurazione degli alert email per messaggi non letti
  Future<Map<String, dynamic>> getEmailAlertConfig() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/communication/email-alert-config'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    await _checkUnauthorized(response);
    throw Exception("Errore recupero config (${response.statusCode}): ${_safeBody(response)}");
  }

  /// Salva la configurazione degli alert email per messaggi non letti
  Future<void> setEmailAlertConfig({
    required bool enabled,
    required int thresholdDays,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/communication/email-alert-config'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'enabled': enabled,
        'threshold_days': thresholdDays,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore salvataggio config (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  // --- REWARDS CATALOG ---

  /// Gets the full rewards catalog (admin view, includes inactive)
  Future<Map<String, dynamic>> getRewardsCatalog() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/rewards/catalog'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Catalogo Premi (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Creates a new reward
  Future<void> createReward({
    required String name,
    required int xpCost,
    String description = '',
    String? imageUrl,
    String? redirectUrl,
    int? stock,
    bool isActive = true,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/rewards/catalog'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'xp_cost': xpCost,
        if (imageUrl != null) 'image_url': imageUrl,
        if (redirectUrl != null) 'redirect_url': redirectUrl,
        if (stock != null) 'stock': stock,
        'is_active': isActive,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Creazione Premio (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Updates an existing reward
  Future<void> updateReward(
    String rewardId, {
    String? name,
    String? description,
    int? xpCost,
    String? imageUrl,
    String? redirectUrl,
    int? stock,
    bool? isActive,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/rewards/catalog/$rewardId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (xpCost != null) 'xp_cost': xpCost,
        if (imageUrl != null) 'image_url': imageUrl,
        if (redirectUrl != null) 'redirect_url': redirectUrl,
        if (stock != null) 'stock': stock,
        if (isActive != null) 'is_active': isActive,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Aggiornamento Premio (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Deletes a reward
  Future<void> deleteReward(String rewardId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/rewards/catalog/$rewardId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Eliminazione Premio (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Gets all reward claims (admin view)
  Future<Map<String, dynamic>> getRewardsClaims({String? status}) async {
    final token = await _getToken();
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    final uri = Uri.parse('$_baseUrl/admin/rewards/claims').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Lista Riscatti (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Fulfills a reward claim
  Future<void> fulfillRewardClaim(String userUid, String claimId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/rewards/claims/$userUid/$claimId/fulfill'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Evasione Premio (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  // --- WORKOUT PLANS ---

  /// Gets all workout plans created by the current professional
  Future<Map<String, dynamic>> getWorkoutPlans() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/workouts/plans'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception("Errore Schede Allenamento (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Creates a new workout plan. Se [isTemplate] è true, [targetUid] è ignorato
  /// e la scheda viene salvata come template riutilizzabile.
  Future<void> createWorkoutPlan({
    required String name,
    String description = '',
    List<Map<String, dynamic>> days = const [],
    String? targetUid,
    bool isTemplate = false,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/workouts/plans'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'days': days,
        if (targetUid != null && !isTemplate) 'target_uid': targetUid,
        'is_template': isTemplate,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Creazione Scheda (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Updates an existing workout plan
  Future<void> updateWorkoutPlan(
    String planId, {
    String? name,
    String? description,
    List<Map<String, dynamic>>? days,
    bool? isActive,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/workouts/plans/$planId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (days != null) 'days': days,
        if (isActive != null) 'is_active': isActive,
      }),
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Aggiornamento Scheda (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Deletes a workout plan
  Future<void> deleteWorkoutPlan(String planId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/workouts/plans/$planId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Eliminazione Scheda (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Assigns a workout plan to a user
  Future<void> assignWorkoutPlan(String planId, String targetUid) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/workouts/plans/$planId/assign/$targetUid'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception("Errore Assegnazione Scheda (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Clona un template e assegna la copia a un utente. Il template originale
  /// resta intatto e riutilizzabile (a differenza di assignWorkoutPlan che
  /// muta il target_uid del piano).
  Future<void> cloneAndAssignWorkoutPlan(
      String planId, String targetUid) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(
          '$_baseUrl/workouts/plans/$planId/clone-and-assign/$targetUid'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception(
          "Errore Clone Template (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  // --- DIET TEMPLATES ---

  Future<Map<String, dynamic>> getDietTemplates() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/diet-templates'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } else {
      await _checkUnauthorized(response);
      throw Exception(
          "Errore Templates Diete (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  /// Upload PDF dieta come template riutilizzabile (no target user).
  Future<void> createDietTemplate({
    required PlatformFile file,
    required String name,
    String description = '',
  }) async {
    final token = await _getToken();
    if (file.bytes == null) throw Exception('File corrotto');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/diet-templates'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final streamResponse = await request.send();
    final body = await streamResponse.stream.bytesToString();
    if (streamResponse.statusCode != 200) {
      if (streamResponse.statusCode == 401) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Sessione scaduta.');
      }
      throw Exception('Errore Template Dieta (${streamResponse.statusCode}): $body');
    }
  }

  Future<void> deleteDietTemplate(String templateId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/diet-templates/$templateId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception(
          "Errore Eliminazione Template (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  Future<void> cloneAndAssignDietTemplate(
      String templateId, String targetUid) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(
          '$_baseUrl/diet-templates/$templateId/clone-and-assign/$targetUid'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await _checkUnauthorized(response);
      throw Exception(
          "Errore Clone Template (${response.statusCode}): ${_safeBody(response)}");
    }
  }

  // --- MATCHMAKING ---

  Future<List<dynamic>> getMatchmakingBoard() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/matchmaking/board'),
      headers: {'Authorization': 'Bearer $token'},
    );
    await _checkUnauthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['board'] as List<dynamic>? ?? [];
    } else {
      throw Exception(_safeBody(response));
    }
  }

  Future<void> makeMatchmakingOffer(String reqId, String notes, String? priceInfo) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/matchmaking/requests/$reqId/offers'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'notes': notes,
        if (priceInfo != null) 'price_info': priceInfo,
      }),
    );
    await _checkUnauthorized(response);

    if (response.statusCode != 200) {
      throw Exception(_safeBody(response));
    }
  }

  /// Il PT ritira la propria offerta per una richiesta.
  /// Ritorna true se c'era un'offerta da ritirare, false se non esisteva (404).
  Future<bool> withdrawMatchmakingOffer(String reqId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/matchmaking/requests/$reqId/offers/mine'),
      headers: {'Authorization': 'Bearer $token'},
    );
    await _checkUnauthorized(response);

    if (response.statusCode == 200) return true;
    if (response.statusCode == 404) return false;
    throw Exception("Errore Ritiro Offerta (${response.statusCode}): ${_safeBody(response)}");
  }
}
