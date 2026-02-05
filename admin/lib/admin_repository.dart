import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:kybo_admin/core/env.dart';

class AdminRepository {
  String get _baseUrl => Env.isProd
      ? "https://kybo-prod.onrender.com"
      : "https://kybo-test.onrender.com";

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  // --- MAINTENANCE & CONFIGURATION ---

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
      throw Exception('Failed to schedule: ${response.body}');
    }
  }

  Future<void> cancelMaintenanceSchedule() async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/cancel-maintenance'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to cancel: ${response.body}');
    }
  }

  // --- USER MANAGEMENT ---

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
      throw Exception('Failed to create user: ${response.body}');
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
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user: ${response.body}');
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
      throw Exception('Failed to assign user: ${response.body}');
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
      throw Exception('Failed to unassign user: ${response.body}');
    }
  }

  Future<void> deleteUser(String uid) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/delete-user/$uid'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete user: ${response.body}');
    }
  }

  // NUOVO: Cancella Dieta tramite API (Secure Logged)
  Future<void> deleteDiet(String dietId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/delete-diet/$dietId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete diet: ${response.body}');
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
    throw Exception("Sync fallito: ${response.body}");
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
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception(await response.stream.bytesToString());
    }
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
    if (response.statusCode != 200) {
      throw Exception(await response.stream.bytesToString());
    }
  }

  // --- AUDIT & SECURITY ---

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
      throw Exception('Audit Log Failed: ${response.body}');
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
      throw Exception(
        "Errore Audit Gateway (${response.statusCode}): ${response.body}",
      );
    }
  }

  // --- USER MANAGEMENT SECURE ---

  Future<List<dynamic>> getSecureUsersList() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/users-secure'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    } else {
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
      throw Exception("Errore Profilo Secure (${response.statusCode})");
    }
  }

  // --- CHAT ATTACHMENTS ---
  
  Future<Map<String, dynamic>> uploadChatAttachment(PlatformFile file) async {
    final token = await _getToken();
    var uri = Uri.parse('$_baseUrl/chat/upload-attachment');
    var request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    if (file.bytes != null) {
      // Web or bytes available
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: _getMediaType(file.extension),
      ));
    } else if (file.path != null) {
      // Mobile/Desktop with path
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
      throw Exception("Upload fallito: ${response.statusCode} - ${response.body}");
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

  // --- TWO-FACTOR AUTHENTICATION ---

  /// Initiates 2FA setup
  Future<Map<String, dynamic>> setup2FA() async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/2fa/setup'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception("Errore Setup 2FA (${response.statusCode}): ${response.body}");
    }
  }

  /// Verifies code and enables 2FA
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
      throw Exception("Errore Verifica 2FA (${response.statusCode}): ${response.body}");
    }
  }

  /// Validates 2FA code for login
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

  /// Disables 2FA
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
      throw Exception("Errore Disabilita 2FA (${response.statusCode}): ${response.body}");
    }
  }

  /// Gets 2FA status
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

  /// Regenerates backup codes
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
      throw Exception("Errore Rigenera Backup (${response.statusCode}): ${response.body}");
    }
  }

  // --- NUTRITIONIST REPORTS ---

  /// Fetches monthly report for a nutritionist
  Future<Map<String, dynamic>> getMonthlyReport({
    required String nutritionistId,
    required String month, // YYYY-MM format
  }) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/reports/monthly?nutritionist_id=$nutritionistId&month=$month'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception("Errore Report (${response.statusCode}): ${response.body}");
    }
  }

  /// Lists available reports
  Future<List<dynamic>> listReports({
    String? nutritionistId,
    int limit = 12,
  }) async {
    final token = await _getToken();
    var url = '$_baseUrl/admin/reports/list?limit=$limit';
    if (nutritionistId != null) {
      url += '&nutritionist_id=$nutritionistId';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['reports'] as List<dynamic>? ?? [];
    } else {
      throw Exception("Errore Lista Report (${response.statusCode}): ${response.body}");
    }
  }

  /// Generates (or regenerates) a report
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
      throw Exception("Errore Generazione Report (${response.statusCode}): ${response.body}");
    }
  }

  // --- GDPR RETENTION POLICY ---

  /// Fetches GDPR dashboard with retention statistics
  Future<Map<String, dynamic>> getGDPRDashboard() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/gdpr/admin/dashboard'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception("Errore GDPR Dashboard (${response.statusCode}): ${response.body}");
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
      throw Exception("Errore Retention Config (${response.statusCode}): ${response.body}");
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
      throw Exception("Errore Salvataggio Config (${response.statusCode}): ${response.body}");
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
      throw Exception("Errore Purge (${response.statusCode}): ${response.body}");
    }
  }
}
