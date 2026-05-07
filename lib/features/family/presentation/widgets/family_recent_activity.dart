import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/utils/formatters.dart';
import '../../data/family_constants.dart';
import '../../data/family_data_provider.dart';

/// Latest receipts shared with the family — '<Name> dodał paragon
/// w <Sklep>', amount, relative time. Backed by
/// `get_family_recent_receipts` RPC.
class FamilyRecentActivity extends ConsumerStatefulWidget {
  final String familyId;
  const FamilyRecentActivity({super.key, required this.familyId});

  @override
  ConsumerState<FamilyRecentActivity> createState() =>
      _FamilyRecentActivityState();
}

class _FamilyRecentActivityState
    extends ConsumerState<FamilyRecentActivity> {
  static bool _localeRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!_localeRegistered) {
      timeago.setLocaleMessages('pl', timeago.PlMessages());
      _localeRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncReceipts =
        ref.watch(familyRecentReceiptsProvider(widget.familyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: asyncReceipts.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) =>
              const Text('Nie udało się wczytać aktywności'),
          data: (rows) => _buildContent(context, rows),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Ostatnia aktywność',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Text(
            'Brak udostępnionych paragonów. Pierwszy zaznaczony „Udostępnij rodzinie" pojawi się tutaj.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface
                  .withValues(alpha: 0.6),
            ),
          )
        else
          for (final r in rows) _row(context, r),
      ],
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> r) {
    final theme = Theme.of(context);
    final name = FamilyDisplay.displayName(
      firstName: r['first_name'] as String?,
      lastName: r['last_name'] as String?,
      username: r['username'] as String?,
    );
    final initials = FamilyDisplay.initials(
      firstName: r['first_name'] as String?,
      lastName: r['last_name'] as String?,
      username: r['username'] as String?,
    );
    final merchant =
        (r['merchant_name'] as String?)?.trim().isNotEmpty == true
            ? r['merchant_name'] as String
            : 'Nieznany sklep';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final uploadedAt =
        DateTime.tryParse(r['uploaded_at'] as String? ?? '') ??
            DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.18),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' dodał paragon w '),
                      TextSpan(
                        text: merchant,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeago.format(uploadedAt, locale: 'pl'),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.formatCurrency(amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
