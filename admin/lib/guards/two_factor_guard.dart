import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';

/// Guard che blocca l'accesso se l'utente ha 2FA attivo
/// e non ha ancora verificato il codice TOTP per questa sessione.
class TwoFactorGuard extends StatefulWidget {
  final Widget child;
  const TwoFactorGuard({super.key, required this.child});

  @override
  State<TwoFactorGuard> createState() => _TwoFactorGuardState();
}

class _TwoFactorGuardState extends State<TwoFactorGuard> {
  bool _isVerified = false;

  @override
  Widget build(BuildContext context) {
    if (_isVerified) return widget.child;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return widget.child;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final has2FA = data?['two_factor_enabled'] == true;

        if (!has2FA) {
          return widget.child;
        }

        // 2FA attivo ma non ancora verificato: mostra schermata TOTP
        return _TwoFactorVerifyScreen(
          onVerified: () {
            if (mounted) setState(() => _isVerified = true);
          },
        );
      },
    );
  }
}

class _TwoFactorVerifyScreen extends StatefulWidget {
  final VoidCallback onVerified;
  const _TwoFactorVerifyScreen({required this.onVerified});

  @override
  State<_TwoFactorVerifyScreen> createState() =>
      _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState extends State<_TwoFactorVerifyScreen> {
  final AdminRepository _repo = AdminRepository();
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = "Inserisci il codice");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final valid = await _repo.validate2FA(code);
      if (valid) {
        widget.onVerified();
      } else {
        setState(() => _error = "Codice non valido. Riprova.");
      }
    } catch (e) {
      setState(() => _error = "Errore di verifica. Riprova.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: KyboColors.surface,
            borderRadius: KyboBorderRadius.large,
            boxShadow: KyboColors.mediumShadow,
            border: Border.all(color: KyboColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  borderRadius: KyboBorderRadius.large,
                ),
                child: const Icon(
                  Icons.security_rounded,
                  size: 44,
                  color: KyboColors.primary,
                ),
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                "Verifica 2FA",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: KyboColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Inserisci il codice dalla tua app di autenticazione",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KyboColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 36),

              // Code Input
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: KyboColors.background,
                  borderRadius: KyboBorderRadius.pill,
                  border: Border.all(
                    color: _error != null ? KyboColors.error : KyboColors.border,
                  ),
                ),
                child: TextField(
                  controller: _codeCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verify(),
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: "000000",
                    hintStyle: TextStyle(
                      color: KyboColors.textMuted,
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 8,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: KyboColors.error,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Text(
                "Puoi anche usare un codice di backup",
                style: TextStyle(
                  color: KyboColors.textMuted,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 28),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: "VERIFICA",
                  icon: Icons.verified_user_rounded,
                  backgroundColor: KyboColors.primary,
                  textColor: Colors.white,
                  height: 52,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _verify,
                ),
              ),

              const SizedBox(height: 16),

              // Logout link
              TextButton(
                onPressed: _logout,
                child: Text(
                  "Torna al login",
                  style: TextStyle(
                    color: KyboColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
