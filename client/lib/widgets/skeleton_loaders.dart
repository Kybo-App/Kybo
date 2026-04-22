// Skeleton loaders con shimmer per liste in caricamento. Usati al posto
// di CircularProgressIndicator per ridurre la percezione di attesa.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'design_system.dart';

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder per una ListView di card (stile dieta/workout history).
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white12 : Colors.grey.shade300;
    final highlight = isDark ? Colors.white24 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: KyboColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _ShimmerBox(width: 40, height: 40, radius: 20),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: double.infinity, height: 14),
                      SizedBox(height: 8),
                      _ShimmerBox(width: 140, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
