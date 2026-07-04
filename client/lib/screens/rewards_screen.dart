// Schermata Shop Premi: mostra il catalogo reward con saldo XP, riscatto e storico.
// _loadCatalog — carica i premi attivi dal backend.
// _claimReward — riscatta un premio spendendo XP con conferma.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/error_handler.dart';
import '../services/api_client.dart';
import '../services/xp_service.dart';
import '../widgets/design_system.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/state_views.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;
  List<Map<String, dynamic>> _catalog = [];
  List<Map<String, dynamic>> _claims = [];
  bool _isLoadingCatalog = true;
  bool _isLoadingClaims = true;
  bool _isClaiming = false;
  String? _catalogError;
  String? _claimsError;

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
    if (mounted) setState(() => _catalogError = null);
    try {
      final data = await _api.get('/rewards/catalog') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _catalog = List<Map<String, dynamic>>.from(data['rewards'] ?? []);
          _isLoadingCatalog = false;
        });
      }
    } catch (e) {
      // [UX] Prima: solo debugPrint (invisibile in release) → il catalogo
      // vuoto sembrava "nessun premio". Ora distinguiamo errore da vuoto.
      debugPrint("Error loading rewards catalog: $e");
      if (mounted) {
        setState(() {
          _catalogError = ErrorMapper.toUserMessage(e);
          _isLoadingCatalog = false;
        });
      }
    }
  }

  Future<void> _loadClaims() async {
    if (mounted) setState(() => _claimsError = null);
    try {
      final data = await _api.get('/rewards/my-claims') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _claims = List<Map<String, dynamic>>.from(data['claims'] ?? []);
          _isLoadingClaims = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading claims: $e");
      if (mounted) {
        setState(() {
          _claimsError = ErrorMapper.toUserMessage(e);
          _isLoadingClaims = false;
        });
      }
    }
  }

  Future<void> _claimReward(Map<String, dynamic> reward) async {
    final xpService = context.read<XpService>();
    final xpCost = (reward['xp_cost'] as num?)?.toInt() ?? 0;

    if (xpService.totalXp < xpCost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'XP insufficienti! Hai ${xpService.totalXp} XP, servono $xpCost XP.',
            ),
            backgroundColor: KyboColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          'Riscatta Premio',
          style: TextStyle(color: KyboColors.textPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KyboColors.primary.withValues(alpha: 0.08),
                borderRadius: KyboBorderRadius.medium,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.card_giftcard_rounded,
                    size: 48,
                    color: KyboColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reward['name'] ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: KyboColors.textPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: KyboColors.warning, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$xpCost XP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: KyboColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Il tuo saldo dopo: ${xpService.totalXp - xpCost} XP',
              style: TextStyle(
                fontSize: 13,
                color: KyboColors.textSecondary(context),
              ),
            ),
          ],
        ),
        actions: [
          PillButton(
            label: 'Annulla',
            onPressed: () => Navigator.pop(ctx, false),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 44,
          ),
          PillButton(
            label: 'Riscatta',
            icon: Icons.redeem_rounded,
            onPressed: () => Navigator.pop(ctx, true),
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 44,
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClaiming = true);

    try {
      final data = await _api.post('/rewards/claim/${reward['id']}')
          as Map<String, dynamic>;

      if (!mounted) return;

      final newXpTotal = (data['new_xp_total'] as num?)?.toInt();

      HapticFeedback.mediumImpact();

      // Aggiorna XP locale al valore autorevole ritornato dal server
      // (non più un decremento locale — vedi audit RW1).
      if (newXpTotal != null) {
        xpService.setAuthoritativeXp(newXpTotal);
      }

      // Ricarica catalogo e storico
      _loadCatalog();
      _loadClaims();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('🎉 Premio "${reward['name']}" riscattato!'),
              ],
            ),
            backgroundColor: KyboColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: KyboBorderRadius.medium),
          ),
        );
      }

      // Se il premio ha un URL esterno associato (pagina sconto, shop
      // partner...), proponiamo al cliente di aprirlo subito.
      final redirect = (reward['redirect_url'] as String?)?.trim();
      if (mounted && redirect != null && redirect.isNotEmpty) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: KyboColors.surface(context),
            shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
            title: Text('Completa il riscatto', style: TextStyle(color: KyboColors.textPrimary(context))),
            content: Text(
              'Apri il link del premio per completare il riscatto.',
              style: TextStyle(color: KyboColors.textSecondary(context)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Dopo'),
              ),
              PillButton(
                label: 'Apri',
                icon: Icons.open_in_new_rounded,
                backgroundColor: KyboColors.primary,
                textColor: Colors.white,
                height: 40,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
        if (open == true) {
          final uri = Uri.tryParse(redirect);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: KyboColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error claiming reward: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore di connessione'),
            backgroundColor: KyboColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: KyboBorderRadius.medium),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final xpService = context.watch<XpService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        elevation: 0,
        title: Text(
          'Shop Premi',
          style: TextStyle(
            color: KyboColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: KyboColors.textPrimary(context)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: KyboColors.primary,
          unselectedLabelColor: KyboColors.textMuted(context),
          indicatorColor: KyboColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Catalogo', icon: Icon(Icons.storefront_rounded, size: 20)),
            Tab(text: 'I miei premi', icon: Icon(Icons.inventory_2_rounded, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // XP Balance Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [KyboColors.primary, KyboColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: KyboBorderRadius.large,
              boxShadow: [
                BoxShadow(
                  color: KyboColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Il tuo saldo',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${xpService.totalXp} XP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: KyboBorderRadius.pill,
                  ),
                  child: Text(
                    'Lv. ${xpService.levelNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCatalogTab(xpService),
                _buildClaimsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTab(XpService xpService) {
    if (_isLoadingCatalog) {
      return const SkeletonCardList(itemCount: 6);
    }

    if (_catalogError != null) {
      return KyboErrorView(message: _catalogError!, onRetry: _loadCatalog);
    }

    if (_catalog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 56,
                  color: KyboColors.primary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nessun premio disponibile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Torna più tardi, nuovi premi in arrivo!',
                style: TextStyle(
                  fontSize: 14,
                  color: KyboColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      color: KyboColors.primary,
      // [FIX M-3] AbsorbPointer durante il claim evita che il tap venga
      // propagato a più card mentre la transazione è in volo (il flag
      // _isClaiming sul singolo GestureDetector non previene i tap
      // partiti nello stesso frame).
      child: AbsorbPointer(
        absorbing: _isClaiming,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _catalog.length,
          itemBuilder: (context, index) {
            final reward = _catalog[index];
            return _buildRewardCard(reward, xpService);
          },
        ),
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward, XpService xpService) {
    final xpCost = (reward['xp_cost'] as num?)?.toInt() ?? 0;
    final stock = reward['stock'] as int?;
    final canAfford = xpService.totalXp >= xpCost;
    final isOutOfStock = stock != null && stock <= 0;

    return GestureDetector(
      onTap: (canAfford && !isOutOfStock && !_isClaiming)
          ? () => _claimReward(reward)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: KyboColors.surface(context),
          borderRadius: KyboBorderRadius.large,
          border: Border.all(
            color: canAfford && !isOutOfStock
                ? KyboColors.primary.withValues(alpha: 0.3)
                : KyboColors.border(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image / Icon placeholder
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: KyboColors.primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: reward['image_url'] != null &&
                              (reward['image_url'] as String).isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                reward['image_url'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 48,
                                  color:
                                      KyboColors.primary.withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.card_giftcard_rounded,
                              size: 48,
                              color:
                                  KyboColors.primary.withValues(alpha: 0.5),
                            ),
                    ),
                    if (isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'ESAURITO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (stock != null && stock > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: KyboBorderRadius.pill,
                          ),
                          child: Text(
                            '$stock rimasti',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Info section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward['name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: KyboColors.textPrimary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: canAfford && !isOutOfStock
                            ? KyboColors.primary.withValues(alpha: 0.1)
                            : KyboColors.textMuted(context)
                                .withValues(alpha: 0.1),
                        borderRadius: KyboBorderRadius.pill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: canAfford && !isOutOfStock
                                ? KyboColors.warning
                                : KyboColors.textMuted(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$xpCost XP',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: canAfford && !isOutOfStock
                                  ? KyboColors.primary
                                  : KyboColors.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsTab() {
    if (_isLoadingClaims) {
      return const SkeletonCardList(itemCount: 4);
    }

    if (_claimsError != null) {
      return KyboErrorView(message: _claimsError!, onRetry: _loadClaims);
    }

    if (_claims.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: KyboColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 56,
                  color: KyboColors.accent.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nessun premio riscattato',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: KyboColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Accumula XP e riscatta i tuoi premi!',
                style: TextStyle(
                  fontSize: 14,
                  color: KyboColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClaims,
      color: KyboColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _claims.length,
        itemBuilder: (context, index) {
          final claim = _claims[index];
          return _buildClaimCard(claim);
        },
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final status = claim['status'] ?? 'pending';
    final isFulfilled = status == 'fulfilled';

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

    // [FIX M-4] Il server serializza claimed_at/fulfilled_at come ISO8601
    // string. Mostra la data più recente rilevante per lo stato.
    String? dateLabel;
    final claimedRaw = claim['claimed_at'];
    final fulfilledRaw = claim['fulfilled_at'];
    if (isFulfilled && fulfilledRaw is String) {
      final dt = DateTime.tryParse(fulfilledRaw);
      if (dt != null) {
        dateLabel = 'Evaso il ${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    } else if (claimedRaw is String) {
      final dt = DateTime.tryParse(claimedRaw);
      if (dt != null) {
        dateLabel = 'Richiesto il ${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.large,
        border: Border.all(color: KyboColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFulfilled
                  ? Icons.card_giftcard_rounded
                  : Icons.card_giftcard_outlined,
              color: statusColor,
              size: 24,
            ),
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
                    color: KyboColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 14, color: KyboColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '-${claim['xp_spent'] ?? 0} XP',
                      style: TextStyle(
                        fontSize: 12,
                        color: KyboColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                if (dateLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: KyboColors.textSecondary(context).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: KyboBorderRadius.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
