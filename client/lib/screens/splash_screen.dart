// Splash screen con gestione deep link invito, autenticazione e routing verso onboarding o home.
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
    final initialUri = await DeepLinkService().init();
    final inviteCode = DeepLinkService.getInviteCode(initialUri);

    if (inviteCode != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(inviteCode: inviteCode),
        ),
      );
      return;
    }

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = AuthService().currentUser;

    if (user != null) {
      AuthService().updateLastLogin(user.uid);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
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
            Image.asset(
              'assets/icon/icon_nobg.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.eco,
                  size: 100,
                  color: KyboColors.primary,
                );
              },
            ),

            const SizedBox(height: 30),

            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(KyboColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
