import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shared shimmer base. Wraps any child with the standard ParagonPro
/// dark/light shimmer gradient.
class _Shimmer extends StatelessWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

class _Box extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _Box({this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Skeleton placeholder matching the dashboard StatCard footprint —
/// drop into `loading:` branches for fluid loading states.
class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Box(width: 80, height: 12),
            _Box(width: 60, height: 22),
            _Box(width: 100, height: 10),
          ],
        ),
      ),
    );
  }
}

/// 2x2 grid of stat skeletons matching DashboardStats geometry.
class DashboardStatsSkeleton extends StatelessWidget {
  const DashboardStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: const [
        StatCardSkeleton(),
        StatCardSkeleton(),
        StatCardSkeleton(),
        StatCardSkeleton(),
      ],
    );
  }
}

/// Skeleton row matching a receipt card's silhouette.
class ReceiptCardSkeleton extends StatelessWidget {
  const ReceiptCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _Box(width: 56, height: 56, radius: 12),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Box(width: 160, height: 14),
                  SizedBox(height: 8),
                  _Box(width: 100, height: 10),
                  SizedBox(height: 6),
                  _Box(width: 80, height: 10),
                ],
              ),
            ),
            const _Box(width: 60, height: 18),
          ],
        ),
      ),
    );
  }
}

/// Vertical list of [ReceiptCardSkeleton]s. Use as the `loading` state
/// for any receipt list view.
class ReceiptListSkeleton extends StatelessWidget {
  final int count;
  const ReceiptListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) => const ReceiptCardSkeleton(),
    );
  }
}
