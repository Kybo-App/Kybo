import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdminRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Fetch All Users
  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // 2. Toggle Ban/Active
  Future<void> toggleUserStatus(String uid, bool currentStatus) async {
    await _db.collection('users').doc(uid).update({
      'is_active': !currentStatus,
    });
  }

  // 3. Create User (Via Python Backend)
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

    const String backendUrl = "https://mydiet-74rg.onrender.com";

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

  // 4. Delete User (Via Python Backend)
  Future<void> deleteUser(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");
    final token = await user.getIdToken();

    const String backendUrl = "https://mydiet-74rg.onrender.com";

    final response = await http.delete(
      Uri.parse('$backendUrl/admin/delete-user/$uid'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete user: ${response.body}");
    }
  }

  // 5. Sync Users (Repair invisible users)
  Future<String> syncUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");
    final token = await user.getIdToken();

    const String backendUrl = "https://mydiet-74rg.onrender.com";

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

  // 6. Upload Diet (Inject PDF & Save to Firestore)
  Future<void> uploadDietForUser(String targetUid, PlatformFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");

    final token = await user.getIdToken();
    const String backendUrl = "https://mydiet-74rg.onrender.com";

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
      });
    } else {
      final respStr = await response.stream.bytesToString();
      throw Exception("Upload Failed (${response.statusCode}): $respStr");
    }
  }
}
