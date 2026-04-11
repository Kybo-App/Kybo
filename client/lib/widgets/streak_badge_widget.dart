// Widget compatto per home screen: mostra streak, XP del giorno e sfide completate.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';
import '../services/xp_service.dart';
import '../services/challenge_service.dart';
import '../screens/badges_screen.dart';
import 'design_system.dart';

class StreakBadgeWidget extends StatelessWidget {
  const StreakBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final badgeSvc = context.watch<BadgeService>();
    final xpSvc = context.watch<XpService>();
    final challengeSvc = context.watch<ChallengeService>();

    final streak = badgeSvc.currentStreak;
    final todayXp = xpSvc.todayXp;
    final challengesDone = challengeSvc.completedCount;
    final challengesTotal = challengeSvc.totalCount;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BadgesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: KyboColors.surface(context),
          borderRadius: KyboBorderRadius.medium,
          border: Border.all(color: KyboColors.border(context)),
        ),
        child: Row(
          children: [
            // Streak flame
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: streak > 0
                    ? const Color(0xFFFF6B35).withValues(alpha: 0.12)
                    : KyboColors.background(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: streak > 0
                    ? const Color(0xFFFF6B35)
                    : KyboColors.textMuted(context),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$streak',
              style: TextStyle(
                color: streak > 0
                    ? KyboColors.textPrimary(context)
                    : KyboColors.textMuted(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),

            const SizedBox(width: 16),

            // Divider
            Container(
              width: 1,
              height: 24,
              color: KyboColors.border(context),
            ),

            const SizedBox(width: 16),

            // Today's XP
            Icon(
              Icons.star_rounded,
              size: 18,
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(width: 4),
            Text(
              '+$todayXp XP',
              style: TextStyle(
                color: KyboColors.textSecondary(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),

            const Spacer(),

            // Daily challenges progress
            if (challengesTotal > 0) ...[
              ..._buildChallengeIndicators(challengesDone, challengesTotal, context),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: KyboColors.textMuted(context),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChallengeIndicators(int done, int total, BuildContext context) {
    return List.generate(total, (i) {
      final isCompleted = i < done;
      return Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isCompleted
                ? KyboColors.primary
                : KyboColors.textMuted(context).withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }
}
