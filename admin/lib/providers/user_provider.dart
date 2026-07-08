// Provider condiviso del profilo utente corrente (ruolo + nome).
//
// [COERENZA 2026-07-07] Prima OGNI view (RoleCheckScreen, dashboard,
// analytics, reports, matchmaking, my day) rileggeva users/{uid} da Firestore
// per conto suo a ogni mount — quindi anche a ogni cambio tema, che rimonta
// le view — e teneva una copia locale del ruolo che poteva divergere dalle
// altre. Ora il documento si legge UNA volta per login (ensureLoaded è
// idempotente) e il provider si resetta da solo al logout ascoltando
// authStateChanges.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProvider extends ChangeNotifier {
  UserProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _clear();
      } else if (user.uid != _uid) {
        _loadFuture = _load(user.uid);
      }
    });
  }

  StreamSubscription<User?>? _authSub;
  Future<void>? _loadFuture;

  bool _isLoaded = false;
  String _uid = '';
  String _firstName = '';
  String _userName = '';
  String _role = '';

  bool get isLoaded => _isLoaded;
  String get uid => _uid;
  String get firstName => _firstName;

  /// Nome completo ("Nome Cognome"), fallback "Utente".
  String get userName => _userName;
  String get role => _role;

  bool get isAdmin => _role == 'admin';

  // Semantica identica a quella che aveva il dashboard: l'admin "conta"
  // anche come nutrizionista e PT ai fini della visibilità delle tab.
  bool get isNutritionist => _role == 'nutritionist' || isAdmin;
  bool get isPT => _role == 'personal_trainer' || isAdmin;

  /// Ruoli ammessi al pannello admin (stesso set di verify_professional
  /// lato server e del gate RoleCheckScreen).
  bool get isProfessional =>
      _role == 'admin' ||
      _role == 'nutritionist' ||
      _role == 'personal_trainer';

  /// Garantisce che il profilo sia caricato (idempotente: la lettura
  /// Firestore avviene una sola volta per login).
  Future<void> ensureLoaded() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Future.value();
    if (_isLoaded && _uid == user.uid) return Future.value();
    return _loadFuture ??= _load(user.uid);
  }

  Future<void> _load(String uid) async {
    // _uid impostato SUBITO (non dopo l'await): così se il listener di
    // authStateChanges e ensureLoaded scattano insieme al login, il secondo
    // vede l'uid già "prenotato" e non parte una seconda lettura.
    _uid = uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      _firstName = (data['first_name'] ?? '').toString();
      _userName =
          "${data['first_name'] ?? 'Utente'} ${data['last_name'] ?? ''}"
              .trim();
      _role = (data['role'] ?? '').toString();
    } catch (_) {
      // Lettura fallita (rete/permessi): profilo minimo con ruolo vuoto.
      // I gate a valle (RoleCheckScreen) trattano il ruolo vuoto come
      // non-professionale → accesso negato, fail-closed.
      _firstName = '';
      _userName = '';
      _role = '';
    }
    _isLoaded = true;
    notifyListeners();
  }

  void _clear() {
    _isLoaded = false;
    _loadFuture = null;
    _uid = '';
    _firstName = '';
    _userName = '';
    _role = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
