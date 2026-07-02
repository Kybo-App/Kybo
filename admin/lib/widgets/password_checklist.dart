// Checklist requisiti password che si spunta MENTRE l'utente digita.
// Versione admin (colori static + label localizzate IT/EN via AppLocalizations).
//
// Policy allineata a server + client: min 12 caratteri, una maiuscola, una
// minuscola, un numero. `KyboPasswordChecklist.isValid(pwd)` è la fonte unica
// di verità: usala per abilitare/disabilitare il submit.
import 'package:flutter/material.dart';
import '../core/app_localizations.dart';
import 'design_system.dart';

class KyboPasswordChecklist extends StatelessWidget {
  final String password;

  const KyboPasswordChecklist({super.key, required this.password});

  // Le regole (test) sono statiche; le label vengono dai l10n a render time.
  static final List<bool Function(String)> _tests = [
    (p) => p.length >= 12,
    (p) => p.contains(RegExp(r'[A-Z]')),
    (p) => p.contains(RegExp(r'[a-z]')),
    (p) => p.contains(RegExp(r'[0-9]')),
  ];

  /// Fonte unica di verità: true se la password rispetta tutti i requisiti.
  static bool isValid(String password) =>
      _tests.every((t) => t(password));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.pwdRuleLength,
      l10n.pwdRuleUpper,
      l10n.pwdRuleLower,
      l10n.pwdRuleDigit,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_tests.length, (i) {
        final ok = _tests[i](password);
        final color = ok ? KyboColors.success : KyboColors.textMuted;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  ok
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(ok),
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  color: ok ? KyboColors.textSecondary : KyboColors.textMuted,
                  fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
