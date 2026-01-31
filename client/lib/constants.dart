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

  // Dark Mode Colors
  static const Color darkScaffoldBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCardColor = Color(0xFF2C2C2C);
}

// --- CONFIGURAZIONE DIETA (Centralizzata) ---

/// Giorni della settimana in italiano (ordine standard: Lunedì = index 0)
const List<String> italianDays = [
  "Lunedì",
  "Martedì",
  "Mercoledì",
  "Giovedì",
  "Venerdì",
  "Sabato",
  "Domenica",
];

/// Tipi di pasto nell'ordine corretto della giornata
const List<String> orderedMealTypes = [
  "Colazione",
  "Seconda Colazione",
  "Spuntino",
  "Pranzo",
  "Merenda",
  "Cena",
  "Spuntino Serale",
  "Nell'Arco Della Giornata",
];

// --- CONVERSIONI UNITÀ (Configurabili) ---

/// Fattori di conversione per unità di misura comuni
/// Tutti i valori sono espressi in grammi/ml equivalenti
class UnitConversions {
  static const double kgToGrams = 1000.0;
  static const double literToMl = 1000.0;
  static const double vasettoGrams = 125.0; // Vasetto yogurt standard
  static const double cucchiainoMl = 5.0; // Cucchiaino standard
  static const double cucchiaioMl = 15.0; // Cucchiaio standard
  static const double tazzaMl = 250.0; // Tazza standard
  static const double bicchiereMl = 200.0; // Bicchiere standard
}

// --- LISTE KEYWORDS ---

/// Keywords per identificare frutta (usato per conteggio e "Tranquil Mode")
const Set<String> fruitKeywords = {
  'mela',
  'mele',
  'pera',
  'pere',
  'banana',
  'banane',
  'arancia',
  'arance',
  'mandarino',
  'mandarini',
  'ananas',
  'kiwi',
  'pesca',
  'pesche',
  'albicocca',
  'albicocche',
  'fragola',
  'fragole',
  'ciliegia',
  'ciliegie',
  'prugna',
  'prugne',
  'fichi',
  'uva',
  'caco',
  'cachi',
  'anguria',
  'melone',
  'limone',
  'pompelmo',
  'frutti di bosco',
};

/// Keywords per identificare verdura
const Set<String> veggieKeywords = {
  'zucchina',
  'zucchine',
  'melanzana',
  'melanzane',
  'pomodoro',
  'pomodori',
  'cetriolo',
  'cetrioli',
  'insalata',
  'lattuga',
  'rucola',
  'bieta',
  'spinaci',
  'carota',
  'carote',
  'finocchio',
  'finocchi',
  'verza',
  'cavolfiore',
  'broccolo',
  'broccoli',
  'minestrone',
  'verdura',
  'verdure',
  'fagiolini',
  'cicoria',
  'radicchio',
  'indivia',
  'zucca',
  'asparagi',
  'peperone',
  'peperoni',
  'sedano',
  'funghi',
  'cime di rapa',
  'passato di verdura',
  'ortaggi',
};

/// Set combinato di alimenti "rilassabili" per Tranquil Mode
/// Frutta e verdura per cui la quantità può essere "a piacere"
const Set<String> relaxableFoods = {
  ...fruitKeywords,
  ...veggieKeywords,
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
