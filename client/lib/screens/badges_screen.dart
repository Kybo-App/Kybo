import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';
import '../models/badge_model.dart';
import '../widgets/design_system.dart';
import 'package:intl/intl.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badgeService = context.watch<BadgeService>();
    final badges = badgeService.badges;
    
    // Simple stats
    final unlockedCount = badges.where((b) => b.isUnlocked).length;
    final totalCount = badges.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        title: const Text("Traguardi"),
        backgroundColor: KyboColors.surface(context),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             // Progress Card
             Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: KyboColors.primary,
                 borderRadius: KyboBorderRadius.large,
                 boxShadow: [
                   BoxShadow(
                     color: KyboColors.primary.withValues(alpha: 0.3),
                     blurRadius: 16,
                     offset: const Offset(0, 8),
                   )
                 ]
               ),
               child: Row(
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text(
                           "Livello Novizio",
                           style: TextStyle(
                             color: Colors.white70,
                             fontWeight: FontWeight.bold,
                             fontSize: 14,
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           "$unlockedCount / $totalCount Badges",
                           style: const TextStyle(
                             color: Colors.white,
                             fontWeight: FontWeight.bold,
                             fontSize: 28,
                           ),
                         ),
                       ],
                     ),
                   ),
                   Container(
                     width: 60,
                     height: 60,
                     decoration: BoxDecoration(
                       color: Colors.white.withValues(alpha: 0.2),
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30),
                   ),
                 ],
               ),
             ),
             
             const SizedBox(height: 30),
             
             // Grid
             GridView.builder(
               physics: const NeverScrollableScrollPhysics(),
               shrinkWrap: true,
               itemCount: badges.length,
               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: 2,
                 crossAxisSpacing: 16,
                 mainAxisSpacing: 16,
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
        borderRadius: KyboBorderRadius.medium,
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
              )
            ] 
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
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
              size: 32,
              color: isUnlocked 
                  ? KyboColors.primary 
                  : KyboColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isUnlocked 
                  ? KyboColors.textPrimary(context) 
                  : KyboColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          
          Text(
            badge.description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: KyboColors.textSecondary(context),
            ),
          ),
          
          if (isUnlocked && badge.unlockedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(badge.unlockedAt!),
              style: TextStyle(
                fontSize: 10,
                color: KyboColors.textMuted(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
