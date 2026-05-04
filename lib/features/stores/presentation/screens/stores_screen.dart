import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/polish_plurals.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../data/store_logo_service.dart';
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
            hint: 'Każdy zeskanowany paragon dodaje swój sklep do tej '
                'listy z liczbą wizyt i wydaną kwotą.',
          );
        }

        final totalSpent = list.fold<double>(
            0, (s, e) => s + ((e['total_spent'] as num?)?.toDouble() ?? 0));

        return RefreshIndicator(
          onRefresh: () async {
            Haptics.medium();
            ref.invalidate(storeStatsProvider);
            await Future<void>.delayed(const Duration(milliseconds: 350));
            Haptics.success();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length + 1,
            itemBuilder: (context, index) {
              // Header
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                );
              }

              final store = list[index - 1];
              final storeId = store['store_id'] as String;
              final storeName =
                  store['store_name'] as String? ?? 'Sklep';
              final receiptCount =
                  (store['receipt_count'] as num?)?.toInt() ?? 0;
              final spent =
                  (store['total_spent'] as num?)?.toDouble() ?? 0;
              final lastPurchase = store['last_purchase'] as String?;
              final faviconUrl =
                  StoreLogoService.getFaviconUrl(storeName);
              final initials =
                  StoreLogoService.getInitials(storeName);
              final color = StoreLogoService.getColor(storeName);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StoreDetailScreen(
                          storeId: storeId,
                          storeName: storeName,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: faviconUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: faviconUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) =>
                                      _InitialsAvatar(
                                          initials: initials,
                                          color: color),
                                )
                              : _InitialsAvatar(
                                  initials: initials, color: color),
                        ),
                        const SizedBox(width: 14),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                storeName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      PolishPlurals.receipts(
                                          receiptCount),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  if (lastPurchase != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ostatni: ${Formatters.formatDate(DateTime.tryParse(lastPurchase))}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Amount
                        Text(
                          Formatters.formatCurrency(spent),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color:
                                Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  const _InitialsAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
