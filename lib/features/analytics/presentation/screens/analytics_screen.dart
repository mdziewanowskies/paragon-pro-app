import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../receipts/data/receipt_repository.dart';
import '../widgets/expense_pie_chart.dart';
import '../widgets/monthly_line_chart.dart';

final categoryExpensesProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return {};
  return await ref.read(receiptRepositoryProvider).getExpensesByCategory(userId);
});

final monthlyExpensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return [];
  return await ref.read(receiptRepositoryProvider).getMonthlyExpenses(userId);
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryExpensesProvider);
    final monthly = ref.watch(monthlyExpensesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(categoryExpensesProvider);
        ref.invalidate(monthlyExpensesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wydatki wg kategorii',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            categories.when(
              loading: () => const SizedBox(
                  height: 300, child: LoadingSpinner()),
              error: (e, _) => Text('Błąd: $e'),
              data: (data) => data.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Brak danych do wyświetlenia'),
                      ),
                    )
                  : ExpensePieChart(data: data),
            ),
            const SizedBox(height: 32),
            Text(
              'Wydatki miesięczne',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            monthly.when(
              loading: () => const SizedBox(
                  height: 300, child: LoadingSpinner()),
              error: (e, _) => Text('Błąd: $e'),
              data: (data) => data.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Brak danych do wyświetlenia'),
                      ),
                    )
                  : MonthlyLineChart(data: data),
            ),
          ],
        ),
      ),
    );
  }
}
