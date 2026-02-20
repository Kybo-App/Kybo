import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';
import '../models/badge_model.dart';
import '../widgets/design_system.dart';
import 'package:intl/intl.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Controlla se c'è un badge appena sbloccato o un level-up da mostrare
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForCelebration());
  }

  void _checkForCelebration() {
    final svc = context.read<BadgeService>();
    if (svc.justLeveledUp != null) {
      _showLevelUpDialog(svc.justLeveledUp!);
      svc.clearJustUnlocked();
    } else if (svc.justUnlocked != null) {
      _showBadgeUnlockedSnackbar(svc.justUnlocked!);
      svc.clearJustUnlocked();
    }
  }

  void _showLevelUpDialog(BadgeLevel level) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                KyboColors.primary,
                KyboColors.primary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: KyboBorderRadius.large,
            boxShadow: [
              BoxShadow(
                color: KyboColors.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                level.emoji,
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nuovo Livello!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                level.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: KyboColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: KyboBorderRadius.pill,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Fantastico!',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeUnlockedSnackbar(BadgeModel badge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: KyboColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.pill),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(badge.icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🏆 Badge sbloccato: ${badge.title}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BadgeService>();
    final badges = svc.badges;
    final unlockedCount = svc.unlockedCount;
    final totalCount = badges.length;
    final level = svc.currentLevel;

    // Prossimo livello
    final levelIndex = kBadgeLevels.indexOf(level);
    final isMaxLevel = levelIndex == kBadgeLevels.length - 1;
    final nextLevel = isMaxLevel ? null : kBadgeLevels[levelIndex + 1];

    // Progress verso il prossimo livello
    final progressInLevel = unlockedCount - level.minBadges;
    final neededForNext = isMaxLevel ? 1 : (nextLevel!.minBadges - level.minBadges);
    final levelProgress = neededForNext > 0
        ? (progressInLevel / neededForNext).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        title: const Text('Traguardi'),
        backgroundColor: KyboColors.surface(context),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEVEL CARD ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    KyboColors.primary,
                    KyboColors.primary.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: KyboBorderRadius.large,
                boxShadow: [
                  BoxShadow(
                    color: KyboColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${level.emoji}  ${level.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$unlockedCount / $totalCount badge sbloccati',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Progress bar verso prossimo livello
                  if (!isMaxLevel) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Verso ${nextLevel!.emoji} ${nextLevel.name}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$progressInLevel / $neededForNext',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: KyboBorderRadius.pill,
                      child: LinearProgressIndicator(
                        value: levelProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ] else ...[
                    // Livello massimo raggiunto
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: KyboBorderRadius.pill,
                      ),
                      child: const Text(
                        '⭐ Livello massimo raggiunto!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── SCALA LIVELLI ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: KyboColors.surface(context),
                borderRadius: KyboBorderRadius.large,
                border: Border.all(color: KyboColors.border(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: kBadgeLevels.map((lvl) {
                  final isCurrent = lvl.name == level.name;
                  final isReached = unlockedCount >= lvl.minBadges;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lvl.emoji,
                        style: TextStyle(
                          fontSize: isCurrent ? 24 : 18,
                          color: isReached
                              ? null
                              : KyboColors.textMuted(context)
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lvl.name,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w400,
                          color: isCurrent
                              ? KyboColors.primary
                              : isReached
                                  ? KyboColors.textSecondary(context)
                                  : KyboColors.textMuted(context)
                                      .withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 28),

            // ─── TITOLO GRIGLIA ───────────────────────────────────────
            Text(
              'I tuoi badge',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // ─── GRIGLIA BADGE ────────────────────────────────────────
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: badges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (ctx, index) {
                final badge = badges[index];
                return _BadgeCard(badge: badge);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BADGE CARD
// =============================================================================

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = badge.isUnlocked;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.large,
        border: Border.all(
          color: isUnlocked
              ? KyboColors.primary.withValues(alpha: 0.5)
              : KyboColors.border(context),
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: KyboColors.primary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icona
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? KyboColors.primary.withValues(alpha: 0.1)
                  : KyboColors.background(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              badge.icon,
              size: 30,
              color: isUnlocked
                  ? KyboColors.primary
                  : KyboColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          // Titolo
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isUnlocked
                  ? KyboColors.textPrimary(context)
                  : KyboColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),

          // Descrizione
          Text(
            isUnlocked ? badge.description : '???',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: KyboColors.textSecondary(context),
            ),
          ),

          // Data sblocco
          if (isUnlocked && badge.unlockedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              DateFormat('dd/MM/yyyy').format(badge.unlockedAt!),
              style: TextStyle(
                fontSize: 10,
                color: KyboColors.primary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          // Lucchetto se bloccato
          if (!isUnlocked) ...[
            const SizedBox(height: 6),
            Icon(
              Icons.lock_rounded,
              size: 14,
              color: KyboColors.textMuted(context),
            ),
          ],
        ],
      ),
    );
  }
}
