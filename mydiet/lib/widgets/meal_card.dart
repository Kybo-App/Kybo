import 'package:flutter/material.dart';
import '../models/active_swap.dart';

class MealCard extends StatelessWidget {
  final String mealName;
  final List<dynamic> foods;
  final Map<String, ActiveSwap> activeSwaps;
  final Function(String key, int currentCad)
  onSwap; // Passiamo il CAD per sapere cosa cercare

  const MealCard({
    super.key,
    required this.mealName,
    required this.foods,
    required this.activeSwaps,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    // 1. RAGGRUPPA I CIBI PER CAD
    // Struttura: Map<int_CAD, List<Food>>
    // Usiamo una lista di liste per mantenere l'ordine
    List<List<dynamic>> groupedFoods = [];

    if (foods.isNotEmpty) {
      List<dynamic> currentGroup = [foods[0]];
      for (int i = 1; i < foods.length; i++) {
        var prev = foods[i - 1];
        var curr = foods[i];

        // Logica di raggruppamento: Se hanno lo stesso 'cad' (e non è nullo/zero) vanno insieme.
        // Se nel tuo JSON il campo si chiama 'cad_code' o altro, correggi qui.
        int prevCad = int.tryParse(prev['cad'].toString()) ?? 0;
        int currCad = int.tryParse(curr['cad'].toString()) ?? 0;

        if (prevCad != 0 && prevCad == currCad) {
          currentGroup.add(curr);
        } else {
          groupedFoods.add(currentGroup);
          currentGroup = [curr];
        }
      }
      groupedFoods.add(currentGroup);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mealName, // Es. "Pranzo"
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),

            // Generiamo i widget per i GRUPPI
            ...groupedFoods.asMap().entries.map((entry) {
              int groupIndex = entry.key;
              List<dynamic> group = entry.value;

              // Chiave univoca per il gruppo (usiamo l'indice del primo elemento nel pasto originale)
              // Nota: per renderlo univoco usiamo un identificativo basato sulla posizione
              String swapKey = "${mealName}_group_$groupIndex";

              // Verifica se c'è uno swap attivo per questo gruppo
              bool isSwapped = activeSwaps.containsKey(swapKey);
              List<dynamic> displayFoods = isSwapped
                  ? activeSwaps[swapKey]!.swappedIngredients ?? group
                  : group;

              // Titolo del piatto (prendiamo il nome del primo elemento o un nome generico)
              // Se è un gruppo sostituito, il nome potrebbe venire dallo swap se lo avessimo salvato,
              // altrimenti mostriamo gli ingredienti.

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Se è un gruppo singolo, mostriamo nome classico
                      // Se è un gruppo multiplo, mostriamo l'elenco puntato
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: displayFoods.map((f) {
                            bool isMultiple = displayFoods.length > 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isMultiple)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        top: 6,
                                        right: 6,
                                      ),
                                      child: Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: Colors.green,
                                      ),
                                    ), // I pallini richiesti
                                  Expanded(
                                    child: Text(
                                      "${f['name']} (${f['qty']})",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isMultiple
                                            ? FontWeight.normal
                                            : FontWeight.w500,
                                        color: isSwapped
                                            ? Colors.blue[800]
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Tasto Swap unico per il gruppo
                      IconButton(
                        icon: Icon(
                          Icons.swap_horiz,
                          color: isSwapped ? Colors.blue : Colors.grey,
                        ),
                        onPressed: () {
                          // Passiamo il CAD del primo elemento originale per cercare alternative valide
                          int originalCad =
                              int.tryParse(group[0]['cad'].toString()) ?? 0;
                          onSwap(swapKey, originalCad);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 8),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
