import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../receipts/data/receipt_repository.dart';

final monthlyReportProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return {};

  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 1);
  final lastMonth = DateTime(now.year, now.month - 1, 1);

  final repo = ref.read(receiptRepositoryProvider);

  final thisMonthReceipts = await repo.getReceipts(
    userId: userId,
    limit: 10000,
    dateFrom: thisMonth,
    dateTo: now,
    filterType: ReceiptFilterType.receiptsOnly,
  );

  final lastMonthReceipts = await repo.getReceipts(
    userId: userId,
    limit: 10000,
    dateFrom: lastMonth,
    dateTo: thisMonth.subtract(const Duration(days: 1)),
    filterType: ReceiptFilterType.receiptsOnly,
  );

  final thisTotal = thisMonthReceipts.fold<double>(
      0, (sum, r) => sum + (r.amount ?? 0));
  final lastTotal = lastMonthReceipts.fold<double>(
      0, (sum, r) => sum + (r.amount ?? 0));
  final change = lastTotal > 0 ? ((thisTotal - lastTotal) / lastTotal * 100) : 0.0;

  // Category breakdown
  final Map<String, double> categories = {};
  for (final r in thisMonthReceipts) {
    final cat = r.category ?? 'Inne';
    categories[cat] = (categories[cat] ?? 0) + (r.amount ?? 0);
  }

  return {
    'thisMonthTotal': thisTotal,
    'lastMonthTotal': lastTotal,
    'change': change,
    'receiptCount': thisMonthReceipts.length,
    'categories': categories,
  };
});

class MonthlyReport extends ConsumerWidget {
  const MonthlyReport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(monthlyReportProvider);

    return report.when(
      loading: () => const SizedBox(height: 200, child: LoadingSpinner()),
      error: (e, _) => Text('Błąd: $e'),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        final change = (data['change'] as num?)?.toDouble() ?? 0.0;
        final isUp = change > 0;
        final categories =
            data['categories'] as Map<String, double>? ?? {};

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Podsumowanie tego miesiąca',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // Main stats
                Row(
                  children: [
                    Expanded(
                      child: _ReportStat(
                        label: 'Ten miesiąc',
                        value: Formatters.formatCurrency(
                            (data['thisMonthTotal'] as num?)?.toDouble() ?? 0),
                      ),
                    ),
                    Expanded(
                      child: _ReportStat(
                        label: 'Poprzedni miesiąc',
                        value: Formatters.formatCurrency(
                            (data['lastMonthTotal'] as num?)?.toDouble() ?? 0),
                      ),
                    ),
                    Expanded(
                      child: _ReportStat(
                        label: 'Zmiana',
                        value:
                            '${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
                        valueColor: isUp ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Paragony w tym miesiącu: ${data['receiptCount']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Wydatki wg kategorii',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...categories.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text(
                              Formatters.formatCurrency(e.value),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReportStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
