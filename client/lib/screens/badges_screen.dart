// Schermata badge completa: 3 tab (Badge, Sfide, XP) con griglia badge tiered,
// sfide giornaliere e storico XP.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';
import '../services/xp_service.dart';
import '../services/challenge_service.dart';
import '../models/badge_model.dart';
import '../widgets/design_system.dart';
import '../widgets/badge_celebration_overlay.dart';
import '../widgets/badge_detail_sheet.dart';
import 'package:intl/intl.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForCelebration());
  }

  void _checkForCelebration() {
    final svc = context.read<BadgeService>();
    if (svc.justLeveledUp != null) {
      showBadgeCelebration(context, svc.justUnlocked!, levelUp: svc.justLeveledUp!);
      svc.clearJustUnlocked();
    } else if (svc.justUnlocked != null) {
      showBadgeCelebration(context, svc.justUnlocked!);
      svc.clearJustUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        title: const Text('Traguardi'),
        backgroundColor: KyboColors.surface(context),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: PillTabBar(
              tabs: const ['Badge', 'Sfide', 'XP'],
              selectedIndex: _selectedTab,
              onTabSelected: (i) => setState(() => _selectedTab = i),
            ),
          ),

          // Tab content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: const [
                _BadgesTab(),
                _ChallengesTab(),
                _XpTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  TAB 1: BADGES
// ═══════════════════════════════════════════════

class _BadgesTab extends StatelessWidget {
  const _BadgesTab();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BadgeService>();
    final xpSvc = context.watch<XpService>();
    final badges = svc.badges;
    final unlockedCount = svc.unlockedCount;
    final totalCount = badges.length;
    final level = xpSvc.currentLevel;

    final levelIndex = kBadgeLevels.indexOf(level);
    final isMaxLevel = levelIndex == kBadgeLevels.length - 1;
    final nextLevel = isMaxLevel ? null : kBadgeLevels[levelIndex + 1];

    final progressInLevel = xpSvc.totalXp - level.minXp;
    final neededForNext = isMaxLevel ? 1 : (nextLevel!.minXp - level.minXp);
    final levelProgress = neededForNext > 0
        ? (progressInLevel / neededForNext).clamp(0.0, 1.0)
        : 1.0;

    // Raggruppa badge per tipo
    final regularBadges = badges.where((b) => !b.isSecret).toList();
    final secretBadges = badges.where((b) => b.isSecret).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Level Card ───────────────────────
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
                            '$unlockedCount / $totalCount badge • ${xpSvc.totalXp} XP',
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
                      child: Center(
                        child: Text(
                          '${xpSvc.levelNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

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
                        '${xpSvc.xpForNextLevel} XP rimanenti',
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

          // ── Level Timeline ───────────────────
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
                final isReached = xpSvc.totalXp >= lvl.minXp;
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
                      lvl.name.length > 8 ? '${lvl.name.substring(0, 7)}.' : lvl.name,
                      style: TextStyle(
                        fontSize: 8,
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

          // ── Regular Badges ───────────────────
          Text(
            'I tuoi badge',
            style: TextStyle(
              color: KyboColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: regularBadges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (ctx, index) {
              final badge = regularBadges[index];
              return _BadgeCard(badge: badge);
            },
          ),

          // ── Secret Badges ────────────────────
          if (secretBadges.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              '🤫 Badge Segreti',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: secretBadges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (ctx, index) {
                final badge = secretBadges[index];
                return _BadgeCard(badge: badge);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  TAB 2: SFIDE
// ═══════════════════════════════════════════════

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab();

  @override
  Widget build(BuildContext context) {
    final challengeSvc = context.watch<ChallengeService>();
    final challenges = challengeSvc.dailyChallenges;
    final allDone = challengeSvc.allCompleted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header con data
          Row(
            children: [
              Icon(
                Icons.today_rounded,
                color: KyboColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Sfide di Oggi',
                style: TextStyle(
                  color: KyboColors.textPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM', 'it').format(DateTime.now()),
                style: TextStyle(
                  color: KyboColors.textMuted(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Challenge cards
          if (challenges.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: KyboColors.surface(context),
                borderRadius: KyboBorderRadius.large,
                border: Border.all(color: KyboColors.border(context)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 48,
                    color: KyboColors.textMuted(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Caricamento sfide...',
                    style: TextStyle(
                      color: KyboColors.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            ...challenges.map((c) => _ChallengeCard(challenge: c)),

          const SizedBox(height: 16),

          // Bonus card
          if (challenges.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: allDone
                    ? KyboColors.primary.withValues(alpha: 0.08)
                    : KyboColors.surface(context),
                borderRadius: KyboBorderRadius.large,
                border: Border.all(
                  color: allDone
                      ? KyboColors.primary.withValues(alpha: 0.3)
                      : KyboColors.border(context),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: allDone
                          ? KyboColors.primary.withValues(alpha: 0.15)
                          : KyboColors.background(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      allDone ? Icons.celebration_rounded : Icons.stars_rounded,
                      size: 24,
                      color: allDone
                          ? KyboColors.primary
                          : KyboColors.textMuted(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allDone ? 'Tutte completate!' : 'Completa tutte le sfide',
                          style: TextStyle(
                            color: KyboColors.textPrimary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          allDone
                              ? 'Hai guadagnato il bonus XP!'
                              : '+${XpRewards.allChallengesBonus} XP bonus',
                          style: TextStyle(
                            color: allDone
                                ? KyboColors.primary
                                : KyboColors.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (allDone)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: KyboColors.primary,
                      size: 28,
                    ),
                ],
              ),
            ),

          // Challenge streak
          if (challengeSvc.challengeStreak > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                borderRadius: KyboBorderRadius.medium,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF6B35),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${challengeSvc.challengeStreak} giorni di sfide consecutive!',
                    style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  TAB 3: XP
// ═══════════════════════════════════════════════

class _XpTab extends StatelessWidget {
  const _XpTab();

  @override
  Widget build(BuildContext context) {
    final xpSvc = context.watch<XpService>();
    final level = xpSvc.currentLevel;
    final entries = xpSvc.recentEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── XP Ring Card ─────────────────────
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: KyboColors.surface(context),
              borderRadius: KyboBorderRadius.large,
              border: Border.all(color: KyboColors.border(context)),
            ),
            child: Column(
              children: [
                // Circular progress
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: xpSvc.progressToNextLevel,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: KyboColors.background(context),
                          valueColor: AlwaysStoppedAnimation<Color>(KyboColors.primary),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            level.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                          Text(
                            'Lv. ${xpSvc.levelNumber}',
                            style: TextStyle(
                              color: KyboColors.textPrimary(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  level.name,
                  style: TextStyle(
                    color: KyboColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${xpSvc.totalXp} XP totali',
                  style: TextStyle(
                    color: KyboColors.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
                if (xpSvc.xpForNextLevel > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${xpSvc.xpForNextLevel} XP per il prossimo livello',
                    style: TextStyle(
                      color: KyboColors.textMuted(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Today Summary ────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  KyboColors.primary.withValues(alpha: 0.08),
                  KyboColors.primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: KyboBorderRadius.large,
              border: Border.all(
                color: KyboColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: KyboColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: KyboColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'XP di Oggi',
                        style: TextStyle(
                          color: KyboColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '+${xpSvc.todayXp} XP',
                        style: TextStyle(
                          color: KyboColors.textPrimary(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Recent Activity ──────────────────
          if (entries.isNotEmpty) ...[
            Text(
              'Attività Recente',
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            ...entries.take(15).map((entry) => _XpEntryRow(entry: entry)),
          ] else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: KyboColors.surface(context),
                borderRadius: KyboBorderRadius.large,
                border: Border.all(color: KyboColors.border(context)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 48,
                    color: KyboColors.textMuted(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nessuna attività XP ancora oggi.\nCompleta pasti e sfide per guadagnare XP!',
                    style: TextStyle(
                      color: KyboColors.textSecondary(context),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  COMPONENTS
// ═══════════════════════════════════════════════

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = badge.isUnlocked;
    final svc = context.read<BadgeService>();
    final hasProgress = badge.counterKey != null && !isUnlocked;
    final progress = svc.getProgress(badge);

    return GestureDetector(
      onTap: () => showBadgeDetailSheet(context, badge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KyboColors.surface(context),
          borderRadius: KyboBorderRadius.large,
          border: Border.all(
            color: isUnlocked
                ? (badge.color ?? KyboColors.primary).withValues(alpha: 0.5)
                : KyboColors.border(context),
            width: isUnlocked ? 2 : 1,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: (badge.color ?? KyboColors.primary).withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tier indicator
            if (badge.tier != null && isUnlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  badge.tierEmoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),

            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? (badge.color ?? KyboColors.primary).withValues(alpha: 0.1)
                    : KyboColors.background(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                badge.isSecret && !isUnlocked ? Icons.help_outline_rounded : badge.icon,
                size: 30,
                color: isUnlocked
                    ? (badge.color ?? KyboColors.primary)
                    : KyboColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              isUnlocked || !badge.isSecret ? badge.title : '???',
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

            // Description / hint
            Text(
              isUnlocked
                  ? badge.description
                  : badge.isSecret
                      ? '???'
                      : badge.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: KyboColors.textSecondary(context),
              ),
            ),

            // Progress bar
            if (hasProgress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: KyboBorderRadius.pill,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: KyboColors.background(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    badge.color ?? KyboColors.primary,
                  ),
                ),
              ),
            ],

            // Unlock date
            if (isUnlocked && badge.unlockedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy').format(badge.unlockedAt!),
                style: TextStyle(
                  fontSize: 10,
                  color: (badge.color ?? KyboColors.primary).withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // Lock icon
            if (!isUnlocked && !hasProgress) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.lock_rounded,
                size: 14,
                color: KyboColors.textMuted(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final isDone = challenge.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.large,
        border: Border.all(
          color: isDone
              ? KyboColors.primary.withValues(alpha: 0.3)
              : KyboColors.border(context),
          width: isDone ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDone
                  ? KyboColors.primary.withValues(alpha: 0.1)
                  : KyboColors.background(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              challenge.icon,
              size: 22,
              color: isDone
                  ? KyboColors.primary
                  : KyboColors.textMuted(context),
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: TextStyle(
                    color: KyboColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: KyboColors.textMuted(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.description,
                  style: TextStyle(
                    color: KyboColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // XP reward / check
          if (isDone)
            const Icon(
              Icons.check_circle_rounded,
              color: KyboColors.primary,
              size: 28,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                borderRadius: KyboBorderRadius.pill,
              ),
              child: Text(
                '+${challenge.xpReward}',
                style: const TextStyle(
                  color: Color(0xFFD4A200),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _XpEntryRow extends StatelessWidget {
  final XpEntry entry;
  const _XpEntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: KyboBorderRadius.medium,
        border: Border.all(color: KyboColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: KyboColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              XpService.reasonLabel(entry.reason),
              style: TextStyle(
                color: KyboColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '+${entry.amount} XP',
            style: const TextStyle(
              color: KyboColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('HH:mm').format(entry.timestamp),
            style: TextStyle(
              color: KyboColors.textMuted(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
