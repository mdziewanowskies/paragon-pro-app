import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/services/haptics.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/family_data_provider.dart';
import '../../data/family_repository.dart';

/// Admin-only list of pending / expired invitations with a single
/// 'Anuluj' action per row. Mirrors the spec section 3.5.
class FamilyPendingInvitations extends ConsumerStatefulWidget {
  final String familyId;
  const FamilyPendingInvitations({super.key, required this.familyId});

  @override
  ConsumerState<FamilyPendingInvitations> createState() =>
      _FamilyPendingInvitationsState();
}

class _FamilyPendingInvitationsState
    extends ConsumerState<FamilyPendingInvitations> {
  static bool _localeRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!_localeRegistered) {
      timeago.setLocaleMessages('pl', timeago.PlMessages());
      _localeRegistered = true;
    }
  }

  Future<void> _cancel(String id) async {
    Haptics.medium();
    try {
      await FamilyRepository.instance.cancelInvitation(id);
      ref.invalidate(familyPendingInvitesProvider(widget.familyId));
      Haptics.success();
      if (mounted) {
        AppSnack.show(
          context,
          'Zaproszenie anulowane',
          kind: SnackKind.info,
        );
      }
    } catch (_) {
      Haptics.error();
      if (mounted) {
        AppSnack.show(
          context,
          'Nie udało się anulować zaproszenia',
          kind: SnackKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncInvites =
        ref.watch(familyPendingInvitesProvider(widget.familyId));
    return asyncInvites.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Oczekujące zaproszenia (${rows.length})',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final inv in rows) _row(context, inv),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> inv) {
    final theme = Theme.of(context);
    final email = (inv['invited_email'] as String?) ?? '';
    final status = (inv['status'] as String?) ?? 'pending';
    final expiresAt =
        DateTime.tryParse(inv['expires_at'] as String? ?? '');
    final isExpired = status == 'expired' ||
        (expiresAt != null && expiresAt.isBefore(DateTime.now()));

    final ttl = expiresAt != null
        ? expiresAt.difference(DateTime.now())
        : Duration.zero;
    final ttlLabel = isExpired
        ? 'Wygasło'
        : ttl.inDays >= 1
            ? 'Wygasa za ${ttl.inDays} dni'
            : 'Wygasa za ${ttl.inHours} godz.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isExpired
                ? Icons.hourglass_empty_rounded
                : Icons.schedule_rounded,
            size: 16,
            color: isExpired ? Colors.grey : Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ttlLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _cancel(inv['id'] as String),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
  }
}
