import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/error_handler.dart'; // [IMPORTANTE]
import '../widgets/design_system.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
  bool _obscurePassword = true;    // [NEW] Toggle visibilità password
  bool _obscureConfirm = true;     // [NEW] Toggle visibilità conferma

  Future<void> _changePassword() async {
    if (_passCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) return;

    if (_passCtrl.text != _confirmCtrl.text) {
      _showError("Le password non coincidono");
      return;
    }
    // [SECURITY] Password minima aumentata a 12 caratteri
    if (_passCtrl.text.length < 12) {
      _showError("La password deve avere almeno 12 caratteri");
      return;
    }
    // [SECURITY] Verifica complessità password
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Password aggiornata con successo!"),
            backgroundColor: KyboColors.success,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        // [UX] Errore tradotto
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
                ),
                const SizedBox(height: 16),
                PillTextField(
                  controller: _confirmCtrl,
                  showPasswordToggle: true,
                  labelText: "Conferma Password",
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 24),
                PillButton(
                  label: "AGGIORNA PASSWORD",
                  isLoading: _isLoading,
                  onPressed: _changePassword,
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
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
