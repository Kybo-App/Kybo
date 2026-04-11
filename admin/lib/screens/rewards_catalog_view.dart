// Schermata admin per gestire il catalogo premi (Reward System).
// _loadCatalog — carica tutti i premi dal backend inclusi quelli disattivati.
// _createOrEditReward — dialog per creare/modificare un premio.
// _fulfillClaim — segna un riscatto come evaso.
import 'package:flutter/material.dart';
import '../admin_repository.dart';
import '../widgets/design_system.dart';

class RewardsCatalogView extends StatefulWidget {
  const RewardsCatalogView({super.key});

  @override
  State<RewardsCatalogView> createState() => _RewardsCatalogViewState();
}

class _RewardsCatalogViewState extends State<RewardsCatalogView>
    with SingleTickerProviderStateMixin {
  final AdminRepository _repo = AdminRepository();
  late TabController _tabController;

  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _claims = [];
  bool _isLoadingRewards = true;
  bool _isLoadingClaims = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCatalog();
    _loadClaims();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoadingRewards = true);
    try {
      final data = await _repo.getRewardsCatalog();
      if (mounted) {
        setState(() {
          _rewards = List<Map<String, dynamic>>.from(data['rewards'] ?? []);
          _isLoadingRewards = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRewards = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoadingClaims = true);
    try {
      final data = await _repo.getRewardsClaims();
      if (mounted) {
        setState(() {
          _claims = List<Map<String, dynamic>>.from(data['claims'] ?? []);
          _isLoadingClaims = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClaims = false);
      }
    }
  }

  void _showCreateEditDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final xpCtrl = TextEditingController(
        text: existing?['xp_cost']?.toString() ?? '');
    final imageCtrl =
        TextEditingController(text: existing?['image_url'] ?? '');
    final stockCtrl = TextEditingController(
        text: existing?['stock']?.toString() ?? '');
    bool isActive = existing?['is_active'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: KyboColors.surface,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: Row(
              children: [
                Icon(
                  existing == null
                      ? Icons.add_circle_rounded
                      : Icons.edit_rounded,
                  color: KyboColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  existing == null ? 'Nuovo Premio' : 'Modifica Premio',
                  style: TextStyle(
                    color: KyboColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PillTextField(
                      controller: nameCtrl,
                      hintText: 'Nome premio',
                      prefixIcon: Icons.card_giftcard_rounded,
                    ),
                    const SizedBox(height: 12),
                    PillTextField(
                      controller: descCtrl,
                      hintText: 'Descrizione (opzionale)',
                      prefixIcon: Icons.description_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PillTextField(
                            controller: xpCtrl,
                            hintText: 'Costo XP',
                            prefixIcon: Icons.star_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PillTextField(
                            controller: stockCtrl,
                            hintText: 'Stock (vuoto = illimitato)',
                            prefixIcon: Icons.inventory_2_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PillTextField(
                      controller: imageCtrl,
                      hintText: 'URL immagine (opzionale)',
                      prefixIcon: Icons.image_rounded,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Switch(
                          value: isActive,
                          activeTrackColor: KyboColors.primary,
                          onChanged: (v) =>
                              setDialogState(() => isActive = v),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isActive ? 'Attivo' : 'Disattivato',
                          style: TextStyle(
                            color: KyboColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Annulla',
                  style: TextStyle(color: KyboColors.textSecondary),
                ),
              ),
              PillButton(
                label: existing == null ? 'Crea' : 'Salva',
                icon: existing == null ? Icons.add : Icons.save,
                backgroundColor: KyboColors.primary,
                textColor: Colors.white,
                height: 40,
                isLoading: isSaving,
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final xpStr = xpCtrl.text.trim();
                        if (name.isEmpty || xpStr.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Nome e costo XP obbligatori')),
                          );
                          return;
                        }
                        final xpCost = int.tryParse(xpStr);
                        if (xpCost == null || xpCost <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Costo XP non valido')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          final stockStr = stockCtrl.text.trim();
                          final stock = stockStr.isNotEmpty
                              ? int.tryParse(stockStr)
                              : null;

                          if (existing == null) {
                            await _repo.createReward(
                              name: name,
                              description: descCtrl.text.trim(),
                              xpCost: xpCost,
                              imageUrl: imageCtrl.text.trim().isNotEmpty
                                  ? imageCtrl.text.trim()
                                  : null,
                              stock: stock,
                              isActive: isActive,
                            );
                          } else {
                            await _repo.updateReward(
                              existing['id'],
                              name: name,
                              description: descCtrl.text.trim(),
                              xpCost: xpCost,
                              imageUrl: imageCtrl.text.trim(),
                              stock: stock,
                              isActive: isActive,
                            );
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadCatalog();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Errore: $e'),
                                backgroundColor: KyboColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteReward(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          'Elimina premio',
          style: TextStyle(color: KyboColors.textPrimary),
        ),
        content: Text(
          'Vuoi eliminare "$name"? L\'azione è irreversibile.',
          style: TextStyle(color: KyboColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla',
                style: TextStyle(color: KyboColors.textSecondary)),
          ),
          PillButton(
            label: 'Elimina',
            icon: Icons.delete_rounded,
            backgroundColor: KyboColors.error,
            textColor: Colors.white,
            height: 36,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteReward(id);
        _loadCatalog();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: KyboColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _fulfillClaim(String userUid, String claimId) async {
    try {
      await _repo.fulfillRewardClaim(userUid, claimId);
      _loadClaims();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Premio segnato come evaso ✓'),
            backgroundColor: KyboColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.card_giftcard_rounded,
                color: KyboColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Gestione Premi',
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            PillButton(
              label: 'Nuovo Premio',
              icon: Icons.add_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 40,
              onPressed: () => _showCreateEditDialog(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tabs
        Container(
          decoration: BoxDecoration(
            color: KyboColors.background,
            borderRadius: KyboBorderRadius.pill,
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: KyboColors.primary,
              borderRadius: KyboBorderRadius.pill,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: KyboColors.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.storefront_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Catalogo (${_rewards.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Riscatti (${_claims.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCatalogTab(),
              _buildClaimsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogTab() {
    if (_isLoadingRewards) {
      return Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    if (_rewards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded,
                size: 56, color: KyboColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Nessun premio nel catalogo',
              style: TextStyle(
                fontSize: 16,
                color: KyboColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea il primo premio con il pulsante in alto',
              style: TextStyle(
                fontSize: 13,
                color: KyboColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rewards.length,
      itemBuilder: (context, index) {
        final reward = _rewards[index];
        return _buildRewardRow(reward);
      },
    );
  }

  Widget _buildRewardRow(Map<String, dynamic> reward) {
    final isActive = reward['is_active'] ?? false;
    final xpCost = reward['xp_cost'] ?? 0;
    final stock = reward['stock'];
    final claimedCount = reward['claimed_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(
          color: isActive
              ? KyboColors.border
              : KyboColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? KyboColors.primary.withValues(alpha: 0.1)
                  : KyboColors.textMuted.withValues(alpha: 0.1),
              borderRadius: KyboBorderRadius.medium,
            ),
            child: reward['image_url'] != null &&
                    (reward['image_url'] as String).isNotEmpty
                ? ClipRRect(
                    borderRadius: KyboBorderRadius.medium,
                    child: Image.network(
                      reward['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.card_giftcard_rounded,
                        color: isActive
                            ? KyboColors.primary
                            : KyboColors.textMuted,
                      ),
                    ),
                  )
                : Icon(
                    Icons.card_giftcard_rounded,
                    color: isActive
                        ? KyboColors.primary
                        : KyboColors.textMuted,
                  ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reward['name'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: KyboColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!isActive)
                      PillBadge(
                        label: 'Disattivato',
                        icon: Icons.visibility_off_rounded,
                        color: KyboColors.error,
                      ),
                  ],
                ),
                if (reward['description'] != null &&
                    (reward['description'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      reward['description'],
                      style: TextStyle(
                        fontSize: 13,
                        color: KyboColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.star_rounded,
                      '$xpCost XP',
                      KyboColors.warning,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.inventory_2_rounded,
                      stock != null ? '$stock rimasti' : '∞',
                      KyboColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.redeem_rounded,
                      '$claimedCount riscattati',
                      KyboColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillIconButton(
                icon: Icons.edit_rounded,
                color: KyboColors.primary,
                tooltip: 'Modifica',
                onPressed: () => _showCreateEditDialog(existing: reward),
              ),
              const SizedBox(width: 4),
              PillIconButton(
                icon: Icons.delete_rounded,
                color: KyboColors.error,
                tooltip: 'Elimina',
                onPressed: () =>
                    _deleteReward(reward['id'], reward['name'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: KyboBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsTab() {
    if (_isLoadingClaims) {
      return Center(
        child: CircularProgressIndicator(color: KyboColors.primary),
      );
    }

    if (_claims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56, color: KyboColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Nessun premio riscattato',
              style: TextStyle(
                fontSize: 16,
                color: KyboColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _claims.length,
      itemBuilder: (context, index) {
        final claim = _claims[index];
        return _buildClaimRow(claim);
      },
    );
  }

  Widget _buildClaimRow(Map<String, dynamic> claim) {
    final status = claim['status'] ?? 'pending';
    final isPending = status == 'pending';
    final userUid = claim['user_uid'] ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'fulfilled':
        statusColor = KyboColors.success;
        statusLabel = 'Evaso';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pending':
      default:
        statusColor = KyboColors.warning;
        statusLabel = 'In attesa';
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.background,
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: KyboColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claim['reward_name'] ?? 'Premio',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: KyboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 14, color: KyboColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      userUid.length > 12
                          ? '${userUid.substring(0, 12)}...'
                          : userUid,
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.star_rounded,
                        size: 14, color: KyboColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '-${claim['xp_spent'] ?? 0} XP',
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PillBadge(
            label: statusLabel,
            icon: statusIcon,
            color: statusColor,
          ),
          if (isPending) ...[
            const SizedBox(width: 8),
            PillButton(
              label: 'Evadi',
              icon: Icons.check_rounded,
              backgroundColor: KyboColors.success,
              textColor: Colors.white,
              height: 36,
              onPressed: () => _fulfillClaim(userUid, claim['id']),
            ),
          ],
        ],
      ),
    );
  }
}
