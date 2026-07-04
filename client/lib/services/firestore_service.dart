// Gestisce salvataggio, lettura e storico delle diete su Firestore con crittografia AES-256.
// getDietStream — stream della dieta corrente con decrittazione trasparente; getDietHistory — lista storico diete decriptate.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'encryption_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// [FIX FS2] Ritorna true/false invece di ingoiare silenziosamente ogni
  /// errore (prima solo un debugPrint): il chiamante (DietProvider) può
  /// segnalare il fallimento tramite lo stesso banner "sync fallita" già
  /// usato per syncFromFirebase (vedi fix D2).
  Future<bool> saveCurrentDiet(
    Map<String, dynamic> plan,
    Map<String, dynamic> subs,
    Map<String, dynamic> swaps, {
    List<dynamic>? weeks,
    Map<String, dynamic>? config,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final encryptionService = EncryptionService();

      final encryptedPlan = encryptionService.encryptData(plan, user.uid);
      final encryptedSubs = encryptionService.encryptData(subs, user.uid);
      final encryptedSwaps = encryptionService.encryptData(swaps, user.uid);

      final Map<String, dynamic> docData = {
        'lastUpdated': FieldValue.serverTimestamp(),
        'plan_encrypted': encryptedPlan,
        'substitutions_encrypted': encryptedSubs,
        'activeSwaps_encrypted': encryptedSwaps,
        'encrypted': true,
        // [FIX 2026-05-25] Cancella esplicitamente i campi legacy in chiaro
        // che potrebbero essere rimasti nel doc da scritture pre-encryption.
        // Con SetOptions(merge: true) i campi non menzionati restano lì come
        // fossili — e `syncFromFirebase` prima del fix li leggeva al posto
        // dei campi `_encrypted` (vedi bug "dieta vecchia senza sostituzioni
        // dopo kill+reopen"). Queste delete sono no-op se i campi non esistono.
        'plan': FieldValue.delete(),
        'substitutions': FieldValue.delete(),
        'activeSwaps': FieldValue.delete(),
        'weeks': FieldValue.delete(),
      };

      if (weeks != null && weeks.length > 1) {
        docData['weeks_encrypted'] =
            encryptionService.encryptData({'weeks': weeks}, user.uid);
      }

      // [FIX 2026-05-25] Persisti la `config` (days/meals/relaxable_foods)
      // accanto ai campi crittografati. Senza questo, l'ordine esplicito di
      // giorni/pasti veniva perso al primo sync da cloud, e l'app cadeva nel
      // fallback fragile (sort tramite _globalDays, iterazione Map keys, etc.)
      // → giorni nell'ordine sbagliato in TabController, pasti disordinati.
      //
      // Nota: `config` è scritta in chiaro (non `config_encrypted`). I dati
      // contenuti (nomi dei giorni, dei pasti, alimenti rilassati come "mela")
      // non sono PII, e in chiaro mantengono compatibilità con il fossile
      // top-level già presente sui doc pre-encryption esistenti.
      if (config != null) {
        docData['config'] = config;
      }

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('diets')
          .doc('current')
          .set(docData, SetOptions(merge: true));

      debugPrint("✅ Dieta 'current' aggiornata (encrypted, ${weeks?.length ?? 1} settimane, config=${config != null}).");
      return true;
    } catch (e) {
      debugPrint("⚠️ Errore salvataggio current: $e");
      return false;
    }
  }

  Future<String> saveDietToHistory(
    Map<String, dynamic> plan,
    Map<String, dynamic> subs,
    Map<String, dynamic> swaps, {
    List<dynamic>? weeks,
    Map<String, dynamic>? config,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User null");

      final encryptionService = EncryptionService();

      final encryptedPlan = encryptionService.encryptData(plan, user.uid);
      final encryptedSubs = encryptionService.encryptData(subs, user.uid);
      final encryptedSwaps = encryptionService.encryptData(swaps, user.uid);

      final Map<String, dynamic> docData = {
        'uploadedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'plan_encrypted': encryptedPlan,
        'substitutions_encrypted': encryptedSubs,
        'activeSwaps_encrypted': encryptedSwaps,
        'encrypted': true,
      };

      if (weeks != null && weeks.length > 1) {
        docData['weeks_encrypted'] =
            encryptionService.encryptData({'weeks': weeks}, user.uid);
      }

      // [FIX 2026-05-25] Vedi commento in saveCurrentDiet. Persistiamo `config`
      // anche nello storico così le diete storiche restaurate via Ripristina
      // hanno ordine giorni/pasti corretto al volo.
      if (config != null) {
        docData['config'] = config;
      }

      final docRef =
          await _db.collection('users').doc(user.uid).collection('diets').add(docData);

      debugPrint("✅ Dieta salvata nello storico (encrypted, ${weeks?.length ?? 1} settimane, config=${config != null}).");
      return docRef.id;
    } catch (e) {
      debugPrint("⚠️ Errore storico: $e");
      rethrow;
    }
  }

  Future<void> updateDietHistory(
    String docId,
    Map<String, dynamic> plan,
    Map<String, dynamic> subs,
    Map<String, dynamic> swaps, {
    List<dynamic>? weeks,
    Map<String, dynamic>? config,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final encryptionService = EncryptionService();

      final encryptedPlan = encryptionService.encryptData(plan, user.uid);
      final encryptedSubs = encryptionService.encryptData(subs, user.uid);
      final encryptedSwaps = encryptionService.encryptData(swaps, user.uid);

      final Map<String, dynamic> updateData = {
        'lastUpdated': FieldValue.serverTimestamp(),
        'plan_encrypted': encryptedPlan,
        'substitutions_encrypted': encryptedSubs,
        'activeSwaps_encrypted': encryptedSwaps,
        'encrypted': true,
      };

      if (weeks != null && weeks.length > 1) {
        updateData['weeks_encrypted'] =
            encryptionService.encryptData({'weeks': weeks}, user.uid);
      }

      // [FIX 2026-05-25] Vedi saveCurrentDiet.
      if (config != null) {
        updateData['config'] = config;
      }

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('diets')
          .doc(docId)
          .update(updateData);

      debugPrint("🔄 Dieta $docId aggiornata su Cloud (encrypted, ${weeks?.length ?? 1} settimane, config=${config != null}).");
    } catch (e) {
      debugPrint("⚠️ Errore aggiornamento storico: $e");
      rethrow;
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
        .map((snapshot) {
      final encryptionService = EncryptionService();

      return snapshot.docs.where((doc) => doc.id != 'current').map((doc) {
        final data = doc.data();
        final isEncrypted = data['encrypted'] == true;

        if (isEncrypted) {
          try {
            final decryptedPlan = encryptionService.decryptData(
              data['plan_encrypted'] as String,
              user.uid,
            );

            final decryptedSubs = encryptionService.decryptData(
              data['substitutions_encrypted'] as String,
              user.uid,
            );

            final decryptedSwaps = encryptionService.decryptData(
              data['activeSwaps_encrypted'] as String,
              user.uid,
            );

            return {
              'id': doc.id,
              'plan': decryptedPlan,
              'substitutions': decryptedSubs,
              'activeSwaps': decryptedSwaps,
              'uploadedAt': data['uploadedAt'],
              'lastUpdated': data['lastUpdated'],
            };
          } catch (e) {
            debugPrint('❌ Errore decryption history item: $e');
            return {'id': doc.id, 'error': 'decryption_failed'};
          }
        } else {
          return {'id': doc.id, ...data};
        }
      }).toList();
    });
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

  Future<Map<String, dynamic>?> fetchGlobalConfig() async {
    try {
      final doc = await _db.collection('app_config').doc('constants').get();
      if (doc.exists) {
        debugPrint("🌍 Global Config caricata da Firestore");
        return doc.data();
      }
    } catch (e) {
      debugPrint("⚠️ Errore caricamento Global Config: $e");
    }
    return null;
  }

}
