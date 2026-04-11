// Genera una card immagine condivisibile per i badge sbloccati.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/badge_model.dart';
import 'design_system.dart';

/// Condivide un badge come immagine generata.
Future<void> shareAchievementCard(BuildContext context, BadgeModel badge) async {
  try {
    final image = await _generateBadgeImage(context, badge);
    if (image == null) return;

    // Salva in file temp
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/kybo_badge_${badge.id}.png');
    await file.writeAsBytes(image);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '🏆 Ho sbloccato il badge "${badge.title}" su Kybo! ${badge.tierEmoji}',
    );
  } catch (e) {
    debugPrint("Error sharing badge: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Errore nella condivisione'),
          backgroundColor: KyboColors.error,
        ),
      );
    }
  }
}

Future<Directory> _getTempDir() async {
  return Directory.systemTemp;
}

/// Genera un'immagine PNG della card del badge.
Future<Uint8List?> _generateBadgeImage(BuildContext context, BadgeModel badge) async {
  final key = GlobalKey();

  final overlay = OverlayEntry(
    builder: (ctx) => Positioned(
      left: -1000,
      top: -1000,
      child: RepaintBoundary(
        key: key,
        child: _AchievementCardWidget(badge: badge),
      ),
    ),
  );

  Overlay.of(context).insert(overlay);

  // Attendere il rendering
  await Future.delayed(const Duration(milliseconds: 200));

  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } finally {
    overlay.remove();
  }
}

class _AchievementCardWidget extends StatelessWidget {
  final BadgeModel badge;
  const _AchievementCardWidget({required this.badge});

  @override
  Widget build(BuildContext context) {
    final gradientColors = badge.tier != null
        ? [badge.tierColor, badge.tierColor.withValues(alpha: 0.7)]
        : [KyboColors.primary, KyboColors.primaryDark];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                badge.icon,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Tier
            if (badge.tier != null)
              Text(
                badge.tierEmoji,
                style: const TextStyle(fontSize: 28),
              ),

            // Title
            Text(
              badge.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              badge.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Branding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Kybo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
