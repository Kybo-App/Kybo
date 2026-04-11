import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeHelper {
  static final TimeHelper _instance = TimeHelper._internal();
  factory TimeHelper() => _instance;
  TimeHelper._internal();

  /// Quanti minuti dopo la mezzanotte scatta il vero reset della giornata.
  /// Se 0, il reset è a mezzanotte esatta.
  int _rolloverDelayMinutes = 0;

  bool _isLoaded = false;

  Future<void> init() async {
    if (_isLoaded) return;
    await reloadAlarms();
    _isLoaded = true;
  }

  /// Ricalcola l'offset di rollover basandosi sugli allarmi configurati
  Future<void> reloadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('meal_alarms');
    
    int maxMealMinutes = -1;

    if (savedJson != null) {
      try {
        final decoded = jsonDecode(savedJson) as Map<String, dynamic>;
        for (var val in decoded.values) {
          final parts = val.toString().split(':');
          if (parts.length == 2) {
            int h = int.parse(parts[0]);
            int m = int.parse(parts[1]);
            // I pasti molto tardivi (es. 01:00 AM, 02:00 AM) appartengono
            // logicamente al "giorno" corrente secondo la mente dell'utente.
            // Aggiungiamo 24h virtuali in modo che diventino il "maxMealMinutes".
            int logicalHour = h < 5 ? h + 24 : h;
            int totalMins = logicalHour * 60 + m;
            if (totalMins > maxMealMinutes) {
              maxMealMinutes = totalMins;
            }
          }
        }
      } catch (e) {
        debugPrint("TimeHelper error parsing alarms: $e");
      }
    }

    if (maxMealMinutes == -1) {
      // Nessun allarme o parse fallito. Fallback: reset = Mezzanotte (0 delay)
      _rolloverDelayMinutes = 0;
    } else {
      // L'utente vuole che il reset avvenga 3 ore (180 min) dopo l'ultimo pasto.
      // Esempio: Cena alle 23:00 (1380 min) -> +180 = 1560 min.
      // Visto che un giorno ha 1440 min, il delay rispetto a mezzanotte è 1560 - 1440 = +120 min.
      // Se l'ultimo pasto è alle 20:00 (1200) -> +180 = 1380 min. È prima di mezzanotte,
      // non anticipiamo il giorno, quindi il delay è 0.
      int logicalResetMins = maxMealMinutes + 180;
      int delay = logicalResetMins - 1440; // 1440 = 24h
      
      if (delay > 0) {
        _rolloverDelayMinutes = delay;
      } else {
        _rolloverDelayMinutes = 0;
      }
    }
  }

  /// Restituisce la data "logica" attuale.
  /// Se sono le 01:00 AM e il rollover è alle 02:00 AM, restituirà "Ieri".
  DateTime getLogicalToday() {
    final now = DateTime.now();
    return _applyRolloverTo(now);
  }

  /// Data logica formattata come YYYY-MM-DD
  String getLogicalTodayString() {
    final logical = getLogicalToday();
    return '${logical.year}-${logical.month.toString().padLeft(2, '0')}-${logical.day.toString().padLeft(2, '0')}';
  }

  /// Trasforma una data arbitraria nella sua data "logica" rispetto al reset
  DateTime getLogicalDate(DateTime date) {
    return _applyRolloverTo(date);
  }

  /// Stringa YYYY-MM-DD di una data passata
  String getLogicalDateString(DateTime date) {
    final logical = getLogicalDate(date);
    return '${logical.year}-${logical.month.toString().padLeft(2, '0')}-${logical.day.toString().padLeft(2, '0')}';
  }

  DateTime _applyRolloverTo(DateTime date) {
    if (_rolloverDelayMinutes > 0) {
       return date.subtract(Duration(minutes: _rolloverDelayMinutes));
    }
    return date;
  }
}
