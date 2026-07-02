// Schermata cambio password con validazione complessità (min 12 caratteri, maiuscole, minuscole, numeri).
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/error_handler.dart';
import '../services/api_client.dart';
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

  /// Submit abilitato solo se la password rispetta la policy E le due
  /// password coincidono (ep6.1: niente submit finché non è tutto valido).
  bool get _canSubmit =>
      KyboPasswordChecklist.isValid(_passCtrl.text) &&
      _passCtrl.text == _confirmCtrl.text;

  bool get _passwordsMismatch =>
      _confirmCtrl.text.isNotEmpty && _passCtrl.text != _confirmCtrl.text;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_passCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) return;

    if (_passCtrl.text != _confirmCtrl.text) {
      _showError("Le password non coincidono");
      return;
    }
    if (_passCtrl.text.length < 12) {
      _showError("La password deve avere almeno 12 caratteri");
      return;
    }
    final hasUppercase = _passCtrl.text.contains(RegExp(r'[A-Z]'));
    final hasLowercase = _passCtrl.text.contains(RegExp(r'[a-z]'));
    final hasDigit = _passCtrl.text.contains(RegExp(r'[0-9]'));
    if (!hasUppercase || !hasLowercase || !hasDigit) {
      _showError("La password deve contenere maiuscole, minuscole e numeri");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utente non loggato");

      await user.updatePassword(_passCtrl.text);

      // Azzera requires_password_change lato server (Admin SDK): le Firestore
      // rules non permettono al client di modificare questo campo da solo,
      // quindi senza questa chiamata il PasswordGuard resterebbe in loop.
      await ApiClient().post('/profile/complete-password-change');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Password aggiornata con successo!"),
            backgroundColor: KyboColors.success,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Da Impostazioni la schermata è una rotta pushata → la chiudiamo.
        // Dal PasswordGuard non c'è nulla da chiudere: si sgancia da solo
        // quando il flag su Firestore diventa false.
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError(ErrorMapper.toUserMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: KyboColors.error,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        title: Text(
          "Cambia Password",
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        iconTheme: IconThemeData(color: KyboColors.textPrimary(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(Icons.lock_reset, size: 80, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  "Inserisci la tua nuova password.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KyboColors.textSecondary(context), fontSize: 16),
                ),
                const SizedBox(height: 32),
                PillTextField(
                  controller: _passCtrl,
                  showPasswordToggle: true,
                  labelText: "Nuova Password",
                  prefixIcon: Icons.lock,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Requisiti password live — si spuntano mentre digiti (ep6.5).
                Align(
                  alignment: Alignment.centerLeft,
                  child: KyboPasswordChecklist(password: _passCtrl.text),
                ),
                const SizedBox(height: 16),
                PillTextField(
                  controller: _confirmCtrl,
                  showPasswordToggle: true,
                  labelText: "Conferma Password",
                  prefixIcon: Icons.lock_outline,
                  onChanged: (_) => setState(() {}),
                ),
                // Errore inline vicino al campo che non va (ep7).
                if (_passwordsMismatch) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 16, color: KyboColors.error),
                        const SizedBox(width: 6),
                        Text(
                          "Le password non coincidono",
                          style: TextStyle(
                              color: KyboColors.error, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PillButton(
                  label: "AGGIORNA PASSWORD",
                  isLoading: _isLoading,
                  onPressed: (_isLoading || !_canSubmit) ? null : _changePassword,
                  // Grigio finché non è tutto valido (ep6.1).
                  backgroundColor:
                      _canSubmit ? KyboColors.primary : KyboColors.border(context),
                  textColor:
                      _canSubmit ? Colors.white : KyboColors.textMuted(context),
                  height: 50,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
