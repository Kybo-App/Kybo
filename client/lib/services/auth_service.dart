// Gestisce autenticazione Firebase: email/password, Google Sign-In e creazione profilo utente.
// _ensureUserDoc — crea il documento Firestore dell'utente se non esiste (self-healing).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Token Firebase ID dell'utente corrente, o null se non loggato.
  /// Usato da tutti i caller HTTP che chiamano il backend autenticato.
  Future<String?> getToken() async {
    return await currentUser?.getIdToken();
  }

  /// Crea il documento Firestore dell'utente se non esiste (self-healing:
  /// chiamato sia da signUp/signInWithGoogle che da signIn, così un account
  /// Auth creato ma senza doc — es. per un fallimento passato — viene
  /// riparato al prossimo login invece di restare orfano per sempre).
  ///
  /// [SECURITY FIX F2] Non ingoia più l'errore: il chiamante deve sapere se
  /// il profilo non è stato creato, altrimenti l'utente prosegue verso
  /// MainScreen senza ruolo/legame col nutrizionista (vedi audit F1).
  Future<void> _ensureUserDoc(User user, {String role = 'independent', Map<String, dynamic>? additionalData}) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      debugPrint("👤 Creazione nuovo profilo utente: ${user.uid}");
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'role': role,
        'first_name': user.displayName?.split(' ').first ?? 'User',
        'last_name': '',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
        if (additionalData != null) ...additionalData,
      });
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw PlatformException(
          code: 'sign_in_canceled',
          message: 'Login annullato dall\'utente',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      if (userCred.user != null) {
        await _ensureUserDoc(userCred.user!);
        await updateLastLogin(userCred.user!.uid);
      }
      return userCred;
    } catch (e) {
      debugPrint("❌ Google Sign-In Error: $e");
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (cred.user != null) {
        // Self-healing: ripara un account Auth senza doc Firestore (es. da un
        // signUp interrotto in passato). Se il doc esiste già, _ensureUserDoc
        // è un no-op (non tocca ruolo/dati esistenti).
        await _ensureUserDoc(cred.user!);
        await updateLastLogin(cred.user!.uid);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, {String role = 'independent', Map<String, dynamic>? additionalData}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        // Nuovo account self-signup: obbliga la verifica email al primo accesso
        // (l'EmailVerificationGuard mostra la schermata finché il flag è true;
        // la mail di verifica viene inviata dalla schermata stessa).
        await _ensureUserDoc(
          credential.user!,
          role: role,
          additionalData: {
            'requires_email_verification': true,
            if (additionalData != null) ...additionalData,
          },
        );
        await updateLastLogin(credential.user!.uid);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> updateLastLogin(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'last_seen': FieldValue.serverTimestamp(),
        'is_active': true,
      });
    } catch (e) {
      debugPrint("⚠️ Failed to update last_login: $e");
    }
  }

  /// Aggiorna solo `last_seen` — chiamato dall'app ad ogni avvio per dare
  /// un segnale "freschezza" visibile ai PT/nutri in admin (last activity).
  Future<void> touchLastSeen() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'last_seen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("⚠️ Failed to update last_seen: $e");
    }
  }
}
