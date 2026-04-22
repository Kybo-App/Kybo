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

/// Placeholder per la lista utenti in user_management_view.
class SkeletonUserList extends StatelessWidget {
  const SkeletonUserList({super.key, this.itemCount = 8});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = KyboColors.isDark;
    final base = isDark ? Colors.white12 : Colors.grey.shade300;
    final highlight = isDark ? Colors.white24 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, _) => Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.medium),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _ShimmerBox(width: 44, height: 44, radius: 22),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 180, height: 14),
                      SizedBox(height: 8),
                      _ShimmerBox(width: 120, height: 12),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                _ShimmerBox(width: 60, height: 24, radius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
