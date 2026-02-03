import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firestore_service.dart';
import '../providers/diet_provider.dart';
import '../core/error_handler.dart'; // [IMPORTANTE]
import '../widgets/design_system.dart';

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
          decoration: BoxDecoration(
            color: KyboColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "JSON Dieta Corrente",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KyboColors.textPrimary(context)),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy, color: KyboColors.textPrimary(context)),
                        tooltip: "Copia",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jsonString));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("JSON copiato!"),
                              backgroundColor: KyboColors.success,
                              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.share, color: KyboColors.textPrimary(context)),
                        tooltip: "Condividi",
                        onPressed: () async {
                          try {
                            await Share.share(
                              jsonString,
                              subject: 'Dieta Kybo',
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
                        icon: Icon(Icons.close, color: KyboColors.textPrimary(context)),
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
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: KyboColors.textSecondary(context),
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
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        title: Text(
          "Cronologia Diete",
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        iconTheme: IconThemeData(color: KyboColors.textPrimary(context)),
        actions: [
          // Bottone per vedere JSON dieta corrente
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: "Vedi JSON Dieta Corrente",
            onPressed: () => _showCurrentDietJson(context),
          ),
          // [DEBUG] Vedi RAW AI Response
          Consumer<DietProvider>(
            builder: (_, provider, __) {
              if (provider.lastRawParsedData == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.bug_report, color: Colors.orange),
                tooltip: "Debug RAW AI Response",
                onPressed: () => _showRawAiResponse(context),
              );
            },
          ),
          // ADMIN: Upload Config Init
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: "Admin Init Config",
            onPressed: () async {
              await firestore.uploadDefaultGlobalConfig();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Config Globale caricata su Firestore!")),
                );
              }
            },
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
              backgroundColor: result.contains('✅') ||
                      result.contains('☁️') ||
                      result.contains('🆕')
                  ? KyboColors.success
                  : KyboColors.warning,
              shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
              behavior: SnackBarBehavior.floating,
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 50, color: KyboColors.textMuted(context)),
                  const SizedBox(height: 10),
                  Text(
                    "Nessuna dieta salvata nel cloud.",
                    style: TextStyle(color: KyboColors.textSecondary(context)),
                  ),
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
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: KyboColors.surface(context),
                shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
                child: ListTile(
                  leading: Icon(Icons.cloud_done, color: KyboColors.primary),
                  title: Text(
                    "Dieta del $dateStr",
                    style: TextStyle(color: KyboColors.textPrimary(context), fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Tocca per ripristinare",
                    style: TextStyle(color: KyboColors.textSecondary(context)),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: KyboColors.error),
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
                        backgroundColor: KyboColors.surface(context),
                        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
                        title: Text(
                          "Ripristina Dieta",
                          style: TextStyle(color: KyboColors.textPrimary(context)),
                        ),
                        content: Text(
                          "Vuoi sostituire la dieta attuale con questa versione salvata?",
                          style: TextStyle(color: KyboColors.textSecondary(context)),
                        ),
                        actions: [
                          PillButton(
                            label: "Annulla",
                            onPressed: () => Navigator.pop(c),
                            backgroundColor: KyboColors.surface(context),
                            textColor: KyboColors.textPrimary(context),
                            height: 44,
                          ),
                          PillButton(
                            label: "Ripristina",
                            onPressed: () {
                              context.read<DietProvider>().loadHistoricalDiet(
                                diet, // I dati
                                diet['id'], // L'ID Firestore
                              );
                              Navigator.pop(c);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Dieta ripristinata con successo!"),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: KyboColors.success,
                                  shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
                                ),
                              );
                            },
                            backgroundColor: KyboColors.primary,
                            textColor: Colors.white,
                            height: 44,
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

  void _showRawAiResponse(BuildContext context) {
    final provider = context.read<DietProvider>();
    final data = provider.lastRawParsedData;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text("RAW AI Response", style: TextStyle(color: KyboColors.textPrimary(context))),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(data),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          PillButton(
            label: "Chiudi",
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );
  }
}
