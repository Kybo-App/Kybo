// Persistenza locale sicura tramite FlutterSecureStorage (dieta, dispensa, swap) e SharedPreferences (allarmi, conversioni, budget).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pantry_item.dart';
import '../models/active_swap.dart';

class StorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<Map<String, dynamic>?> loadDiet() async {
    try {
      String? jsonString = await _storage.read(key: 'diet_plan');
      if (jsonString == null) return null;
      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint("⚠️ Errore caricamento dieta (corrotta?): $e");
      return null;
    }
  }

  Future<void> saveDiet(Map<String, dynamic> dietData) async {
    await _storage.write(key: 'diet_plan', value: jsonEncode(dietData));
    // Stamp local mtime so sync can do last-write-wins against Firestore.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'diet_local_updated_at_ms',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Ultimo timestamp di modifica locale della dieta.
  /// Usato da syncFromFirebase per evitare che una `diets/current` stale
  /// in Firestore sovrascriva modifiche recenti salvate solo offline
  /// (es. swap/sostituzioni fatte tra un flutter run e l'altro).
  Future<DateTime?> loadDietLocalUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('diet_local_updated_at_ms');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setDietLocalUpdatedAt(DateTime ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('diet_local_updated_at_ms', ts.millisecondsSinceEpoch);
  }

  Future<void> clearDietLocalUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('diet_local_updated_at_ms');
  }

  Future<List<PantryItem>> loadPantry() async {
    try {
      String? jsonString = await _storage.read(key: 'pantry');
      if (jsonString == null) return [];
      List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => PantryItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint("⚠️ Errore caricamento dispensa: $e");
      return [];
    }
  }

  Future<void> savePantry(List<PantryItem> items) async {
    await _storage.write(
      key: 'pantry',
      value: jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, ActiveSwap>> loadSwaps() async {
    try {
      String? jsonString = await _storage.read(key: 'active_swaps');
      if (jsonString == null) return {};
      Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return jsonMap.map(
        (key, value) => MapEntry(key, ActiveSwap.fromJson(value)),
      );
    } catch (e) {
      return {};
    }
  }

  Future<void> saveSwaps(Map<String, ActiveSwap> swaps) async {
    final jsonMap = swaps.map((key, value) => MapEntry(key, value.toJson()));
    await _storage.write(key: 'active_swaps', value: jsonEncode(jsonMap));
  }

  // [SECURITY] Allarmi spostati da SharedPreferences a FlutterSecureStorage.
  // Gli orari dei pasti sono dati comportamentali sensibili (rivelano le abitudini
  // alimentari dell'utente). Su device rooted, SharedPreferences è leggibile
  // senza permessi. FlutterSecureStorage usa AES-256 + Android Keystore / iOS Keychain.
  Future<List<Map<String, dynamic>>> loadAlarms() async {
    try {
      String? raw = await _storage.read(key: 'custom_alarms');
      if (raw == null) return [];
      List<dynamic> list = jsonDecode(raw);
      return List<Map<String, dynamic>>.from(list);
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAlarms(List<Map<String, dynamic>> alarms) async {
    await _storage.write(key: 'custom_alarms', value: jsonEncode(alarms));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _storage.deleteAll();
  }

  Future<Map<String, double>> loadConversions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('custom_conversions');
    if (raw == null) return {};
    try {
      Map<String, dynamic> jsonMap = jsonDecode(raw);
      return jsonMap.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      return {};
    }
  }

  Future<void> saveConversions(Map<String, double> conversions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_conversions', jsonEncode(conversions));
  }

  Future<double?> loadWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('weekly_budget')
        ? prefs.getDouble('weekly_budget')
        : null;
  }

  Future<void> saveWeeklyBudget(double? budget) async {
    final prefs = await SharedPreferences.getInstance();
    if (budget == null) {
      await prefs.remove('weekly_budget');
    } else {
      await prefs.setDouble('weekly_budget', budget);
    }
  }

  Future<List<String>> loadShoppingList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('shopping_list') ?? [];
  }

  Future<void> saveShoppingList(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('shopping_list', list);
  }

  Future<String?> loadLastConsumedResetDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_consumed_reset_date');
  }

  Future<void> saveLastConsumedResetDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_consumed_reset_date', date);
  }
}
