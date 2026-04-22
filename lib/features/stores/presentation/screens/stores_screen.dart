import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/polish_plurals.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../widgets/store_tile.dart';
import 'store_detail_screen.dart';

final storeStatsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return [];

  final data = await SupabaseService.rpc(
    'get_user_store_stats',
    params: {'_user_id': userId},
  );

  return (data as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storeStatsProvider);

    return stores.when(
      loading: () => const LoadingSpinner(message: 'Ładowanie sklepów...'),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.store_rounded,
            title: 'Brak sklepów',
            subtitle:
                'Dodaj paragony, a sklepy pojawią się automatycznie',
          );
        }

        final totalSpent = list.fold<double>(
            0, (s, e) => s + ((e['total_spent'] as num?)?.toDouble() ?? 0));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(storeStatsProvider),
          child: CustomScrollView(
            slivers: [
              // Summary header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.store_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text(
                        PolishPlurals.stores(list.length),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.trending_up_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        'Łącznie: ${Formatters.formatCurrency(totalSpent)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final store = list[index];
                      final storeId = store['store_id'] as String;
                      final storeName =
                          store['store_name'] as String? ?? 'Sklep';
                      final receiptCount =
                          (store['receipt_count'] as num?)?.toInt() ?? 0;
                      final totalSpent =
                          (store['total_spent'] as num?)?.toDouble() ?? 0;

                      return StoreTile(
                        storeName: storeName,
                        receiptCount: receiptCount,
                        totalSpent: totalSpent,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoreDetailScreen(
                                storeId: storeId,
                                storeName: storeName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: list.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}
