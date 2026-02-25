// Schermata cronologia diete cloud con ripristino ed eliminazione.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../providers/diet_provider.dart';
import '../core/error_handler.dart';
import '../widgets/design_system.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.getDietHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
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
                                diet,
                                diet['id'],
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

}
