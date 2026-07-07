// Schermata di verifica email (app admin), mostrata dall'EmailVerificationGuard
// finché il flag requires_email_verification è true su Firestore.
//
// La conferma reale la fa il server (Admin SDK controlla email_verified, non
// falsificabile) via /profile/complete-email-verification, che azzera il flag:
// lo stream del guard se ne accorge e mostra il resto dell'app.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
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
      // Silenzioso: se Firebase limita l'invio, resta il pulsante "Invia di nuovo".
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
    final l10n = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      await AdminRepository().completeEmailVerification();
      // Successo: requires_email_verification → false, il guard mostra l'app.
    } on ApiStatusException catch (e) {
      if (mounted) {
        _showSnack(
            e.statusCode == 400 ? l10n.verifyEmailNotYet : e.message,
            KyboColors.error);
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.verifyEmailError, KyboColors.error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _startCooldown();
      if (mounted) _showSnack(l10n.verifyEmailSentAgain, KyboColors.success);
    } catch (_) {
      if (mounted) _showSnack(l10n.verifyEmailTooMany, KyboColors.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: KyboColors.background,
      body: Center(
        child: Card(
          elevation: 4,
          // Il cardTheme dell'app forza bianco: serve il colore esplicito
          // perché il dark mode admin vive in KyboColors, non nel ThemeData.
          color: KyboColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  l10n.verifyEmailTitle,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: KyboColors.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.verifyEmailSentTo,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KyboColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: KyboColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.verifyEmailInstructions,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KyboColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _checking ? null : _checkVerified,
                    child: _checking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(l10n.verifyEmailDone),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: (_sending || _cooldown > 0) ? null : _resend,
                  child: Text(
                    _cooldown > 0
                        ? l10n.verifyEmailResendIn(_cooldown)
                        : l10n.verifyEmailResend,
                  ),
                ),
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
