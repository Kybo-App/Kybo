/// PricingService - Stima prezzi ingredienti al supermercato italiano
///
/// Prezzi medi al kg/litro/pz basati su supermercati italiani (2024).
/// Usato per stimare il costo totale della lista della spesa.
library;

class PricingService {
  PricingService._();

  // ─── Prezzi medi italiani (€/kg oppure €/pz dove indicato) ───────────────
  // Fonte: prezzi medi supermercati (Esselunga, Coop, Conad) 2024
  static const Map<String, double> _pricePerKg = {
    // Frutta
    'mela': 2.50,
    'pera': 2.80,
    'banana': 2.00,
    'arancia': 1.80,
    'limone': 2.20,
    'uva': 3.50,
    'fragola': 5.00,
    'kiwi': 3.00,
    'ananas': 2.50,
    'mango': 5.50,
    'avocado': 7.00,
    'pesca': 3.00,
    'albicocca': 3.50,
    'ciliegia': 6.00,
    'cocomero': 0.80,
    'melone': 1.50,
    'lampone': 12.00,
    'mirtillo': 10.00,
    'fico': 4.00,
    'prugna': 2.50,
    'melagrana': 3.50,
    'clementina': 2.00,
    'mandarino': 2.00,
    'pompelmo': 2.00,

    // Verdura
    'pomodoro': 2.50,
    'insalata': 2.00,
    'lattuga': 2.00,
    'spinaci': 3.00,
    'broccoli': 2.50,
    'carota': 1.20,
    'zucchina': 2.00,
    'melanzana': 2.00,
    'peperone': 3.00,
    'cipolla': 1.00,
    'aglio': 5.00,
    'patata': 1.20,
    'cavolo': 1.50,
    'cavolfiore': 2.00,
    'sedano': 1.80,
    'finocchio': 1.80,
    'asparago': 5.00,
    'carciofo': 3.00,
    'fagiolino': 4.00,
    'pisello': 4.00,
    'cetriolo': 2.00,
    'rucola': 8.00,
    'radicchio': 3.00,
    'zucca': 1.50,
    'bietola': 2.00,
    'porro': 2.00,

    // Carne
    'pollo': 6.00,
    'petto di pollo': 8.00,
    'coscia di pollo': 5.00,
    'manzo': 15.00,
    'macinato di manzo': 10.00,
    'macinato': 9.00,
    'maiale': 8.00,
    'lombo di maiale': 9.00,
    'tacchino': 7.00,
    'petto di tacchino': 8.00,
    'vitello': 18.00,
    'agnello': 14.00,
    'coniglio': 9.00,

    // Salumi
    'prosciutto cotto': 14.00,
    'prosciutto crudo': 25.00,
    'prosciutto': 15.00,
    'bresaola': 30.00,
    'mortadella': 8.00,
    'salame': 18.00,
    'speck': 25.00,
    'pancetta': 12.00,
    'wurstel': 8.00,

    // Pesce
    'salmone': 18.00,
    'tonno fresco': 15.00,
    'merluzzo': 12.00,
    'branzino': 14.00,
    'orata': 12.00,
    'gambero': 20.00,
    'calamaro': 10.00,
    'polpo': 12.00,
    'vongole': 10.00,
    'cozze': 5.00,
    'sgombro': 8.00,
    'alici': 6.00,
    'baccalà': 14.00,

    // Latticini (prezzi al kg o litro)
    'latte': 1.40,
    'yogurt': 2.50,
    'mozzarella': 8.00,
    'ricotta': 6.00,
    'parmigiano': 18.00,
    'grana': 16.00,
    'burro': 10.00,
    'panna': 5.00,
    'formaggio': 12.00,
    'gorgonzola': 12.00,
    'fontina': 14.00,
    'pecorino': 15.00,
    'feta': 10.00,
    'mascarpone': 8.00,
    'kefir': 3.00,

    // Pasta, Cereali, Pane
    'pasta': 2.00,
    'riso': 2.50,
    'pane': 3.00,
    'farro': 4.00,
    'quinoa': 8.00,
    'avena': 3.00,
    'orzo': 2.50,
    'fette biscottate': 4.00,
    'crackers': 5.00,
    'farina': 1.50,
    'piadina': 4.00,
    'gnocchi': 3.00,
    'cous cous': 4.00,
    'polenta': 2.00,
    'miglio': 5.00,

    // Legumi
    'fagioli': 3.00,
    'ceci': 3.50,
    'lenticchie': 3.00,
    'piselli surgelati': 2.50,
    'soia': 4.00,
    'tofu': 8.00,
    'edamame': 6.00,

    // Condimenti & Oli (prezzi al litro/kg)
    'olio': 7.00,
    'olio di oliva': 9.00,
    'olio evo': 12.00,
    'aceto': 2.00,
    'aceto balsamico': 8.00,

    // Frutta secca
    'mandorle': 14.00,
    'noci': 12.00,
    'nocciole': 16.00,
    'anacardi': 18.00,
    'pistacchi': 20.00,
    'semi di chia': 15.00,
    'semi di lino': 6.00,
    'semi di girasole': 5.00,
    'semi di zucca': 8.00,
    'pinoli': 45.00,
    'arachidi': 8.00,
    'uvetta': 8.00,
    'datteri': 12.00,

    // Uova (al pezzo, vedi sotto)
    // Bevande
    'acqua': 0.30,
    'succo': 2.00,
  };

  /// Prezzi a pezzo (€/pz) per prodotti che non si misurano al kg
  static const Map<String, double> _pricePerPiece = {
    'uovo': 0.25,
    'uova': 0.25,
    'vasetto': 1.50, // yogurt
    'mozzarella': 1.50, // pallina da 125g
    'limone': 0.30,
    'arancia': 0.40,
    'banana': 0.20,
    'avocado': 1.50,
    'pomodoro': 0.30,
    'cipolla': 0.30,
    'aglio': 0.50, // testa
    'peperone': 0.80,
    'zucchina': 0.40,
    'melanzana': 0.60,
    'cetriolo': 0.50,
    'finocchio': 0.80,
    'carciofo': 0.80,
    'piadina': 0.50,
    'pane': 0.50, // fetta o panino
  };

  /// Prezzi medi per categoria (fallback quando ingrediente non trovato)
  static const Map<String, double> _categoryFallback = {
    'Frutta & Verdura': 2.50,
    'Carne & Pesce': 12.00,
    'Latticini & Uova': 6.00,
    'Cereali & Pane': 3.00,
    'Legumi': 3.00,
    'Condimenti & Oli': 6.00,
    'Frutta Secca & Semi': 15.00,
    'Bevande': 2.00,
    'Altro': 3.00,
  };

  /// Prezzo generico di fallback quando non si riesce a stimare nulla
  static const double _defaultFallback = 3.00;

  // ─── API pubblica ─────────────────────────────────────────────────────────

  /// Stima il prezzo di un articolo della lista spesa.
  ///
  /// [itemString] è nel formato usato da Kybo:
  ///   "Nome (100 g) • 3 pasti"  oppure  "Nome (2 pz)"
  ///
  /// Restituisce il prezzo stimato in euro per la quantità specificata.
  static double estimatePrice(String itemString) {
    final parsed = _parseItem(itemString);
    if (parsed == null) return 0.0;

    final name = parsed['name'] as String;
    final qty = parsed['qty'] as double;
    final unit = parsed['unit'] as String;

    return _calculatePrice(name, qty, unit);
  }

  /// Stima il costo totale di una lista di articoli.
  static double estimateTotalCost(List<String> items) {
    return items.fold(0.0, (sum, item) => sum + estimatePrice(item));
  }

  /// Stima il prezzo e restituisce anche la stringa formattata (es. "~€ 1,50")
  static String formatEstimatedPrice(String itemString) {
    final price = estimatePrice(itemString);
    if (price <= 0) return '';
    return '~€ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// Stima il prezzo direttamente da nome + qty + unit (usato internamente)
  static double estimateFromParts(String name, double qty, String unit) {
    return _calculatePrice(name, qty, unit);
  }

  /// Prezzo medio di fallback per categoria (es. 'Frutta & Verdura' → 2.50 €/kg)
  static double fallbackForCategory(String category) {
    return _categoryFallback[category] ?? _defaultFallback;
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  /// Parsa una stringa item della shopping list
  static Map<String, dynamic>? _parseItem(String itemString) {
    // Rimuovi "• X pasti" finale
    final cleaned = itemString
        .replaceAll(RegExp(r'\s*•\s*\d+\s*past[io]$'), '')
        .trim();

    // Pattern: "Nome (qty unit)"
    final match = RegExp(
      r'^(.*?)\s*\((\d+(?:[.,]\d+)?)\s*([^)]*)\)$',
    ).firstMatch(cleaned);

    if (match == null) {
      // Nessuna quantità: assume 1 pz
      return {'name': cleaned, 'qty': 1.0, 'unit': 'pz'};
    }

    final name = match.group(1)?.trim() ?? cleaned;
    final qtyStr = match.group(2) ?? '1';
    final unit = match.group(3)?.trim() ?? 'pz';
    final qty = double.tryParse(qtyStr.replaceAll(',', '.')) ?? 1.0;

    return {'name': name, 'qty': qty, 'unit': unit};
  }

  /// Calcola il prezzo per un ingrediente dato nome, quantità e unità
  static double _calculatePrice(String name, double qty, String unit) {
    final lowerName = name.toLowerCase().trim();

    // Unità a pezzo → cerca nel dizionario pz
    if (unit == 'pz' || unit == 'vasetto' || unit == 'fette') {
      final pzPrice = _findPiecePrice(lowerName);
      return pzPrice * qty;
    }

    // Converti tutto in kg/litro per confronto uniforme
    final qtyKg = _toKg(qty, unit);
    if (qtyKg <= 0) return 0.0;

    final kgPrice = _findKgPrice(lowerName);
    return kgPrice * qtyKg;
  }

  /// Cerca il prezzo al kg facendo match parziale sul nome
  static double _findKgPrice(String name) {
    // Match esatto
    if (_pricePerKg.containsKey(name)) return _pricePerKg[name]!;

    // Match parziale (es. "petto di pollo" trova "pollo")
    for (final entry in _pricePerKg.entries) {
      if (name.contains(entry.key) || entry.key.contains(name)) {
        return entry.value;
      }
    }

    return _defaultFallback;
  }

  /// Cerca il prezzo al pezzo facendo match parziale
  static double _findPiecePrice(String name) {
    if (_pricePerPiece.containsKey(name)) return _pricePerPiece[name]!;

    for (final entry in _pricePerPiece.entries) {
      if (name.contains(entry.key) || entry.key.contains(name)) {
        return entry.value;
      }
    }

    // Se non trovato come pz, prova il prezzo al kg con quantità media 0.1kg
    return _findKgPrice(name) * 0.1;
  }

  /// Converte qualsiasi unità in kg (o litri, equivalenti per la stima)
  static double _toKg(double qty, String unit) {
    switch (unit.toLowerCase().trim()) {
      case 'kg':
        return qty;
      case 'g':
        return qty / 1000.0;
      case 'l':
      case 'lt':
      case 'litri':
        return qty;
      case 'ml':
        return qty / 1000.0;
      case 'cl':
        return qty / 100.0;
      // Cucchiaini e cucchiai: unità tipiche per olio/condimenti
      case 'cucchiaino':
      case 'cucchiaini':
        return qty * 0.005; // 1 cucchiaino ≈ 5 ml
      case 'cucchiaio':
      case 'cucchiai':
        return qty * 0.015; // 1 cucchiaio ≈ 15 ml
      default:
        // Unità sconosciuta: assume grammi se numero grande (>10), altrimenti kg
        return qty > 10 ? qty / 1000.0 : qty;
    }
  }
}
