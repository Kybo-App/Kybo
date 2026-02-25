// Widget che mostra il logo Kybo dall'asset PNG con fallback a icona se il file non viene trovato.
import 'package:flutter/material.dart';

class DietLogo extends StatelessWidget {
  final double size;
  final bool isDarkBackground;

  const DietLogo({super.key, this.size = 100, this.isDarkBackground = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.spa, size: size, color: Colors.green);
      },
    );
  }
}
