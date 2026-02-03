import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'encryption_service.dart'; // ✅ AGGIUNGI

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveCurrentDiet(
    Map<String, dynamic> plan,
    Map<String, dynamic> subs,
    Map<String, dynamic> swaps,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // ✅ Cripta dati sensibili prima di salvare
      final encryptionService = EncryptionService();

      final encryptedPlan = encryptionService.encryptData(plan, user.uid);
      final encryptedSubs = encryptionService.encryptData(subs, user.uid);
      final encryptedSwaps = encryptionService.encryptData(swaps, user.uid);

      // Sovrascriviamo SEMPRE 'current' con versione criptata
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('diets')
          .doc('current')
          .set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'plan_encrypted': encryptedPlan, // ✅ Criptato
        'substitutions_encrypted': encryptedSubs, // ✅ Criptato
        'activeSwaps_encrypted': encryptedSwaps, // ✅ Criptato
        'encrypted': true, // ✅ Flag
      }, SetOptions(merge: true));

      debugPrint("✅ Dieta 'current' aggiornata (encrypted).");
    } catch (e) {
      debugPrint("⚠️ Errore salvataggio current: $e");
    }
  }

  Future<String> saveDietToHistory(
    Map<String, dynamic> plan,
    Map<String, dynamic> subs,
    Map<String, dynamic> swaps,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User null");

      // ✅ Cripta dati sensibili
      final encryptionService = EncryptionService();

      final encryptedPlan = encryptionService.encryptData(plan, user.uid);
      final encryptedSubs = encryptionService.encryptData(subs, user.uid);
      final encryptedSwaps = encryptionService.encryptData(swaps, user.uid);

      // Salva nello storico (criptato)
      final docRef =
          await _db.collection('users').doc(user.uid).collection('diets').add({
        'uploadedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'plan_encrypted': encryptedPlan, // ✅ Criptato
        'substitutions_encrypted': encryptedSubs, // ✅ Criptato
        'activeSwaps_encrypted': encryptedSwaps, // ✅ Criptato
        'encrypted': true, // ✅ Flag
      });

      debugPrint("✅ Dieta salvata nello storico (encrypted).");
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
    Map<String, dynamic> swaps,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // ✅ Cripta dati sensibili
      final encryptionService = EncryptionService();

      final encryptedPlan = encryptionService.encryptData(plan, user.uid);
      final encryptedSubs = encryptionService.encryptData(subs, user.uid);
      final encryptedSwaps = encryptionService.encryptData(swaps, user.uid);

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('diets')
          .doc(docId)
          .update({
        'lastUpdated': FieldValue.serverTimestamp(),
        'plan_encrypted': encryptedPlan, // ✅ Criptato
        'substitutions_encrypted': encryptedSubs, // ✅ Criptato
        'activeSwaps_encrypted': encryptedSwaps, // ✅ Criptato
        'encrypted': true, // ✅ Flag
      });

      debugPrint("🔄 Dieta $docId aggiornata su Cloud (encrypted).");
    } catch (e) {
      debugPrint("⚠️ Errore aggiornamento storico: $e");
      rethrow;
    }
  }

  Stream<Map<String, dynamic>?> getDietStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('diets')
        .doc('current')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data()!;

      // ✅ Controlla se i dati sono criptati
      final isEncrypted = data['encrypted'] == true;

      if (isEncrypted) {
        try {
          final encryptionService = EncryptionService();

          // Decripta tutti i campi
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

          // Ricostruisci formato originale
          return {
            'plan': decryptedPlan,
            'substitutions': decryptedSubs,
            'activeSwaps': decryptedSwaps,
            'lastUpdated': data['lastUpdated'],
            'uploadedAt': data['uploadedAt'],
          };
        } catch (e) {
          debugPrint('❌ Errore decryption stream: $e');
          return null;
        }
      } else {
        // Backward compatibility: dati vecchi non criptati
        debugPrint('⚠️ Stream data (unencrypted - legacy format)');
        return data;
      }
    });
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

      // Filtra il documento 'current' che non è history
      return snapshot.docs.where((doc) => doc.id != 'current').map((doc) {
        final data = doc.data();
        final isEncrypted = data['encrypted'] == true;

        if (isEncrypted) {
          try {
            // Decripta
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
          // Legacy format
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

  // --- CONFIGURAZIONE GLOBALE (Step 11 & 12) ---
  Future<Map<String, dynamic>?> fetchGlobalConfig() async {
    try {
      // Usa una collection pubblica o accessibile agli utenti autenticati
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

  // --- UTILITY ADMIN (Da usare solo per init) ---
  Future<void> uploadDefaultGlobalConfig() async {
    try {
      final List<String> foods = [
        "mela", "mele", "pera", "pere", "banana", "banane", "arancia", "arance",
        "mandarino", "mandarini", "clementina", "clementine", "pompelmo", "pompelmi",
        "limone", "limoni", "succo di limone", "lime",
        "ananas", "kiwi", "pesca", "pesche", "albicocca", "albicocche", "prugna", "prugne",
        "fragola", "fragole", "ciliegia", "ciliegie", "frutti di bosco", "mirtilli", "lamponi", "more",
        "fichi", "uva", "caco", "cachi", "anguria", "melone", "melone giallo", "melone retato",
        "zucchina", "zucchine", "melanzana", "melanzane", "pomodoro", "pomodori", "pomodorini",
        "cetriolo", "cetrioli", "finocchio", "finocchi", "sedano", "gambo di sedano",
        "lattuga", "insalata", "insalata mista", "iceberg", "rucola", "valeriana", "radicchio", "indivia", "scarola",
        "spinaci", "bieta", "bietole", "cicoria", "cime di rapa", "friarielli",
        "broccolo", "broccoli", "cavolfiore", "cavolfiori", "verza", "cavolo cappuccio", "cavolo nero", "cavoletti di bruxelles",
        "fagiolini", "taccole", "asparagi", "carciofo", "carciofi",
        "zucca", "fiori di zucca",
        "peperone", "peperoni", "friggitelli",
        "carota", "carote", "ravanelli",
        "funghi", "champignon", "porcini",
        "minestrone", "minestrone di verdure", "passato di verdure", "vellutata di verdure", "ortaggi", "verdure grigliate",
        "caffè", "caffe", "caffe amaro", "caffè senza zucchero",
        "tè", "the", "tè verde", "tisana", "infuso",
        "acqua", "acqua naturale", "acqua frizzante",
        "aceto", "aceto di mele", "aceto balsamico", "succo di limone", "spezie", "erbe aromatiche"
      ];
      
      final List<String> days = [
        "Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"
      ];
      
      final List<String> meals = [
        "Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"
      ];

      await _db.collection('app_config').doc('constants').set({
        'relaxable_foods': foods,
        'default_days': days,
        'default_meals': meals,
      });
      debugPrint("✅ Configurazione Globale caricata su Firestore!");
    } catch (e) {
      debugPrint("❌ Errore upload config: $e");
    }
  }
}
