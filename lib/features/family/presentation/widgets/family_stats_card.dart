import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/family_stats_provider.dart';

/// 2x2 metric grid: total expenses, this-month-vs-last trend,
/// average per member, shared receipt count.
class FamilyStatsCard extends ConsumerWidget {
  final String familyId;
  final int memberCount;

  const FamilyStatsCard({
    super.key,
    required this.familyId,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(
        familyStats(familyId: familyId, memberCount: memberCount));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: asyncStats.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) =>
              const Text('Nie udało się wczytać statystyk rodziny'),
          data: (s) {
            final trend = s.trendPercent;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Wspólne wydatki',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _Metric(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Razem',
                      value: Formatters.formatCurrency(s.total),
                    ),
                    _Metric(
                      icon: Icons.calendar_month_rounded,
                      label: 'Ten miesiąc',
                      value: Formatters.formatCurrency(s.thisMonth),
                      trend: trend,
                    ),
                    _Metric(
                      icon: Icons.person_rounded,
                      label: 'Średnio na osobę',
                      value: Formatters.formatCurrency(s.averagePerMember),
                    ),
                    _Metric(
                      icon: Icons.receipt_long_rounded,
                      label: 'Paragony',
                      value: s.receiptCount.toString(),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? trend;

  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTrend = trend != null && trend!.abs() > 0.5;
    final trendUp = (trend ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: theme.colorScheme.primary
                      .withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasTrend)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: trendUp ? Colors.red : Colors.green,
                      ),
                      Text(
                        '${trend!.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: trendUp ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
