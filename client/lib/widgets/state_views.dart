// Primitive riutilizzabili per gli stati "error" ed "empty" di una schermata.
//
// Insieme agli skeleton (skeleton_loaders.dart, stato "loading") e al contenuto
// reale (stato "success"), coprono i 4 stati che ogni schermata dovrebbe avere:
//   loading · success · error · empty
//
// Principi UX incorporati:
// - ERROR (mai fallimento silenzioso): messaggio chiaro + AZIONE ("Riprova").
//   Il messaggio arriva da ErrorMapper.toUserMessage — niente dettagli backend.
// - EMPTY come opportunità: non un vicolo cieco ma una call-to-action che dice
//   all'utente cosa fare ("Carica la prima dieta"), o un empty "positivo"
//   gamificato (accentColor primary) per stati desiderabili ("Nessun pasto
//   scaduto").
import 'package:flutter/material.dart';
import 'design_system.dart';

/// Stato di errore persistente, centrato, con azione di retry.
///
/// Da usare al posto di una snackbar volatile quando il caricamento di una
/// schermata/sezione fallisce: l'utente vede cosa è andato storto e può
/// riprovare senza uscire e rientrare.
class KyboErrorView extends StatelessWidget {
  /// Messaggio user-facing (tipicamente da `ErrorMapper.toUserMessage`).
  final String message;

  /// Se fornito, mostra il pulsante di retry.
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  /// Padding esterno (default generoso per centratura in un body/Expanded).
  final EdgeInsets padding;

  const KyboErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Riprova',
    this.icon = Icons.error_outline_rounded,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KyboColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: KyboColors.error, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              PillButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                backgroundColor: KyboColors.primary,
                textColor: Colors.white,
                height: 46,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stato vuoto, centrato, con call-to-action opzionale.
///
/// - `actionLabel` + `onAction` → mostra un pulsante che dice all'utente cosa
///   fare per riempire lo stato ("Carica la prima dieta").
/// - `accentColor` → default neutro (grigio) per empty "da riempire"; passare
///   `KyboColors.primary` (o success) per empty "positivi/desiderabili"
///   gamificati (es. "Nessun pasto scaduto ✨").
class KyboEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accentColor;
  final EdgeInsets padding;

  const KyboEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accentColor,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? KyboColors.textMuted(context);
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KyboColors.textSecondary(context),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              PillButton(
                label: actionLabel!,
                icon: Icons.add_rounded,
                onPressed: onAction,
                backgroundColor: accentColor ?? KyboColors.primary,
                textColor: Colors.white,
                height: 48,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
