// Schermata obbligatoria al primo accesso: forza il cambio della password temporanea.
// _updatePassword — aggiorna Auth e sblocca il flag requires_password_change su Firestore.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../widgets/design_system.dart';
import '../widgets/password_checklist.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  // Password già aggiornata su Firebase Auth ma finalizzazione lato server
  // fallita (rete): al retry saltiamo updatePassword e riproviamo solo il server.
  bool _passwordChanged = false;

  bool get _canSubmit =>
      KyboPasswordChecklist.isValid(_passCtrl.text) &&
      _passCtrl.text == _confirmCtrl.text;

  bool get _passwordsMismatch =>
      _confirmCtrl.text.isNotEmpty && _passCtrl.text != _confirmCtrl.text;

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

      // Passo 1 (una sola volta): aggiorna la password su Firebase Auth.
      if (!_passwordChanged) {
        await user.updatePassword(pass);
        _passwordChanged = true;
      }

      // Passo 2: il flag va azzerato lato server (Admin SDK): le Firestore
      // rules non permettono ai professionisti creati dall'admin di modificarlo
      // da soli. Se fallisce, _passwordChanged resta true e al retry si salta
      // il passo 1.
      await AdminRepository().completePasswordChange();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _passwordChanged ? l10n.pwdFinalizeRetry : l10n.pwdChangeError),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: KyboColors.background,
      body: Center(
        child: Card(
          elevation: 4,
          // Il cardTheme dell'app forza bianco: serve il colore esplicito
          // perché il dark mode admin vive in KyboColors, non nel ThemeData.
          color: KyboColors.surface,
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
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: KyboColors.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.pwdWelcome,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KyboColors.textSecondary),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: KyboColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.pwdNew,
                    labelStyle: TextStyle(color: KyboColors.textSecondary),
                    filled: true,
                    // L'inputDecorationTheme dell'app riempie di grigio chiaro:
                    // serve il fill esplicito per il dark mode.
                    fillColor: KyboColors.background,
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock, color: KyboColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                // Requisiti password live — si spuntano mentre digiti.
                Align(
                  alignment: Alignment.centerLeft,
                  child: KyboPasswordChecklist(password: _passCtrl.text),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: KyboColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.pwdConfirm,
                    labelStyle: TextStyle(color: KyboColors.textSecondary),
                    filled: true,
                    fillColor: KyboColors.background,
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.lock_outline, color: KyboColors.textMuted),
                  ),
                ),
                // Errore inline vicino al campo che non va.
                if (_passwordsMismatch) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.pwdMismatch,
                      style: const TextStyle(
                          color: KyboColors.error, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    // Grigio automatico finché non è tutto valido.
                    onPressed:
                        (_isLoading || !_canSubmit) ? null : _updatePassword,
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
