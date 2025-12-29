import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> getToken() async {
    return await currentUser?.getIdToken(false);
  }

  // Helper to ensure User Doc exists in Firestore (Visible to Admin)
  Future<void> _ensureUserDoc(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'role': 'independent', // Default for self-signup
        'first_name': user.displayName?.split(' ').first ?? 'User',
        'last_name': '',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception("Login annullato dall'utente");

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      if (userCred.user != null) {
        await _ensureUserDoc(userCred.user!);
      }
      return userCred;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    // Note: We don't strictly need to create doc on login if it already exists,
    // but you could add _ensureUserDoc here too if you want to be safe.
  }

  Future<void> signUp(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      await _ensureUserDoc(credential.user!);
      await credential.user?.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
