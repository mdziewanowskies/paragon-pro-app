import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/family_constants.dart';
import '../../data/family_data_provider.dart';
import '../../data/family_member_models.dart';
import '../../data/family_stats_provider.dart';

/// Donut chart of `shared_with_family` receipt totals split by user
/// + a legend with kwota / procent per member. Hides itself when
/// nobody shared anything yet.
class FamilyExpenseShareDonut extends ConsumerWidget {
  final String familyId;
  final int memberCount;

  const FamilyExpenseShareDonut({
    super.key,
    required this.familyId,
    required this.memberCount,
  });

  static const _palette = [
    Color(0xFF176B47),
    Color(0xFF1F9663),
    Color(0xFF27C17F),
    Color(0xFF4DC98E),
    Color(0xFF6DD5A8),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(
        familyStats(familyId: familyId, memberCount: memberCount));
    final asyncMembers = ref.watch(familyMembersProvider(familyId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: () {
          if (asyncStats.isLoading || asyncMembers.isLoading) {
            return const SizedBox(
              height: 180,
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (asyncStats.hasError || asyncMembers.hasError) {
            return const Text('Nie udało się wczytać udziału w wydatkach');
          }
          final stats = asyncStats.value!;
          final members = asyncMembers.value!.members;
          if (stats.total == 0 || stats.sumByUserId.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: 12),
                Text(
                  'Nikt jeszcze nie udostępnił paragonu rodzinie. Zaznacz „Udostępnij rodzinie" przy dodawaniu paragonu, żeby zacząć.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            );
          }
          return _buildContent(context, stats, members);
        }(),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.donut_small_rounded, size: 20),
        const SizedBox(width: 8),
        Text(
          'Udział w wydatkach',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    FamilyExpensesStats stats,
    List<FamilyMember> members,
  ) {
    final entries = stats.sumByUserId.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: _palette[i % _palette.length],
                    radius: 48,
                    title: '${(entries[i].value / stats.total * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++)
          _legendRow(
            context,
            color: _palette[i % _palette.length],
            label: _nameFor(members, entries[i].key),
            amount: entries[i].value,
            percent: entries[i].value / stats.total * 100,
          ),
      ],
    );
  }

  String _nameFor(List<FamilyMember> members, String userId) {
    final m = members.firstWhere(
      (x) => x.userId == userId,
      orElse: () => FamilyMember(
        memberRowId: '',
        userId: userId,
        role: 'member',
        joinedAt: DateTime.now(),
      ),
    );
    return FamilyDisplay.displayName(
      firstName: m.firstName,
      lastName: m.lastName,
      username: m.username,
    );
  }

  Widget _legendRow(
    BuildContext context, {
    required Color color,
    required String label,
    required double amount,
    required double percent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            '${Formatters.formatCurrency(amount)}  ·  ${percent.toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
