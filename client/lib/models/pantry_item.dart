// Modello per un singolo articolo della dispensa con nome, quantità e unità di misura.
class PantryItem {
  String name;
  double quantity;
  String unit;

  PantryItem({required this.name, required this.quantity, required this.unit});

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };
  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      name: json['name'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? '',
    );
  }
}
