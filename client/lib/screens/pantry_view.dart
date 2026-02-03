import 'package:flutter/material.dart';
import '../models/pantry_item.dart';
import '../widgets/design_system.dart';

class PantryView extends StatefulWidget {
  final List<PantryItem> pantryItems;
  final Function(String name, double qty, String unit) onAddManual;
  final Function(int index) onRemove;
  final VoidCallback onScanTap;

  const PantryView({
    super.key,
    required this.pantryItems,
    required this.onAddManual,
    required this.onRemove,
    required this.onScanTap,
  });

  @override
  State<PantryView> createState() => _PantryViewState();
}

class _PantryViewState extends State<PantryView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  String _unit = 'g';

  void _handleAdd() {
    if (_nameController.text.isNotEmpty) {
      double qty =
          double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 1.0;
      widget.onAddManual(_nameController.text.trim(), qty, _unit);
      _nameController.clear();
      _qtyController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [KyboColors.primary, KyboColors.primaryDark],
          ),
          borderRadius: KyboBorderRadius.large,
          boxShadow: [
            BoxShadow(
              color: KyboColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: widget.onScanTap,
          icon: const Icon(Icons.camera_alt, color: Colors.white),
          label: const Text(
            "Scansiona Scontrino",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KyboColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.kitchen, size: 24, color: KyboColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "La tua Dispensa",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: KyboColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),

            // INPUT FORM
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KyboColors.surface(context),
                borderRadius: KyboBorderRadius.large,
                border: Border.all(
                  color: KyboColors.border(context),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(color: KyboColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: "Aggiungi cibo...",
                        hintStyle: TextStyle(color: KyboColors.textMuted(context)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: KyboColors.border(context),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KyboColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: "Qtà",
                        hintStyle: TextStyle(color: KyboColors.textMuted(context)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _unit,
                    underline: const SizedBox(),
                    dropdownColor: KyboColors.surface(context),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: KyboColors.textMuted(context),
                    ),
                    items: ['g', 'ml', 'pz', 'vasetto', 'fette']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(
                                fontSize: 13,
                                color: KyboColors.textPrimary(context),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [KyboColors.primary, KyboColors.primaryDark],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _handleAdd,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LISTA
            Expanded(
              child: widget.pantryItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: KyboColors.textMuted(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Dispensa vuota",
                            style: TextStyle(
                              color: KyboColors.textMuted(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.pantryItems.length,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemBuilder: (context, index) {
                        final item = widget.pantryItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: KyboColors.surface(context),
                            borderRadius: KyboBorderRadius.medium,
                            border: Border.all(
                              color: KyboColors.border(context),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Dismissible(
                            key: Key("${item.name}_$index"),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => widget.onRemove(index),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [KyboColors.error, KyboColors.error.withValues(alpha: 0.8)],
                                ),
                                borderRadius: KyboBorderRadius.medium,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [KyboColors.primary, KyboColors.primaryDark],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: KyboColors.textPrimary(context),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: KyboColors.primary.withValues(alpha: 0.1),
                                  borderRadius: KyboBorderRadius.medium,
                                ),
                                child: Text(
                                  "${item.quantity.toStringAsFixed(item.unit == 'pz' ? 0 : 1)} ${item.unit}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: KyboColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
