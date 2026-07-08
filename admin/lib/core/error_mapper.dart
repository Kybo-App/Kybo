// Mappa eccezioni tecniche in messaggi leggibili dall'utente in italiano.
// Speculare a client/lib/core/error_handler.dart (stessa API, stessi principi)
// ma adattato al web: niente dart:io (SocketException non esiste su web),
// gli errori di rete arrivano come ClientException/"Failed to fetch".
//
// Modello messaggio d'errore (UX): ogni messaggio dice COSA è successo e dà
// un'AZIONE chiara ("Riprova", "Controlla la rete", "Accedi di nuovo").
// Non espone MAI dettagli backend (stack, codici interni, "Exception: ...").
//
// `isRetryable(error)` dice se ha senso mostrare "Riprova" (errori transitori)
// o no (401/403/404/validazione). Uso tipico con KyboErrorView:
//   onRetry: ErrorMapper.isRetryable(e) ? _reload : null
import 'dart:async';

class ErrorMapper {
  static String toUserMessage(Object error) {
    String errorStr = error.toString();
    String errorLower = errorStr.toLowerCase();

    if (error is TimeoutException) {
      return "Il server ci mette troppo a rispondere. Riprova.";
    }
    // Rete su Flutter web: http.ClientException / fetch API.
    if (errorLower.contains("clientexception") ||
        errorLower.contains("failed to fetch") ||
        errorLower.contains("xmlhttprequest")) {
      return "Nessuna connessione al server. Controlla la rete e riprova.";
    }
    if (errorLower.contains("timeout")) {
      return "Connessione scaduta. Riprova.";
    }
    if (errorLower.contains("connection") ||
        errorLower.contains("connessione") ||
        errorLower.contains("network")) {
      return "Problemi di connessione. Controlla la rete.";
    }

    if (errorLower.contains("401") || errorLower.contains("unauthorized")) {
      return "Sessione scaduta. Effettua nuovamente il login.";
    }
    if (errorLower.contains("403") || errorLower.contains("forbidden")) {
      return "Non hai i permessi per questa azione.";
    }
    if (errorLower.contains("404") || errorLower.contains("not found")) {
      return "Contenuto non trovato. Potrebbe essere stato rimosso: ricarica la pagina.";
    }
    if (errorLower.contains("413")) {
      return "File troppo grande. Massimo 10MB.";
    }
    if (errorLower.contains("429") || errorLower.contains("too many")) {
      return "Troppe richieste in poco tempo. Attendi qualche istante e riprova.";
    }
    if (errorLower.contains("500") || errorLower.contains("internal server")) {
      return "Errore dei nostri server. Riprova più tardi.";
    }
    if (errorLower.contains("502") ||
        errorLower.contains("503") ||
        errorLower.contains("504")) {
      return "Server non disponibile. Riprova tra poco.";
    }

    if (errorLower.contains("upload failed") ||
        errorLower.contains("upload fallito") ||
        errorLower.contains("upload error")) {
      return "Errore durante il caricamento. Riprova.";
    }
    if (errorLower.contains("pdf") && errorLower.contains("valid")) {
      return "Il file non è un PDF valido.";
    }
    if (errorLower.contains("permission-denied")) {
      return "Non hai i permessi per questa azione.";
    }

    // Le eccezioni del repository portano già il 'detail' pulito del server
    // (vedi AdminRepository._safeBody): se è corto e umano, mostralo senza
    // il prefisso tecnico "Exception: ".
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

    return "Si è verificato un errore. Riprova.";
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
