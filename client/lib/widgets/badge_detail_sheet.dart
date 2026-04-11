// Bottom sheet con dettagli badge: icona grande, tier, descrizione, data sblocco e progresso.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';
import 'design_system.dart';
import 'achievement_card_generator.dart';

void showBadgeDetailSheet(BuildContext context, BadgeModel badge) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BadgeDetailSheet(badge: badge),
  );
}

class _BadgeDetailSheet extends StatelessWidget {
  final BadgeModel badge;
  const _BadgeDetailSheet({required this.badge});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BadgeService>();
    final isUnlocked = badge.isUnlocked;
    final progress = svc.getProgress(badge);
    final counterValue = svc.getCounterValue(badge.counterKey);
    final hasProgress = badge.counterKey != null && !isUnlocked;

    return Container(
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KyboColors.textMuted(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Badge icon grande
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? (badge.color ?? KyboColors.primary).withValues(alpha: 0.12)
                      : KyboColors.background(context),
                  shape: BoxShape.circle,
                  border: isUnlocked
                      ? Border.all(
                          color: (badge.color ?? KyboColors.primary).withValues(alpha: 0.3),
                          width: 3,
                        )
                      : null,
                ),
                child: Icon(
                  badge.icon,
                  size: 44,
                  color: isUnlocked
                      ? (badge.color ?? KyboColors.primary)
                      : KyboColors.textMuted(context),
                ),
              ),

              const SizedBox(height: 16),

              // Tier indicator
              if (badge.tier != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: badge.tierColor.withValues(alpha: 0.12),
                      borderRadius: KyboBorderRadius.pill,
                      border: Border.all(
                        color: badge.tierColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${badge.tierEmoji}  ${badge.tier!.name.toUpperCase()}',
                      style: TextStyle(
                        color: badge.tierColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

              // Title
              Text(
                isUnlocked || !badge.isSecret ? badge.title : '???',
                style: TextStyle(
                  color: KyboColors.textPrimary(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                isUnlocked || !badge.isSecret ? badge.description : 'Questo badge è un segreto! Continua a usare l\'app per scoprirlo.',
                style: TextStyle(
                  color: KyboColors.textSecondary(context),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Progress bar per badge progressivi
              if (hasProgress) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progresso',
                      style: TextStyle(
                        color: KyboColors.textSecondary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$counterValue / ${badge.requiredCount}',
                      style: TextStyle(
                        color: KyboColors.textPrimary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: KyboBorderRadius.pill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: KyboColors.background(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      badge.color ?? KyboColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Unlock date
              if (isUnlocked && badge.unlockedAt != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: KyboColors.background(context),
                    borderRadius: KyboBorderRadius.medium,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: KyboColors.textSecondary(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sbloccato il ${DateFormat('dd MMMM yyyy', 'it').format(badge.unlockedAt!)}',
                        style: TextStyle(
                          color: KyboColors.textSecondary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Locked indicator
              if (!isUnlocked) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: KyboColors.background(context),
                    borderRadius: KyboBorderRadius.medium,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: KyboColors.textMuted(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Non ancora sbloccato',
                        style: TextStyle(
                          color: KyboColors.textMuted(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Share button (solo per badge sbloccati)
              if (isUnlocked) ...[
                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Condividi',
                    icon: Icons.share_rounded,
                    onPressed: () {
                      Navigator.pop(context);
                      shareAchievementCard(context, badge);
                    },
                    backgroundColor: KyboColors.primary,
                    textColor: Colors.white,
                    height: 48,
                    expanded: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
