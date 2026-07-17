// Primitive riutilizzabili per gli stati "error" ed "empty" di una view admin.
// Speculari a client/lib/widgets/state_views.dart (stessa API) ma con
// KyboColors statici (il dark mode admin non usa il context).
//
// Insieme agli skeleton (skeleton_loaders.dart, stato "loading") e al
// contenuto reale (stato "success"), coprono i 4 stati obbligatori:
//   loading · success · error · empty
import 'package:flutter/material.dart';
import '../core/app_localizations.dart';
import '../core/error_mapper.dart';
import 'design_system.dart';

/// Stato di errore persistente, centrato, con azione di retry.
///
/// Da usare al posto di una snackbar volatile quando il caricamento di una
/// view/sezione fallisce: l'utente vede cosa è andato storto e può riprovare
/// senza uscire e rientrare. Il messaggio passa da ErrorMapper.toUserMessage.
class KyboErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  /// Etichetta del bottone di retry; se null usa l10n ("Riprova"/"Retry").
  final String? retryLabel;
  final IconData icon;
  final EdgeInsets padding;

  const KyboErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline_rounded,
    this.padding = const EdgeInsets.all(32),
  });

  /// Costruttore comodo direttamente dall'eccezione: mappa il messaggio e
  /// nasconde il retry quando non avrebbe senso (401/403/404...).
  KyboErrorView.fromError(
    Object error, {
    super.key,
    VoidCallback? onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline_rounded,
    this.padding = const EdgeInsets.all(32),
  })  : message = ErrorMapper.toUserMessage(error),
        onRetry = ErrorMapper.isRetryable(error) ? onRetry : null;

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
                color: KyboColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              PillButton(
                label: retryLabel ?? AppLocalizations.of(context).retry,
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
/// - `actionLabel` + `onAction` → pulsante che dice cosa fare per riempire lo
///   stato ("Aggiungi il primo premio").
/// - `accentColor` → default neutro per empty "da riempire"; passare
///   KyboColors.primary/success per empty "positivi" (es. "Tutto letto ✨").
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
    final accent = accentColor ?? KyboColors.textMuted;
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
                color: KyboColors.textPrimary,
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
                  color: KyboColors.textSecondary,
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
