// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

// --- THEME COLORS ---

class AppColors {
  // Nuovo Verde "Forest" (Più serio e integrato)
  static const Color primary = Color(0xFF2E7D32);

  // Verde chiaro per sfondi/accenti leggeri
  static const Color secondary = Color(0xFF81C784);

  static const Color accent = Colors.orange;
  static const Color scaffoldBackground = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
}

// --- LISTE KEYWORDS ---
const Set<String> fruitKeywords = {
  'mela',
  'mele',
  'pera',
  'pere',
  'banana',
  'banane',
  'arance',
  'arancia',
  'ananas',
  'kiwi',
  'pesche',
  'albicocche',
  'fragole',
  'ciliegie',
  'prugne',
  'fichi',
  'uva',
  'caco',
  'cachi',
};

const Set<String> veggieKeywords = {
  'zucchine',
  'melanzane',
  'pomodori',
  'cetrioli',
  'insalata',
  'rucola',
  'bieta',
  'spinaci',
  'carote',
  'finocchi',
  'verza',
  'cavolfiore',
  'broccoli',
  'minestrone',
  'verdure',
  'fagiolini',
  'cicoria',
  'radicchio',
  'indivia',
  'zucca',
  'asparagi',
  'peperoni',
  'sedano',
  'lattuga',
  'funghi',
};

// [AGGIUNTA PUNTO 4.3] Centralizzazione Unità di Misura
class DietUnits {
  static const String GRAMS = "g";
  static const String ML = "ml";
  static const String KG = "kg";
  static const String LITER = "l";
  static const String VASETTO = "vasetto";
  static const String CUCCHIAIO = "cucchiaio";
  static const String CUCCHIAINO = "cucchiaino";
  static const String TAZZA = "tazza";
  static const String BICCHIERE = "bicchiere";
  static const String FETTE = "fette";
  static const String PIECE = "pz";
}
