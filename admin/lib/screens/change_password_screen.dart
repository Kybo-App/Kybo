// Schermata obbligatoria al primo accesso: forza il cambio della password temporanea.
// _updatePassword — aggiorna Auth e sblocca il flag requires_password_change su Firestore.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (_passCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pwdMismatch)),
      );
      return;
    }

    // [SECURITY] Valida la password lato client prima di chiamare Firebase Auth,
    // allineandosi con la policy del server (min 12 caratteri, maiuscola, minuscola, numero).
    final pass = _passCtrl.text.trim();
    if (pass.length < 12 ||
        !pass.contains(RegExp(r'[A-Z]')) ||
        !pass.contains(RegExp(r'[a-z]')) ||
        !pass.contains(RegExp(r'[0-9]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pwdPolicyError)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await user.updatePassword(pass);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'requires_password_change': false},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pwdChangeError)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      body: Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  l10n.pwdSecurityUpdate,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.pwdWelcome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.pwdNew,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.pwdConfirm,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(l10n.pwdSet),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(l10n.logout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
