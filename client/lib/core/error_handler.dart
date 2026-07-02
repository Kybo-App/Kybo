// Mappa eccezioni tecniche in messaggi leggibili dall'utente in italiano.
//
// Modello messaggio d'errore (UX): ogni messaggio dice COSA è successo e dà
// un'AZIONE chiara ("Riprova", "Controlla la rete", "Accedi di nuovo").
// Non espone MAI dettagli backend (stack, codici interni).
//
// `isRetryable(error)` completa il modello lato UI: dice se ha senso mostrare
// un pulsante "Riprova" (errori transitori: rete/timeout/5xx) o no (401/403/
// 404/validazione, dove ripetere la stessa azione non risolve). Usarlo così
// con KyboErrorView:  onRetry: ErrorMapper.isRetryable(e) ? _reload : null
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class ErrorMapper {
  static String toUserMessage(Object error) {
    String errorStr = error.toString();
    String errorLower = errorStr.toLowerCase();

    if (error is SocketException) {
      return "Nessuna connessione internet. Controlla la rete.";
    }
    if (error is TimeoutException) {
      return "Il server ci mette troppo a rispondere. Riprova.";
    }
    if (errorLower.contains("timeout")) {
      return "Connessione scaduta. Riprova.";
    }
    if (errorLower.contains("connection") || errorLower.contains("connessione")) {
      return "Problemi di connessione. Controlla la rete.";
    }

    if (errorLower.contains("401") || errorLower.contains("unauthorized")) {
      return "Sessione scaduta. Effettua nuovamente il login.";
    }
    if (errorLower.contains("403") || errorLower.contains("forbidden")) {
      return "Non hai i permessi per questa azione. Se pensi sia un errore, contatta il tuo nutrizionista.";
    }
    if (errorLower.contains("404") || errorLower.contains("not found")) {
      return "Contenuto non trovato. Potrebbe essere stato rimosso: ricarica la pagina.";
    }
    if (errorLower.contains("413")) {
      return "File troppo grande. Massimo 10MB.";
    }
    if (errorLower.contains("500") || errorLower.contains("internal server")) {
      return "Errore dei nostri server. Riprova più tardi.";
    }
    if (errorLower.contains("502") || errorLower.contains("503") || errorLower.contains("504")) {
      return "Server non disponibile. Riprova tra poco.";
    }

    if (errorLower.contains("upload failed") || errorLower.contains("upload error")) {
      return "Errore durante il caricamento. Riprova.";
    }
    if (errorLower.contains("file non trovato") || errorLower.contains("file not found")) {
      return "File non trovato. Seleziona di nuovo.";
    }
    if (errorLower.contains("pdf") && errorLower.contains("valid")) {
      return "Il file non è un PDF valido.";
    }

    final erroreMatch = RegExp(r'errore\s*\d*:\s*(.+)', caseSensitive: false).firstMatch(errorStr);
    if (erroreMatch != null) {
      return erroreMatch.group(1)?.trim() ?? errorStr;
    }

    if (error is PlatformException) {
      if (error.code == 'sign_in_failed') return "Accesso Google fallito. Riprova.";
      if (error.code == 'network_error') return "Problemi di rete. Controlla la connessione e riprova.";
      return error.message ?? "Errore di sistema. Riprova.";
    }

    if (errorLower.contains("unitmismatchexception")) {
      return "Unità di misura non compatibili (es. Peso vs Volume). Correggi la quantità in dispensa.";
    }

    if (errorStr.startsWith("Exception: ")) {
      String msg = errorStr.substring(11);
      if (!msg.contains("Exception") && !msg.contains("Error:") && msg.length < 100) {
        return msg;
      }
    }

    return "Si è verificato un errore. Riprova.";
  }

  /// True se ha senso offrire un pulsante "Riprova" per questo errore.
  ///
  /// Retryable: errori transitori (rete, timeout, 5xx, upload, generici) dove
  /// ripetere la stessa azione può riuscire.
  /// NON retryable: 401 (serve login), 403 (permessi), 404 (non esiste),
  /// 413 (file troppo grande), validazione/unità → serve un'azione DIVERSA,
  /// non ripetere la stessa. La UI in quel caso non mostra "Riprova".
  static bool isRetryable(Object error) {
    final s = error.toString().toLowerCase();

    // Casi esplicitamente non-retryable (l'utente deve fare altro).
    if (error is PlatformException && error.code == 'sign_in_failed') {
      return true; // il retry del sign-in ha senso
    }
    if (s.contains("401") || s.contains("unauthorized")) return false;
    if (s.contains("403") || s.contains("forbidden")) return false;
    if (s.contains("404") || s.contains("not found")) return false;
    if (s.contains("413")) return false;
    if (s.contains("unitmismatch")) return false;
    if (s.contains("pdf") && s.contains("valid")) return false;

    // Transitori → retryable.
    if (error is SocketException || error is TimeoutException) return true;
    if (s.contains("timeout") ||
        s.contains("connection") ||
        s.contains("connessione") ||
        s.contains("500") ||
        s.contains("internal server") ||
        s.contains("502") ||
        s.contains("503") ||
        s.contains("504") ||
        s.contains("upload")) {
      return true;
    }

    // Default prudente: consenti il retry (meglio un tentativo in più che un
    // vicolo cieco — ep5: l'errore peggiore è quello senza via d'uscita).
    return true;
  }
}
