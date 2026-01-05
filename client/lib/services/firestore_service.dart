import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveDietToHistory(
    Map<String, dynamic> plan,
    Map<String, dynamic> subs,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.collection('users').doc(user.uid).collection('diets').add({
        'uploadedAt': FieldValue.serverTimestamp(),
        'plan': plan,
        'substitutions': subs,
      });
      debugPrint("💾 Dieta salvata nella cronologia cloud.");
    } catch (e) {
      debugPrint("⚠️ Errore salvataggio cronologia: $e");
      // Non rilanciamo perché non è critico per l'utente immediato
    }
  }

  Stream<List<Map<String, dynamic>>> getDietHistory() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('diets')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<void> deleteDiet(String dietId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('diets')
          .doc(dietId)
          .delete();
    } catch (e) {
      debugPrint("❌ Errore eliminazione dieta: $e");
      rethrow;
    }
  }
}
