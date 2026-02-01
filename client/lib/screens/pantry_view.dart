import 'package:flutter/material.dart';
import '../models/pantry_item.dart';
import '../constants.dart';

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
      backgroundColor: AppColors.getScaffoldBackground(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onScanTap,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text(
          "Scansiona Scontrino",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.kitchen, size: 28, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    "La tua Dispensa",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),
            ),

            // INPUT FORM
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getInputBackground(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getShadowColor(context),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      decoration: InputDecoration(
                        hintText: "Aggiungi cibo...",
                        hintStyle: TextStyle(color: AppColors.getHintColor(context)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppColors.getDividerColor(context),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      decoration: InputDecoration(
                        hintText: "Qtà",
                        hintStyle: TextStyle(color: AppColors.getHintColor(context)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _unit,
                    underline: const SizedBox(),
                    dropdownColor: AppColors.getCardColor(context),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.getIconColor(context),
                    ),
                    items: ['g', 'ml', 'pz', 'vasetto', 'fette']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    onPressed: _handleAdd,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LISTA
            Expanded(
              child: widget.pantryItems.isEmpty
                  ? Center(
                      child: Text(
                        "Dispensa vuota",
                        style: TextStyle(color: AppColors.getHintColor(context)),
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
                            color: AppColors.getCardColor(context),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.getShadowColor(context),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
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
                                color: AppColors.getErrorBackground(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: AppColors.getErrorForeground(context),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextColor(context),
                                ),
                              ),
                              trailing: Text(
                                "${item.quantity.toStringAsFixed(item.unit == 'pz' ? 0 : 1)} ${item.unit}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 15,
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
