import 'package:flutter/material.dart';
import 'package:kybo_admin/admin_repository.dart';
import 'package:kybo_admin/widgets/design_system.dart';
import 'package:timeago/timeago.dart' as timeago;

class MatchmakingBoardView extends StatefulWidget {
  const MatchmakingBoardView({super.key});

  @override
  State<MatchmakingBoardView> createState() => _MatchmakingBoardViewState();
}

class _MatchmakingBoardViewState extends State<MatchmakingBoardView> {
  // AdminRepository non è registrato come Provider a livello di AdminApp.
  // Tutti gli altri view lo istanziano direttamente: facciamo lo stesso qui,
  // altrimenti context.read<AdminRepository>() solleva ProviderNotFoundException.
  final AdminRepository _repo = AdminRepository();

  bool _isLoading = false;
  List<dynamic> _requests = [];
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _fetchBoard();
  }

  Future<void> _fetchBoard() async {
    setState(() => _isLoading = true);
    try {
      final board = await _repo.getMatchmakingBoard();
      setState(() => _requests = board);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _withdrawOffer(String reqId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ritirare l'offerta?"),
        content: const Text(
          "La tua offerta verrà marcata come ritirata. Potrai farne una nuova "
          "finché la richiesta è aperta.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ritira offerta"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final existed = await _repo.withdrawMatchmakingOffer(reqId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existed
                ? "Offerta ritirata."
                : "Non risulta una tua offerta su questa richiesta."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOfferDialog(String reqId, String roleType) {
    final notesCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Fai una Proposta"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Descrivi perché saresti la scelta migliore per questo utente."),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Il tuo messaggio/proposta",
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: "Indicazione Prezzo (Opzionale)",
                hintText: "Es. 50€/mese, o 'Pacchetto Premium'",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _repo.makeMatchmakingOffer(
                  reqId,
                  notesCtrl.text,
                  priceCtrl.text.isEmpty ? null : priceCtrl.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Offerta inviata! L'utente riceverà la tua proposta.")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Errore: $e")),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Invia Offerta"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayRequests = _requests.where((r) {
      if (_filterType == 'all') return true;
      return r['coach_type'] == _filterType;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
         Row(
          children: [
            Text(
              "Bacheca Annunci",
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _filterType,
              items: const [
                DropdownMenuItem(value: 'all', child: Text("Tutti")),
                DropdownMenuItem(value: 'nutritionist', child: Text("Nutrizionista")),
                DropdownMenuItem(value: 'personal_trainer', child: Text("Personal Trainer")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _filterType = val);
              },
            ),
            const SizedBox(width: 16),
             PillIconButton(
              icon: Icons.refresh_rounded,
              color: KyboColors.primary,
              tooltip: "Ricarica",
              onPressed: _fetchBoard,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isLoading) 
           const LinearProgressIndicator(),
        
        const SizedBox(height: 16),
        
        if (displayRequests.isEmpty && !_isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text("Nessun annuncio presente.", style: TextStyle(color: Colors.grey)),
          )),

        Expanded(
          child: ListView.builder(
            itemCount: displayRequests.length,
            itemBuilder: (context, index) {
              final req = displayRequests[index];
              final isPT = req['coach_type'] == 'personal_trainer';
              final date = req['created_at'] != null ? DateTime.tryParse(req['created_at']) : null;
              final timeString = date != null ? timeago.format(date, locale: 'it') : 'Manca data';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                           Icon(
                            isPT ? Icons.fitness_center : Icons.restaurant, 
                            color: isPT ? Colors.teal : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPT ? "Cerca Personal Trainer" : "Cerca Nutrizionista",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Obiettivo:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(req['goal'] ?? '', style: const TextStyle(fontSize: 14)),
                      if (req['notes'] != null && req['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text("Note utente:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(req['notes'], style: const TextStyle(fontSize: 14)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _withdrawOffer(req['id']),
                            icon: const Icon(Icons.undo_rounded, size: 16),
                            label: const Text("Ritira offerta"),
                            style: TextButton.styleFrom(
                              foregroundColor: KyboColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showOfferDialog(req['id'], req['coach_type']),
                            icon: const Icon(Icons.handshake),
                            label: const Text("Fai una Proposta"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
