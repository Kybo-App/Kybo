// Schermata admin per gestire il catalogo premi (Reward System).
// _loadCatalog — carica tutti i premi dal backend inclusi quelli disattivati.
// _createOrEditReward — dialog per creare/modificare un premio.
// _fulfillClaim — segna un riscatto come evaso.
import 'package:flutter/material.dart';
import '../admin_repository.dart';
import '../core/app_localizations.dart';
import '../core/error_mapper.dart';
import '../widgets/design_system.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/state_views.dart';

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
  // [UX R2] Errore di caricamento tenuto distinto dallo stato "catalogo
  // vuoto": prima un load fallito mostrava l'empty state — indistinguibile
  // da un catalogo davvero vuoto e senza modo di riprovare.
  Object? _rewardsError;
  Object? _claimsError;

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
    setState(() {
      _isLoadingRewards = true;
      _rewardsError = null;
    });
    try {
      final data = await _repo.getRewardsCatalog();
      if (mounted) {
        setState(() {
          _rewards = List<Map<String, dynamic>>.from(data['rewards'] ?? []);
          _isLoadingRewards = false;
        });
      }
    } catch (e) {
      // Errore in-page con retry (KyboErrorView nel tab), non snackbar
      // volatile: il caricamento della pagina è un errore "persistente".
      if (mounted) {
        setState(() {
          _rewardsError = e;
          _isLoadingRewards = false;
        });
      }
    }
  }

  Future<void> _loadClaims() async {
    setState(() {
      _isLoadingClaims = true;
      _claimsError = null;
    });
    try {
      final data = await _repo.getRewardsClaims();
      if (mounted) {
        setState(() {
          _claims = List<Map<String, dynamic>>.from(data['claims'] ?? []);
          _isLoadingClaims = false;
        });
      }
    } catch (e) {
      // [UX R5] Prima questo catch era completamente muto: tab riscatti
      // vuoto senza spiegazione. Ora errore visibile con retry.
      if (mounted) {
        setState(() {
          _claimsError = e;
          _isLoadingClaims = false;
        });
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
    final redirectCtrl =
        TextEditingController(text: existing?['redirect_url'] ?? '');
    final stockCtrl = TextEditingController(
        text: existing?['stock']?.toString() ?? '');
    bool isActive = existing?['is_active'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // [UX R6] Gating reattivo: il submit resta disabilitato finché
          // nome e costo XP non sono validi (prima la validazione avveniva
          // solo al click, via snackbar).
          final xpText = xpCtrl.text.trim();
          final xpVal = int.tryParse(xpText);
          final xpInvalid = xpText.isNotEmpty && (xpVal == null || xpVal <= 0);
          final canSubmit =
              nameCtrl.text.trim().isNotEmpty && xpVal != null && xpVal > 0;

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
                  existing == null
                      ? AppLocalizations.of(ctx).rewardsNew
                      : AppLocalizations.of(ctx).rewardsEditDialog,
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
                      hintText: AppLocalizations.of(ctx).rewardsNamePlaceholder,
                      prefixIcon: Icons.card_giftcard_rounded,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    PillTextField(
                      controller: descCtrl,
                      hintText:
                          AppLocalizations.of(ctx).rewardsDescriptionPlaceholder,
                      prefixIcon: Icons.description_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PillTextField(
                            controller: xpCtrl,
                            hintText: AppLocalizations.of(ctx).rewardsCostHint,
                            prefixIcon: Icons.star_rounded,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PillTextField(
                            controller: stockCtrl,
                            hintText: AppLocalizations.of(ctx).rewardsStockHint,
                            prefixIcon: Icons.inventory_2_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    // [UX R6/R7] Errore inline accanto al campo, non snackbar.
                    if (xpInvalid)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppLocalizations.of(ctx).rewardsCostInvalid,
                            style: TextStyle(
                                fontSize: 12, color: KyboColors.error),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    PillTextField(
                      controller: imageCtrl,
                      hintText: AppLocalizations.of(ctx).rewardsImageUrl,
                      prefixIcon: Icons.image_rounded,
                    ),
                    const SizedBox(height: 12),
                    PillTextField(
                      controller: redirectCtrl,
                      hintText: AppLocalizations.of(ctx).rewardsRedeemUrl,
                      prefixIcon: Icons.open_in_new_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 12),
                      child: Text(
                        AppLocalizations.of(ctx).rewardsRedeemUrlHelp,
                        style: TextStyle(fontSize: 11, color: KyboColors.textMuted),
                      ),
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
                          isActive
                              ? AppLocalizations.of(ctx).rewardsActiveStatus
                              : AppLocalizations.of(ctx).rewardsInactiveStatus,
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
                  AppLocalizations.of(ctx).cancel,
                  style: TextStyle(color: KyboColors.textSecondary),
                ),
              ),
              PillButton(
                label: existing == null
                    ? AppLocalizations.of(ctx).create
                    : AppLocalizations.of(ctx).save,
                icon: existing == null ? Icons.add : Icons.save,
                backgroundColor: KyboColors.primary,
                textColor: Colors.white,
                height: 40,
                isLoading: isSaving,
                onPressed: (isSaving || !canSubmit)
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final xpCost = xpVal;

                        setDialogState(() => isSaving = true);
                        try {
                          final stockStr = stockCtrl.text.trim();
                          final stock = stockStr.isNotEmpty
                              ? int.tryParse(stockStr)
                              : null;

                          final redirect = redirectCtrl.text.trim();
                          if (existing == null) {
                            await _repo.createReward(
                              name: name,
                              description: descCtrl.text.trim(),
                              xpCost: xpCost,
                              imageUrl: imageCtrl.text.trim().isNotEmpty
                                  ? imageCtrl.text.trim()
                                  : null,
                              redirectUrl: redirect.isNotEmpty ? redirect : null,
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
                              redirectUrl: redirect,
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
                                content: Text(ErrorMapper.toUserMessage(e)),
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
          AppLocalizations.of(ctx).rewardsDeleteTitle,
          style: TextStyle(color: KyboColors.textPrimary),
        ),
        content: Text(
          AppLocalizations.of(ctx).rewardsDeleteConfirm(name),
          style: TextStyle(color: KyboColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).cancel,
                style: TextStyle(color: KyboColors.textSecondary)),
          ),
          PillButton(
            label: AppLocalizations.of(ctx).delete,
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
              content: Text(ErrorMapper.toUserMessage(e)),
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
            content: Text(AppLocalizations.of(context).rewardsRedeemed),
            backgroundColor: KyboColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.toUserMessage(e)),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.card_giftcard_rounded,
                color: KyboColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              l10n.rewardsManagement,
              style: TextStyle(
                color: KyboColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            PillButton(
              label: l10n.rewardsNew,
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
                    Text('${l10n.rewardsCatalogTab} (${_rewards.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('${l10n.rewardsClaimsTab} (${_claims.length})'),
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
    final l10n = AppLocalizations.of(context);
    if (_isLoadingRewards) {
      return const SkeletonUserList(itemCount: 5);
    }

    if (_rewardsError != null) {
      return KyboErrorView.fromError(_rewardsError!, onRetry: _loadCatalog);
    }

    if (_rewards.isEmpty) {
      // [UX R8] Empty "da riempire" con CTA diretta: apre il dialog di
      // creazione invece di lasciare l'admin a cercare il bottone altrove.
      return KyboEmptyView(
        icon: Icons.storefront_rounded,
        title: l10n.rewardsNoneInCatalog,
        subtitle: l10n.rewardsCreateFirst,
        actionLabel: 'Aggiungi il primo premio',
        onAction: () => _showCreateEditDialog(),
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
                      errorBuilder: (context, error, stackTrace) => Icon(
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
                        label:
                            AppLocalizations.of(context).rewardsInactiveStatus,
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
                      stock != null
                          ? (AppLocalizations.of(context).locale.languageCode ==
                                  'it'
                              ? '$stock rimasti'
                              : '$stock left')
                          : '∞',
                      KyboColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.redeem_rounded,
                      AppLocalizations.of(context).locale.languageCode == 'it'
                          ? '$claimedCount riscattati'
                          : '$claimedCount redeemed',
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
                tooltip: AppLocalizations.of(context).edit,
                onPressed: () => _showCreateEditDialog(existing: reward),
              ),
              const SizedBox(width: 4),
              PillIconButton(
                icon: Icons.delete_rounded,
                color: KyboColors.error,
                tooltip: AppLocalizations.of(context).delete,
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
      return const SkeletonUserList(itemCount: 5);
    }

    if (_claimsError != null) {
      return KyboErrorView.fromError(_claimsError!, onRetry: _loadClaims);
    }

    if (_claims.isEmpty) {
      return KyboEmptyView(
        icon: Icons.receipt_long_rounded,
        title: AppLocalizations.of(context).rewardsNoneRedeemed,
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
    final l10n = AppLocalizations.of(context);
    final status = claim['status'] ?? 'pending';
    final isPending = status == 'pending';
    final userUid = claim['user_uid'] ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'fulfilled':
        statusColor = KyboColors.success;
        statusLabel = l10n.rewardsStatusFulfilled;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pending':
      default:
        statusColor = KyboColors.warning;
        statusLabel = l10n.rewardsStatusPending;
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
                  claim['reward_name'] ?? l10n.rewardsTitle,
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
              label: l10n.rewardsFulfill,
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
