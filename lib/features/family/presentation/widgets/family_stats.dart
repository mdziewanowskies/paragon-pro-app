import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';

class FamilyStats extends ConsumerWidget {
  final String familyId;

  const FamilyStats({super.key, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Statystyki rodziny',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Łączne wydatki',
                        value: Formatters.formatCurrency(
                            stats['total'] as double? ?? 0),
                      ),
                    ),
                    Expanded(
                      child: _StatTile(
                        label: 'Paragony',
                        value: '${stats['count'] ?? 0}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Top kategoria',
                        value: stats['topCategory'] as String? ?? '-',
                      ),
                    ),
                    Expanded(
                      child: _StatTile(
                        label: 'Średni paragon',
                        value: Formatters.formatCurrency(
                            stats['avg'] as double? ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadStats() async {
    try {
      final data = await SupabaseService.client
          .from('receipts')
          .select('amount, category')
          .eq('family_id', familyId)
          .eq('shared_with_family', true);

      final list = data as List;
      if (list.isEmpty) {
        return {'total': 0.0, 'count': 0, 'avg': 0.0, 'topCategory': '-'};
      }

      double total = 0;
      Map<String, int> catCount = {};
      for (final r in list) {
        total += (r['amount'] as num?)?.toDouble() ?? 0;
        final cat = r['category'] as String? ?? 'Inne';
        catCount[cat] = (catCount[cat] ?? 0) + 1;
      }

      final topCategory = catCount.entries.reduce((a, b) =>
          a.value >= b.value ? a : b).key;

      return {
        'total': total,
        'count': list.length,
        'avg': list.isNotEmpty ? total / list.length : 0.0,
        'topCategory': topCategory,
      };
    } catch (_) {
      return {'total': 0.0, 'count': 0, 'avg': 0.0, 'topCategory': '-'};
    }
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
