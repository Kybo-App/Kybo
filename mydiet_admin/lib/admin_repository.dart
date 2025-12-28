import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
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

  // 3. Create User (God Mode)
  Future<void> createUser({
    required String email,
    required String password,
    required String role,
    String? parentId,
  }) async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    try {
      UserCredential cred = await FirebaseAuth.instanceFor(
        app: secondaryApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      await _db.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'role': role,
        'parent_id': parentId,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
    } catch (e) {
      rethrow;
    }
  }

  // 4. Upload Diet (Inject PDF & Save to Firestore)
  Future<void> uploadDietForUser(String targetUid, PlatformFile file) async {
    // A. Get the Admin's ID Token
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Admin not logged in");

    final token = await user.getIdToken();

    // [IMPORTANT] Ensure this matches your live Render URL
    const String backendUrl = "https://mydiet-74rg.onrender.com";

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/upload-diet/$targetUid'),
    );

    // B. Attach Authorization
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
    );

    // C. Send Request to Python Backend
    var response = await request.send();

    if (response.statusCode == 200) {
      // D. Parse the JSON response from the server
      final respStr = await response.stream.bytesToString();
      final Map<String, dynamic> dietData = jsonDecode(respStr);

      // E. Write the parsed data to the TARGET USER'S Firestore
      // The user app listens to 'users/{uid}/diets', so we write there.
      await _db.collection('users').doc(targetUid).collection('diets').add({
        'plan': dietData['plan'],
        'substitutions': dietData['substitutions'],
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': 'admin', // Optional: audit trail
      });
    } else {
      final respStr = await response.stream.bytesToString();
      throw Exception("Upload Failed (${response.statusCode}): $respStr");
    }
  }
}
