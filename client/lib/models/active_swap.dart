// Modello per uno swap attivo su un piatto della dieta, serializzabile da/verso Firestore.
class ActiveSwap {
  final String name;
  final String qty;
  final String unit;
  final List<dynamic>? swappedIngredients;

  ActiveSwap({
    required this.name,
    required this.qty,
    this.unit = "",
    this.swappedIngredients,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'unit': unit,
        'swappedIngredients': swappedIngredients,
      };

  Map<String, dynamic> toMap() => toJson();

  factory ActiveSwap.fromJson(Map<String, dynamic> json) {
    return ActiveSwap(
      name: json['name'] ?? '',
      qty: json['qty']?.toString() ?? '',
      unit: json['unit'] ?? '',
      swappedIngredients: json['swappedIngredients'] != null
          ? List<dynamic>.from(json['swappedIngredients'])
          : null,
    );
  }

  factory ActiveSwap.fromMap(Map<String, dynamic> map) =>
      ActiveSwap.fromJson(map);
}
