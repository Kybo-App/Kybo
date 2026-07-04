// Schermata di verifica email, mostrata dall'EmailVerificationGuard finché il
// flag requires_email_verification è true su Firestore.
//
// Flusso: all'apertura invia il link di verifica → l'utente clicca il link nella
// mail → torna qui e preme "Ho verificato". La conferma reale la fa il server
// (Admin SDK controlla email_verified, non falsificabile) tramite
// /profile/complete-email-verification, che azzera il flag: lo stream del guard
// se ne accorge e mostra l'app.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_client.dart';
import '../widgets/design_system.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _sending = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Invia subito il link (copre anche gli account creati dall'admin, per cui
    // il backend non manda nessuna mail alla creazione).
    _sendInitial();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendInitial() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _startCooldown();
      }
    } catch (_) {
      // Silenzioso: se Firebase limita l'invio, l'utente può usare "Invia di nuovo".
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utente non loggato");
      // Aggiorna lo stato locale (dopo il click sul link in un altro tab/device).
      await user.reload();
      // Il server verifica davvero email_verified via Admin SDK e azzera il flag;
      // se non è ancora verificata risponde 400.
      await ApiClient().post('/profile/complete-email-verification');
      // Successo: requires_email_verification → false, il guard mostra l'app.
    } on ApiException catch (e) {
      if (mounted) {
        _showError(e.statusCode == 400
            ? "Email non ancora verificata. Apri la mail che ti abbiamo inviato (controlla anche lo spam) e clicca il link."
            : e.message);
      }
    } catch (_) {
      if (mounted) _showError("Qualcosa è andato storto. Riprova.");
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _startCooldown();
      if (mounted) _showInfo("Email di verifica inviata di nuovo.");
    } catch (_) {
      if (mounted) _showError("Troppi tentativi. Riprova tra qualche minuto.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) => _showSnack(message, KyboColors.error);
  void _showInfo(String message) => _showSnack(message, KyboColors.success);

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  "Verifica la tua email",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: KyboColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Ti abbiamo inviato un link di verifica a:",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KyboColors.textSecondary(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KyboColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Apri la mail e clicca il link, poi torna qui e premi il pulsante.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: KyboColors.textMuted(context), fontSize: 13),
                ),
                const SizedBox(height: 32),
                PillButton(
                  label: "HO VERIFICATO L'EMAIL",
                  icon: Icons.check_rounded,
                  isLoading: _checking,
                  onPressed: _checking ? null : _checkVerified,
                  height: 50,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_sending || _cooldown > 0) ? null : _resend,
                  child: Text(
                    _cooldown > 0
                        ? "Invia di nuovo tra ${_cooldown}s"
                        : "Invia di nuovo l'email",
                    style: TextStyle(
                      color: (_sending || _cooldown > 0)
                          ? KyboColors.textMuted(context)
                          : KyboColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(
                    "Esci",
                    style: TextStyle(color: KyboColors.textSecondary(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
