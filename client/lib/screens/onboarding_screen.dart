import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _navigateToLogin(BuildContext context, {bool isIndependent = false}) {
    // Navigate to Login/Register.
    // In a real flow, we might pass a flag to Registration screen.
    // For now, let's go to LoginScreen which should have a "Register" option.
    // We can simulate passing data via arguments if needed.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(isIndependent: isIndependent),
      ),
    );
  }

  void _handleInviteCode(BuildContext context) {
    // Show dialog to enter code manually if not via deep link
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: const Text("Hai un codice invito?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Inserisci il codice fornito dal tuo nutrizionista."),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Es. ABC-123",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annulla"),
          ),
          PillButton(
            label: "Avanti",
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(inviteCode: controller.text),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo & Title
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: KyboColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 40,
                    color: KyboColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Benvenuto in Kybo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "La tua nutrizione, semplificata.\nScegli come vuoi iniziare.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: KyboColors.textSecondary(context),
                ),
              ),
              const Spacer(),

              // Options
              _buildOptionCard(
                context,
                icon: Icons.person_pin_circle_rounded,
                title: "Ho un Nutrizionista",
                subtitle: "Usa un codice invito per collegarti.",
                onTap: () => _handleInviteCode(context),
              ),
              const SizedBox(height: 16),
              _buildOptionCard(
                context,
                icon: Icons.fitness_center_rounded,
                title: "Utente Indipendente",
                subtitle: "Gestisci la tua dieta autonomamente.",
                onTap: () => _navigateToLogin(context, isIndependent: true),
                isSecondary: true,
              ),

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Hai già un account? ",
                    style: TextStyle(color: KyboColors.textSecondary(context)),
                  ),
                  GestureDetector(
                    onTap: () => _navigateToLogin(context),
                    child: const Text(
                      "Accedi",
                      style: TextStyle(
                        color: KyboColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: KyboColors.surface(context),
          borderRadius: KyboBorderRadius.large,
          border: Border.all(
            color: isSecondary ? KyboColors.border(context) : KyboColors.primary,
            width: isSecondary ? 1 : 2,
          ),
          boxShadow: isSecondary ? null : [
            BoxShadow(
              color: KyboColors.primary.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSecondary
                    ? KyboColors.background(context)
                    : KyboColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSecondary ? KyboColors.textSecondary(context) : KyboColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: KyboColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: KyboColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: KyboColors.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}
