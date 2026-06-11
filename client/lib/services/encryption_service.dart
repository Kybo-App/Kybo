// Offuscamento AES-256-CBC dei dati dieta su Firestore. Formato v2: IV
// random prepeso al ciphertext.
//
// ⚠️ [SECURITY — leggere prima di farci affidamento]
// La chiave è derivata SOLO dall'UID Firebase (vedi _generateKeyFromUid):
//   key = SHA256(uid + salt)  dove anche `salt` deriva da SHA256(uid).
// L'UID NON è segreto — è il path del documento (`users/{uid}/diets/...`),
// viaggia nei token, nelle richieste API e nei documenti stessi. Chi ottiene
// un dump Firestero ha quindi ANCHE ogni UID, e con l'algoritmo (open source)
// può ricavare ogni chiave e decifrare tutto.
//
// → Questo è OFFUSCAMENTO, non cifratura forte: ferma chi guarda casualmente
//   la console Firestore in plaintext, NON un attaccante che conosce lo schema.
//
// La protezione REALE dei dati a riposo è data da:
//   1. le Firestore Security Rules (owner/nutri/admin) — controllo accessi;
//   2. la cifratura at-rest automatica di Firestore (chiavi gestite da Google).
//
// Una cifratura davvero robusta richiederebbe una chiave/pepper SEGRETA non
// co-locata col ciphertext → impossibile lato client (estraibile dall'APK),
// va fatta server-side. Tracciato in TODO.md ("Cifratura dieta server-side").
//
// NB: NON cambiare _generateKeyFromUid senza una migrazione: romperebbe la
// decifratura di tutte le diete v2 già salvate.
import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const int _formatVersion = 2;

  enc.Key _generateKeyFromUid(String uid) {
    final uidHash = sha256.convert(utf8.encode(uid)).toString();
    final salt = 'kybo_v2_${uidHash.substring(0, 16)}';
    final keyMaterial = '$uid:$salt';
    final bytes = sha256.convert(utf8.encode(keyMaterial)).bytes;
    return enc.Key(Uint8List.fromList(bytes));
  }

  Uint8List _generateRandomIV() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  String encryptData(Map<String, dynamic> data, String uid) {
    try {
      final key = _generateKeyFromUid(uid);
      final ivBytes = _generateRandomIV();
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final jsonString = jsonEncode(data);
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      final combined = Uint8List(_formatVersion == 2 ? 1 + 16 + encrypted.bytes.length : encrypted.bytes.length);
      combined[0] = _formatVersion;
      combined.setRange(1, 17, ivBytes);
      combined.setRange(17, combined.length, encrypted.bytes);

      final result = base64Encode(combined);
      debugPrint('🔒 Data encrypted v$_formatVersion (length: ${result.length})');
      return result;
    } catch (e) {
      debugPrint('❌ Encryption error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> decryptData(String encryptedBase64, String uid) {
    try {
      final key = _generateKeyFromUid(uid);
      final combined = base64Decode(encryptedBase64);

      enc.IV iv;
      Uint8List ciphertext;

      if (combined.length > 17 && combined[0] == 2) {
        iv = enc.IV(Uint8List.fromList(combined.sublist(1, 17)));
        ciphertext = Uint8List.fromList(combined.sublist(17));
        debugPrint('🔓 Decrypting v2 format');
      } else {
        final uidHash = sha256.convert(utf8.encode('${uid}_iv')).bytes;
        iv = enc.IV(Uint8List.fromList(uidHash.sublist(0, 16)));
        ciphertext = Uint8List.fromList(combined);
        debugPrint('🔓 Decrypting v1 legacy format');
      }

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt(enc.Encrypted(ciphertext), iv: iv);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;

      debugPrint('🔓 Data decrypted successfully');
      return data;
    } catch (e) {
      debugPrint('❌ Decryption error: $e');
      rethrow;
    }
  }

}
