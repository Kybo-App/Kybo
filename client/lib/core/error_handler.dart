import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class ErrorMapper {
  static String toUserMessage(Object error) {
    String errorStr = error.toString();
    String errorLower = errorStr.toLowerCase();

    // 1. Errori di Rete e Connettività
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

    // 2. Errori HTTP / API specifici
    if (errorLower.contains("401") || errorLower.contains("unauthorized")) {
      return "Sessione scaduta. Effettua nuovamente il login.";
    }
    if (errorLower.contains("403") || errorLower.contains("forbidden")) {
      return "Non hai i permessi per questa azione.";
    }
    if (errorLower.contains("404") || errorLower.contains("not found")) {
      return "Risorsa non trovata.";
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

    // 3. Errori Upload specifici
    if (errorLower.contains("upload failed") || errorLower.contains("upload error")) {
      return "Errore durante il caricamento. Riprova.";
    }
    if (errorLower.contains("file non trovato") || errorLower.contains("file not found")) {
      return "File non trovato. Seleziona di nuovo.";
    }
    if (errorLower.contains("pdf") && errorLower.contains("valid")) {
      return "Il file non è un PDF valido.";
    }

    // 4. Estrai messaggio da Exception("Errore X: messaggio")
    final erroreMatch = RegExp(r'errore\s*\d*:\s*(.+)', caseSensitive: false).firstMatch(errorStr);
    if (erroreMatch != null) {
      return erroreMatch.group(1)?.trim() ?? errorStr;
    }

    // 5. Errori di Piattaforma (Firebase, Google Auth, etc.)
    if (error is PlatformException) {
      if (error.code == 'sign_in_failed') return "Accesso Google fallito.";
      if (error.code == 'network_error') return "Errore di rete rilevato.";
      return error.message ?? "Errore di sistema.";
    }

    // 6. Eccezioni Custom
    if (errorLower.contains("unitmismatchexception")) {
      return "Unità di misura non compatibili (es. Peso vs Volume).";
    }

    // 7. Se l'errore contiene un messaggio utile, mostralo
    if (errorStr.startsWith("Exception: ")) {
      String msg = errorStr.substring(11);
      // Non mostrare errori tecnici
      if (!msg.contains("Exception") && !msg.contains("Error:") && msg.length < 100) {
        return msg;
      }
    }

    // 8. Default Fail-Safe
    return "Si è verificato un errore. Riprova.";
  }
}
