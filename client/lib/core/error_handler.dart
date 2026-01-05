import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class ErrorMapper {
  static String toUserMessage(Object error) {
    // 1. Errori di Rete e Connettività
    if (error is SocketException) {
      return "Nessuna connessione internet. Controlla la rete.";
    }
    if (error is TimeoutException) {
      return "Il server ci mette troppo a rispondere. Riprova.";
    }

    // 2. Errori HTTP / API (Parsing stringa se non hai classi custom specifiche)
    String errorStr = error.toString().toLowerCase();
    if (errorStr.contains("401")) {
      return "Sessione scaduta. Effettua nuovamente il login.";
    }
    if (errorStr.contains("403")) {
      return "Non hai i permessi per questa azione.";
    }
    if (errorStr.contains("404")) {
      return "Risorsa non trovata.";
    }
    if (errorStr.contains("500")) {
      return "Errore dei nostri server. Riprova più tardi.";
    }
    if (errorStr.contains("api_error")) {
      return "Errore di comunicazione con il server.";
    }

    // 3. Errori di Piattaforma (Firebase, Google Auth, etc.)
    if (error is PlatformException) {
      if (error.code == 'sign_in_failed') return "Accesso Google fallito.";
      if (error.code == 'network_error') return "Errore di rete rilevato.";
      return error.message ?? "Errore di sistema.";
    }

    // 4. Eccezioni Custom (se presenti come UnitMismatch)
    if (errorStr.contains("unitmismatchexception")) {
      return "Unità di misura non compatibili (es. Peso vs Volume).";
    }

    // 5. Default Fail-Safe
    return "Si è verificato un errore imprevisto. Riprova.";
  }
}
