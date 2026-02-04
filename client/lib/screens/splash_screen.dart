import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import '../widgets/design_system.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // 1. Check Deep Link first (can happen cold start)
    final initialUri = await DeepLinkService().init();
    final inviteCode = DeepLinkService.getInviteCode(initialUri);

    if (inviteCode != null && mounted) {
      // Deep Link Invite -> Go directly to Login/Register with code
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(inviteCode: inviteCode),
        ),
      );
      return;
    }

    // 2. Normal flow with min delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = AuthService().currentUser;

    if (user != null) {
      // Aggiorna l'ultimo accesso anche se l'utente è già loggato
      AuthService().updateLastLogin(user.uid);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      // Not logged in -> Onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // [FIX] LOGO APP (Assicurati che il file esista in assets!)
            // Se il file si chiama diversamente (es. icon.png), cambia la stringa qui sotto.
            Image.asset(
              'assets/icon/icon.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                // Fallback nel caso l'immagine non venga trovata (per evitare crash)
                return const Icon(
                  Icons.eco,
                  size: 100,
                  color: KyboColors.primary,
                );
              },
            ),

            const SizedBox(height: 30),

            // Loading con colore del brand
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(KyboColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
