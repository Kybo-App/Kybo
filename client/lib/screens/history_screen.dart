import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firestore_service.dart';
import '../providers/diet_provider.dart';
import '../core/error_handler.dart'; // [IMPORTANTE]

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _showCurrentDietJson(BuildContext context) {
    final provider = Provider.of<DietProvider>(context, listen: false);
    final dietPlan = provider.dietPlan;

    if (dietPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nessuna dieta caricata")),
      );
      return;
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(dietPlan.toJson());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "JSON Dieta Corrente",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: "Copia",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jsonString));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("JSON copiato!")),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: "Condividi",
                        onPressed: () async {
                          try {
                            final dir = await getTemporaryDirectory();
                            final file = File('${dir.path}/dieta_corrente.json');
                            await file.writeAsString(jsonString);
                            await Share.shareXFiles(
                              [XFile(file.path)],
                              text: 'Dieta Kybo',
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Errore: $e")),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cronologia Diete"),
        actions: [
          // Bottone per vedere JSON dieta corrente
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: "Vedi JSON Dieta Corrente",
            onPressed: () => _showCurrentDietJson(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('Test Sync (Force)'),
        icon: const Icon(Icons.cloud_sync),
        backgroundColor: Colors.orange,
        onPressed: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⏳ Esecuzione Sync Forzato...')),
          );

          // Esegue il sync
          final result = await Provider.of<DietProvider>(
            context,
            listen: false,
          ).runSmartSyncCheck(forceSync: true);

          // [FIX LINTER] Verifica se il widget è ancora attivo prima di usare context
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result),
              backgroundColor:
                  result.contains('✅') ||
                      result.contains('☁️') ||
                      result.contains('🆕')
                  ? Colors.green
                  : Colors.amber[900],
            ),
          );
        },
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.getDietHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // [UX] Errore tradotto
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ErrorMapper.toUserMessage(snapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Nessuna dieta salvata nel cloud."),
                ],
              ),
            );
          }

          final diets = snapshot.data!;
          return ListView.builder(
            itemCount: diets.length,
            itemBuilder: (context, index) {
              final diet = diets[index];
              DateTime date = DateTime.now();
              if (diet['uploadedAt'] != null) {
                date = (diet['uploadedAt'] as dynamic).toDate();
              }
              final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.cloud_done, color: Colors.blue),
                  title: Text("Dieta del $dateStr"),
                  subtitle: const Text("Tocca per ripristinare"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      try {
                        await firestore.deleteDiet(diet['id']);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ErrorMapper.toUserMessage(e)),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("Ripristina Dieta"),
                        content: const Text(
                          "Vuoi sostituire la dieta attuale con questa versione salvata?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text("Annulla"),
                          ),
                          FilledButton(
                            onPressed: () {
                              context.read<DietProvider>().loadHistoricalDiet(
                                diet, // I dati
                                diet['id'], // L'ID Firestore (che abbiamo aggiunto nel map del service)
                              );
                              Navigator.pop(c);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Dieta ripristinata con successo!",
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text("Ripristina"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
