import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

class FamilyExpensesStats {
  final double total;
  final double thisMonth;
  final double lastMonth;
  final int receiptCount;
  final int memberCount;
  final Map<String, double> sumByUserId;

  const FamilyExpensesStats({
    this.total = 0,
    this.thisMonth = 0,
    this.lastMonth = 0,
    this.receiptCount = 0,
    this.memberCount = 0,
    this.sumByUserId = const {},
  });

  double get averagePerMember =>
      memberCount > 0 ? total / memberCount : 0;

  /// Month-over-month delta as a percentage. Returns null when last
  /// month had zero spend (no meaningful comparison).
  double? get trendPercent {
    if (lastMonth == 0) return null;
    return ((thisMonth - lastMonth) / lastMonth) * 100;
  }
}

/// Aggregates `receipts` rows for the family-shared, non-KSeF
/// receipts. Used by both FamilyStats and the donut chart.
final familyStatsProvider = FutureProvider.autoDispose
    .family<FamilyExpensesStats, _FamilyStatsKey>((ref, key) async {
  try {
    final rows = await SupabaseService.client
        .from('receipts')
        .select('user_id, amount, purchase_date, uploaded_at')
        .eq('family_id', key.familyId)
        .eq('shared_with_family', true)
        .or('is_ksef_invoice.is.null,is_ksef_invoice.eq.false');

    final list = (rows as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    var total = 0.0;
    var thisMonth = 0.0;
    var lastMonth = 0.0;
    final sumByUser = <String, double>{};

    for (final r in list) {
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      total += amount;

      final uid = r['user_id'] as String?;
      if (uid != null) {
        sumByUser[uid] = (sumByUser[uid] ?? 0) + amount;
      }

      final dateStr =
          (r['purchase_date'] ?? r['uploaded_at']) as String?;
      final date = DateTime.tryParse(dateStr ?? '');
      if (date != null) {
        if (!date.isBefore(thisMonthStart)) {
          thisMonth += amount;
        } else if (!date.isBefore(lastMonthStart) &&
            date.isBefore(thisMonthStart)) {
          lastMonth += amount;
        }
      }
    }

    return FamilyExpensesStats(
      total: total,
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      receiptCount: list.length,
      memberCount: key.memberCount,
      sumByUserId: sumByUser,
    );
  } catch (e) {
    debugPrint('familyStatsProvider failed: $e');
    return const FamilyExpensesStats();
  }
});

class _FamilyStatsKey {
  final String familyId;
  final int memberCount;
  const _FamilyStatsKey(this.familyId, this.memberCount);

  @override
  bool operator ==(Object other) =>
      other is _FamilyStatsKey &&
      other.familyId == familyId &&
      other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(familyId, memberCount);
}

/// Public helper so widgets don't need to import the private key.
ProviderListenable<AsyncValue<FamilyExpensesStats>> familyStats({
  required String familyId,
  required int memberCount,
}) =>
    familyStatsProvider(_FamilyStatsKey(familyId, memberCount));
