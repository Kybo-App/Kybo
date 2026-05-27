import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kybo_admin/admin_repository.dart';
import 'package:kybo_admin/core/app_localizations.dart';
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

  // [MONITOR MODE 2026-05-26] Admin osserva la bacheca matchmaking ma non
  // dovrebbe fare proposte (è una operazione da nutrizionista/PT).
  // _isAdminMonitor=true → banner in alto + bottoni "Make proposal" /
  // "Withdraw" nascosti.
  bool _isAdminMonitor = false;

  @override
  void initState() {
    super.initState();
    _loadRoleAndFetch();
  }

  Future<void> _loadRoleAndFetch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = (doc.data()?['role'] ?? '').toString();
        if (mounted) {
          setState(() => _isAdminMonitor = role == 'admin');
        }
      } catch (_) {/* fallback: assume non-admin → tutto visibile */}
    }
    _fetchBoard();
  }

  Future<void> _fetchBoard() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      final board = await _repo.getMatchmakingBoard();
      setState(() => _requests = board);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l10n.error}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _withdrawOffer(String reqId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.matchmakingWithdrawTitle),
        content: Text(l10n.matchmakingWithdrawBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.matchmakingWithdrawOffer),
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
                ? l10n.matchmakingWithdrawn
                : l10n.matchmakingNoOffer),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l10n.error}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOfferDialog(String reqId, String roleType) {
    final l10n = AppLocalizations.of(context);
    final notesCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.matchmakingMakeProposal),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.matchmakingProposalDescription),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.matchmakingMessage,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(
                labelText: l10n.matchmakingPriceHint,
                hintText: l10n.matchmakingPricePlaceholder,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
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
                    SnackBar(content: Text(l10n.matchmakingOfferSent)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${l10n.error}: $e")),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text(l10n.matchmakingSendOffer),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayRequests = _requests.where((r) {
      if (_filterType == 'all') return true;
      return r['coach_type'] == _filterType;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isAdminMonitor) ...[
          _MonitorModeBanner(
            message: l10n.locale.languageCode == 'it'
                ? 'Modalità monitor: stai osservando la bacheca come admin. '
                    'Le azioni di proposta sono riservate a nutrizionisti e PT.'
                : 'Monitor mode: viewing the board as admin. Proposal actions '
                    'are reserved to nutritionists and PTs.',
          ),
          const SizedBox(height: 16),
        ],
         Row(
          children: [
            Text(
              l10n.matchmakingTitle,
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _filterType,
              items: [
                DropdownMenuItem(
                    value: 'all', child: Text(l10n.matchmakingAll)),
                DropdownMenuItem(
                    value: 'nutritionist',
                    child: Text(l10n.roleNutritionist)),
                DropdownMenuItem(
                    value: 'personal_trainer',
                    child: Text(l10n.rolePersonalTrainer)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _filterType = val);
              },
            ),
            const SizedBox(width: 16),
             PillIconButton(
              icon: Icons.refresh_rounded,
              color: KyboColors.primary,
              tooltip: l10n.refresh,
              onPressed: _fetchBoard,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isLoading)
           const LinearProgressIndicator(),

        const SizedBox(height: 16),

        if (displayRequests.isEmpty && !_isLoading)
          Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(l10n.matchmakingNoAnnouncements,
                style: const TextStyle(color: Colors.grey)),
          )),

        Expanded(
          child: ListView.builder(
            itemCount: displayRequests.length,
            itemBuilder: (context, index) {
              final req = displayRequests[index];
              final isPT = req['coach_type'] == 'personal_trainer';
              final date = req['created_at'] != null ? DateTime.tryParse(req['created_at']) : null;
              final timeagoLocale = l10n.locale.languageCode == 'it' ? 'it' : 'en';
              final timeString = date != null
                  ? timeago.format(date, locale: timeagoLocale)
                  : l10n.missingDate;

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
                            isPT
                                ? l10n.matchmakingFindPT
                                : l10n.matchmakingFindNutritionist,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.matchmakingObjectiveLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(req['goal'] ?? '', style: const TextStyle(fontSize: 14)),
                      if (req['notes'] != null && req['notes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(l10n.matchmakingUserNotes,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(req['notes'], style: const TextStyle(fontSize: 14)),
                      ],
                      // Azioni nascoste in modalità monitor (admin) —
                      // l'admin non fa proposte, le osserva soltanto.
                      if (!_isAdminMonitor) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _withdrawOffer(req['id']),
                              icon: const Icon(Icons.undo_rounded, size: 16),
                              label: Text(l10n.matchmakingWithdrawOffer),
                              style: TextButton.styleFrom(
                                foregroundColor: KyboColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () =>
                                  _showOfferDialog(req['id'], req['coach_type']),
                              icon: const Icon(Icons.handshake),
                              label: Text(l10n.matchmakingMakeProposal),
                            ),
                          ],
                        ),
                      ],
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

/// Banner che appare in cima a una view quando l'admin la sta visualizzando
/// in modalità "osservatore". Spiega che le azioni operative sono nascoste/
/// disabilitate perché riservate ad altri ruoli (nutrizionista, PT).
class _MonitorModeBanner extends StatelessWidget {
  final String message;
  const _MonitorModeBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KyboColors.warning.withValues(alpha: 0.10),
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(
          color: KyboColors.warning.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_rounded,
            color: KyboColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
