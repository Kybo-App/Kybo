// Crittografia AES-256-CBC dei dati sensibili (GDPR). Formato v2: IV random prepeso al ciphertext.
// encryptData — cripta una Map in Base64 con IV random; decryptData — supporta formato v1 (legacy IV deterministico) e v2.
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

  String encryptList(List<String> items, String uid) {
    return encryptData({'items': items}, uid);
  }

  List<String> decryptList(String encryptedBase64, String uid) {
    final data = decryptData(encryptedBase64, uid);
    return (data['items'] as List).cast<String>();
  }
}
