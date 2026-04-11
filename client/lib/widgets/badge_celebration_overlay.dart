// Overlay di celebrazione per sblocco badge con confetti, animazioni e feedback XP.
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';
import '../services/xp_service.dart';
import 'design_system.dart';

/// Mostra l'overlay di celebrazione per un badge sbloccato.
void showBadgeCelebration(BuildContext context, BadgeModel badge, {BadgeLevel? levelUp}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (ctx, anim, secondAnim) {
      return _BadgeCelebrationOverlay(
        badge: badge,
        levelUp: levelUp,
        animation: anim,
      );
    },
    transitionBuilder: (ctx, anim, secondAnim, child) {
      return FadeTransition(opacity: anim, child: child);
    },
  );
}

class _BadgeCelebrationOverlay extends StatefulWidget {
  final BadgeModel badge;
  final BadgeLevel? levelUp;
  final Animation<double> animation;

  const _BadgeCelebrationOverlay({
    required this.badge,
    this.levelUp,
    required this.animation,
  });

  @override
  State<_BadgeCelebrationOverlay> createState() => _BadgeCelebrationOverlayState();
}

class _BadgeCelebrationOverlayState extends State<_BadgeCelebrationOverlay>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _confettiController.play();
        _bounceController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLevelUp = widget.levelUp != null;
    final gradientColors = isLevelUp
        ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
        : [KyboColors.primary, KyboColors.primaryDark];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Color(0xFF2E7D32),
                Color(0xFFFFD700),
                Color(0xFF3B82F6),
                Color(0xFFEF4444),
                Color(0xFFF59E0B),
                Color(0xFF10B981),
              ],
            ),
          ),

          // Contenuto centrale
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: KyboBorderRadius.large,
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge icon con bounce
                    ScaleTransition(
                      scale: _bounceAnimation,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.badge.icon,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tier badge se presente
                    if (widget.badge.tier != null)
                      Text(
                        widget.badge.tierEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),

                    // Label
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            isLevelUp ? 'Nuovo Livello!' : 'Badge Sbloccato!',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isLevelUp
                                ? '${widget.levelUp!.emoji}  ${widget.levelUp!.name}'
                                : widget.badge.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.badge.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // XP reward
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: KyboBorderRadius.pill,
                            ),
                            child: Text(
                              '+${XpRewards.badgeUnlocked} XP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Dismiss button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: gradientColors.first,
                              shape: RoundedRectangleBorder(
                                borderRadius: KyboBorderRadius.pill,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Fantastico!',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
