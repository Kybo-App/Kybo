import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // [FIX] Trim the URL to prevent "Scheme not starting..." errors
  static const String _backendUrl = "https://mydiet-74rg.onrender.com";
  String get backendUrl => _backendUrl.trim();

  // 1. Fetch All Users
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // 2. Fetch Diet History
  Stream<List<Map<String, dynamic>>> getDietHistory(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('diets')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // 3. Create User (Backend - Auto Verified)
  Future<void> createUser({
    required String email,
    required String password,
    required String role,
    required String firstName,
    required String lastName,
    String? parentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");
    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse('$backendUrl/admin/create-user'),
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
        'parent_id': parentId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to create user: ${response.body}");
    }
  }

  // 4. Delete User (Backend - Force Delete)
  Future<void> deleteUser(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");
    final token = await user.getIdToken();

    final response = await http.delete(
      Uri.parse('$backendUrl/admin/delete-user/$uid'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete user: ${response.body}");
    }
  }

  // 5. Sync Users (Restore Ghost Accounts)
  Future<String> syncUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");
    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse('$backendUrl/admin/sync-users'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'] ?? "Sync Done";
    } else {
      throw Exception("Sync Failed: ${response.body}");
    }
  }

  // 6. Upload Diet (With FileName)
  Future<void> uploadDietForUser(String targetUid, PlatformFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");

    final token = await user.getIdToken();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/upload-diet/$targetUid'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final Map<String, dynamic> dietData = jsonDecode(respStr);

      await _db.collection('users').doc(targetUid).collection('diets').add({
        'plan': dietData['plan'],
        'substitutions': dietData['substitutions'],
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': 'admin',
        'fileName': file.name,
      });
    } else {
      final respStr = await response.stream.bytesToString();
      throw Exception("Upload Failed (${response.statusCode}): $respStr");
    }
  }

  // 7. Upload Custom Parser Config (The Logic You Requested)
  Future<void> uploadParserConfig(String targetUid, PlatformFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");

    final token = await user.getIdToken();

    // [FIX] Use trimmed backendUrl to avoid FormatException
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/admin/upload-parser/$targetUid'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
    );

    var response = await request.send();

    if (response.statusCode != 200) {
      final respStr = await response.stream.bytesToString();
      throw Exception("Parser Upload Failed: $respStr");
    }
  }
}
