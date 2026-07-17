// Mappa eccezioni tecniche in messaggi leggibili dall'utente (IT/EN).
// Speculare a client/lib/core/error_handler.dart (stessa API, stessi principi)
// ma adattato al web: niente dart:io (SocketException non esiste su web),
// gli errori di rete arrivano come ClientException/"Failed to fetch".
//
// [L10N] Senza BuildContext (usato anche fuori dal widget tree), la lingua
// arriva dal singleton LanguageProvider — stessa fonte del MaterialApp.
//
// Modello messaggio d'errore (UX): ogni messaggio dice COSA è successo e dà
// un'AZIONE chiara ("Riprova", "Controlla la rete", "Accedi di nuovo").
// Non espone MAI dettagli backend (stack, codici interni, "Exception: ...").
//
// `isRetryable(error)` dice se ha senso mostrare "Riprova" (errori transitori)
// o no (401/403/404/validazione). Uso tipico con KyboErrorView:
//   onRetry: ErrorMapper.isRetryable(e) ? _reload : null
import 'dart:async';

import '../providers/language_provider.dart';

class ErrorMapper {
  static bool get _it => LanguageProvider().isItalian;

  static String toUserMessage(Object error) {
    String errorStr = error.toString();
    String errorLower = errorStr.toLowerCase();

    if (error is TimeoutException) {
      return _it
          ? "Il server ci mette troppo a rispondere. Riprova."
          : "The server is taking too long. Try again.";
    }
    // Rete su Flutter web: http.ClientException / fetch API.
    if (errorLower.contains("clientexception") ||
        errorLower.contains("failed to fetch") ||
        errorLower.contains("xmlhttprequest")) {
      return _it
          ? "Nessuna connessione al server. Controlla la rete e riprova."
          : "No connection to the server. Check your network and try again.";
    }
    if (errorLower.contains("timeout")) {
      return _it ? "Connessione scaduta. Riprova." : "Connection timed out. Try again.";
    }
    if (errorLower.contains("connection") ||
        errorLower.contains("connessione") ||
        errorLower.contains("network")) {
      return _it
          ? "Problemi di connessione. Controlla la rete."
          : "Connection problems. Check your network.";
    }

    if (errorLower.contains("401") || errorLower.contains("unauthorized")) {
      return _it
          ? "Sessione scaduta. Effettua nuovamente il login."
          : "Session expired. Please log in again.";
    }
    if (errorLower.contains("403") || errorLower.contains("forbidden")) {
      return _it
          ? "Non hai i permessi per questa azione."
          : "You don't have permission for this action.";
    }
    if (errorLower.contains("404") || errorLower.contains("not found")) {
      return _it
          ? "Contenuto non trovato. Potrebbe essere stato rimosso: ricarica la pagina."
          : "Content not found. It may have been removed: reload the page.";
    }
    if (errorLower.contains("413")) {
      return _it
          ? "File troppo grande. Massimo 10MB."
          : "File too large. 10MB maximum.";
    }
    if (errorLower.contains("429") || errorLower.contains("too many")) {
      return _it
          ? "Troppe richieste in poco tempo. Attendi qualche istante e riprova."
          : "Too many requests. Wait a moment and try again.";
    }
    if (errorLower.contains("500") || errorLower.contains("internal server")) {
      return _it
          ? "Errore dei nostri server. Riprova più tardi."
          : "Server error on our side. Try again later.";
    }
    if (errorLower.contains("502") ||
        errorLower.contains("503") ||
        errorLower.contains("504")) {
      return _it
          ? "Server non disponibile. Riprova tra poco."
          : "Server unavailable. Try again shortly.";
    }

    if (errorLower.contains("upload failed") ||
        errorLower.contains("upload fallito") ||
        errorLower.contains("upload error")) {
      return _it
          ? "Errore durante il caricamento. Riprova."
          : "Upload failed. Try again.";
    }
    if (errorLower.contains("pdf") && errorLower.contains("valid")) {
      return _it ? "Il file non è un PDF valido." : "The file is not a valid PDF.";
    }
    if (errorLower.contains("permission-denied")) {
      return _it
          ? "Non hai i permessi per questa azione."
          : "You don't have permission for this action.";
    }

    // Le eccezioni del repository portano già il 'detail' pulito del server
    // (vedi AdminRepository._safeBody): se è corto e umano, mostralo senza
    // il prefisso tecnico "Exception: ". NOTA: il 'detail' arriva dal server
    // in italiano — localizzarlo davvero richiederebbe l10n lato FastAPI.
    if (errorStr.startsWith("Exception: ")) {
      String msg = errorStr.substring(11);
      if (!msg.contains("Exception") && !msg.contains("Error:") && msg.length < 140) {
        return msg;
      }
    }
    // ApiStatusException.toString() è già il solo messaggio 'detail'.
    if (!errorStr.contains("Exception") &&
        !errorStr.contains("Error") &&
        errorStr.length < 140 &&
        errorStr.trim().isNotEmpty) {
      return errorStr;
    }

    return _it
        ? "Si è verificato un errore. Riprova."
        : "Something went wrong. Try again.";
  }

  /// True se ha senso offrire un pulsante "Riprova" per questo errore.
  static bool isRetryable(Object error) {
    final s = error.toString().toLowerCase();

    if (s.contains("401") || s.contains("unauthorized")) return false;
    if (s.contains("403") || s.contains("forbidden")) return false;
    if (s.contains("404") || s.contains("not found")) return false;
    if (s.contains("413")) return false;
    if (s.contains("pdf") && s.contains("valid")) return false;

    // Default prudente: consenti il retry (meglio un tentativo in più che un
    // vicolo cieco — l'errore peggiore è quello senza via d'uscita).
    return true;
  }
}
