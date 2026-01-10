class PantryItem {
  String name;
  double quantity;
  String unit; // "g" o "pz"

  PantryItem({required this.name, required this.quantity, required this.unit});

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };
  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      name: json['name'] ?? '',
      // FIX 2.2: Cast sicuro (gestisce int, double e null)
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? '',
    );
  }
}
