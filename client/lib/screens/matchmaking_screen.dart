import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/matchmaking_provider.dart';
import '../widgets/design_system.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchmakingProvider>().loadMyRequests();
    });
  }

  void _showCreateRequestDialog() {
    final goalCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'nutritionist';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Trova un Professionista"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  // Flutter 3.27+: 'value' è deprecato in favore di 'initialValue'
                  initialValue: type,
                  decoration: const InputDecoration(labelText: "Cosa cerchi?"),
                  items: const [
                    DropdownMenuItem(value: 'nutritionist', child: Text("Nutrizionista")),
                    DropdownMenuItem(value: 'personal_trainer', child: Text("Personal Trainer")),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: goalCtrl,
                  decoration: const InputDecoration(
                    labelText: "Il tuo Obiettivo Principale",
                    hintText: "Es. Perdere peso, Aumentare massa...",
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Note (Opzionale)",
                    hintText: "Preferenze, intolleranze, etc.",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annulla"),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<MatchmakingProvider>().createRequest(
                    type,
                    goalCtrl.text,
                    notesCtrl.text,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Richiesta pubblicata!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Errore: $e")),
                    );
                  }
                }
              },
              child: const Text("Pubblica Richiesta"),
            ),
          ],
        ),
      ),
    );
  }

  void _acceptOffer(String reqId, String offerId) async {
    try {
      await context.read<MatchmakingProvider>().acceptOffer(reqId, offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Offerta accettata! Torna alla Home per iniziare.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e")),
        );
      }
    }
  }

  Future<void> _confirmCancelRequest(String reqId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancellare la richiesta?"),
        content: const Text(
          "Le offerte ricevute verranno automaticamente rifiutate. "
          "Potrai crearne una nuova in qualsiasi momento.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cancella richiesta"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<MatchmakingProvider>().cancelRequest(reqId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Richiesta cancellata.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        title: const Text("Trova il tuo Coach"),
        backgroundColor: KyboColors.surface(context),
        foregroundColor: KyboColors.textPrimary(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<MatchmakingProvider>().loadMyRequests(),
          )
        ],
      ),
      body: Consumer<MatchmakingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.myRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.myRequests.isEmpty) {
            return Center(child: Text("Errore: ${provider.error}", style: const TextStyle(color: Colors.red)));
          }

          if (provider.myRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("Non hai ancora cercato un professionista.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  PillButton(
                    label: "inizia la ricerca",
                    icon: Icons.add,
                    onPressed: _showCreateRequestDialog,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.myRequests.length,
            itemBuilder: (context, index) {
              final req = provider.myRequests[index];
              final isPT = req['coach_type'] == 'personal_trainer';
              final isOpen = req['status'] == 'open';
              final offers = req['offers'] as List<dynamic>? ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(isPT ? Icons.fitness_center : Icons.restaurant, color: isPT ? Colors.teal : Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPT ? "Ricerca Personal Trainer" : "Ricerca Nutrizionista",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOpen ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOpen ? "APERTA" : "CHIUSA",
                              style: TextStyle(
                                fontSize: 12,
                                color: isOpen ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Cancella richiesta (solo se aperta)
                          if (isOpen)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: "Cancella richiesta",
                              onPressed: () => _confirmCancelRequest(req['id']),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Il tuo Obiettivo:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(req['goal'] ?? '', style: const TextStyle(fontSize: 16)),

                      if (offers.isNotEmpty) ...[
                        const Divider(height: 32),
                        const Text("Offerte Ricevute", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...offers.map((offer) {
                          // Usa offer['status'] come fonte di verità: il server
                          // ora può restituire pending/accepted/rejected/withdrawn.
                          final offerStatus = offer['status'] as String? ?? 'pending';
                          final isAccepted = offerStatus == 'accepted';
                          final isInactive = offerStatus == 'rejected' || offerStatus == 'withdrawn';

                          Color borderColor;
                          Color bgColor;
                          if (isAccepted) {
                            borderColor = KyboColors.primary;
                            bgColor = KyboColors.primary.withValues(alpha: 0.1);
                          } else if (isInactive) {
                            borderColor = Colors.grey.shade300;
                            bgColor = Colors.grey.withValues(alpha: 0.06);
                          } else {
                            borderColor = Colors.grey.shade300;
                            bgColor = KyboColors.surface(context);
                          }

                          String? statusLabel;
                          if (offerStatus == 'rejected') statusLabel = 'Rifiutata';
                          if (offerStatus == 'withdrawn') statusLabel = 'Ritirata dal coach';
                          if (offerStatus == 'accepted') statusLabel = 'Accettata';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: isInactive ? Colors.grey : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        offer['professional_name'] ?? 'Professionista',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isInactive ? Colors.grey : null,
                                          decoration: isInactive ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (statusLabel != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAccepted
                                              ? KyboColors.primary.withValues(alpha: 0.15)
                                              : Colors.grey.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isAccepted ? KyboColors.primary : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  offer['notes'] ?? '',
                                  style: TextStyle(color: isInactive ? Colors.grey : null),
                                ),
                                if (offer['price_info'] != null && offer['price_info'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    "Prezzo: ${offer['price_info']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isInactive ? Colors.grey : KyboColors.accent,
                                    ),
                                  ),
                                ],
                                // Il pulsante "Accetta" appare solo su offerte ancora pending
                                // e se la richiesta è aperta.
                                if (isOpen && offerStatus == 'pending') ...[
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: PillButton(
                                      label: "Accetta Offerta",
                                      onPressed: () => _acceptOffer(req['id'], offer['id']),
                                    ),
                                  )
                                ]
                              ],
                            ),
                          );
                        }),
                      ] else if (isOpen) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: Text("In attesa di offerte da professionisti...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRequestDialog,
        icon: const Icon(Icons.search),
        label: const Text("Cerca ancora"),
        backgroundColor: KyboColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
