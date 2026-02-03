// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';
// AppColors rimosso (KyboColors adottato ovunque)

// --- CONFIGURAZIONE DEFAULT (Fallback) ---
// Rimosso: i giorni e i pasti sono ora gestiti dinamicamente dalla configurazione della dieta.

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
