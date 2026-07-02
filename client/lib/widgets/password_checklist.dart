// Checklist requisiti password che si spunta MENTRE l'utente digita.
//
// Principio UX (form): non far scoprire i requisiti solo al submit con un
// errore generico — mostrali in tempo reale e barrali man mano che vengono
// soddisfatti, e non permettere l'invio finché non sono tutti verdi.
//
// La policy è allineata a quella del server e degli screen esistenti:
// min 12 caratteri, almeno una maiuscola, una minuscola e un numero.
// `KyboPasswordChecklist.isValid(pwd)` è la fonte unica di verità: usala per
// abilitare/disabilitare il pulsante di submit.
import 'package:flutter/material.dart';
import 'design_system.dart';

class _Rule {
  final String label;
  final bool Function(String) test;
  const _Rule(this.label, this.test);
}

class KyboPasswordChecklist extends StatelessWidget {
  final String password;

  const KyboPasswordChecklist({super.key, required this.password});

  static final List<_Rule> _rules = [
    _Rule('Almeno 12 caratteri', (p) => p.length >= 12),
    _Rule('Una lettera maiuscola', (p) => p.contains(RegExp(r'[A-Z]'))),
    _Rule('Una lettera minuscola', (p) => p.contains(RegExp(r'[a-z]'))),
    _Rule('Un numero', (p) => p.contains(RegExp(r'[0-9]'))),
  ];

  /// Fonte unica di verità: true se la password rispetta tutti i requisiti.
  /// Usare per gate del pulsante di submit.
  static bool isValid(String password) =>
      _rules.every((r) => r.test(password));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _rules.map((rule) {
        final ok = rule.test(password);
        final color = ok ? KyboColors.success : KyboColors.textMuted(context);
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
                rule.label,
                style: TextStyle(
                  fontSize: 13,
                  color: ok
                      ? KyboColors.textSecondary(context)
                      : KyboColors.textMuted(context),
                  fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
