import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/models/notification_models.dart';
import '../../data/notification_providers.dart';
import '../../data/notification_repository.dart';

/// Bottom sheet listing pending family invitations + the latest 30
/// notifications. Tapping a notification marks it as read; family
/// invitations get accept / reject buttons.
class NotificationsSheet extends ConsumerStatefulWidget {
  const NotificationsSheet({super.key});

  @override
  ConsumerState<NotificationsSheet> createState() =>
      _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
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
    final notifs = ref.watch(notificationsProvider);
    final invites = ref.watch(notificationInvitationsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            _Header(
              onMarkAllRead: () async {
                Haptics.tap();
                await NotificationRepository.instance.markAllRead();
                ref.invalidate(notificationsProvider);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: _Body(
                scrollController: scrollController,
                notifs: notifs.valueOrNull ?? const [],
                invites: invites.valueOrNull ?? const [],
                isLoading: notifs.isLoading || invites.isLoading,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  final VoidCallback onMarkAllRead;
  const _Header({required this.onMarkAllRead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread =
        (ref.watch(notificationsProvider).valueOrNull ?? const [])
            .any((n) => !n.isRead);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.notifications_rounded, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Powiadomienia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          if (hasUnread)
            TextButton.icon(
              onPressed: onMarkAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Oznacz wszystkie'),
            ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final ScrollController scrollController;
  final List<AppNotification> notifs;
  final List<FamilyInvitation> invites;
  final bool isLoading;

  const _Body({
    required this.scrollController,
    required this.notifs,
    required this.invites,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading && notifs.isEmpty && invites.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (notifs.isEmpty && invites.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_rounded,
        title: 'Brak nowych powiadomień',
        subtitle:
            'Tu pojawią się przypomnienia o gwarancjach, osiągnięcia i wiadomości od rodziny.',
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        for (final inv in invites)
          _InvitationTile(
            invitation: inv,
            onAccept: () => _accept(context, ref, inv),
            onReject: () => _reject(context, ref, inv),
          ),
        for (final n in notifs)
          _NotificationTile(
            notification: n,
            onTap: () => _markRead(ref, n),
          ),
      ],
    );
  }

  Future<void> _markRead(WidgetRef ref, AppNotification n) async {
    if (n.isRead) return;
    await NotificationRepository.instance.markRead(n.id);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    FamilyInvitation inv,
  ) async {
    Haptics.medium();
    final ok = await NotificationRepository.instance.acceptInvitation(
      invitationId: inv.id,
      familyId: inv.familyId,
    );
    if (!context.mounted) return;
    if (ok) {
      Haptics.success();
      AnalyticsService.logEvent('family_invitation_accept');
      ref.invalidate(notificationInvitationsProvider);
      // Backend may have just bumped tier to family_lite — refresh.
      try {
        await ref.read(subscriptionProvider.notifier).refresh();
      } catch (_) {}
      if (context.mounted) {
        AppSnack.show(
          context,
          'Zaproszenie przyjęte. Witamy w rodzinie!',
          kind: SnackKind.success,
        );
      }
    } else {
      AppSnack.show(
        context,
        'Nie udało się zaakceptować zaproszenia',
        kind: SnackKind.error,
      );
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    FamilyInvitation inv,
  ) async {
    Haptics.tap();
    final ok =
        await NotificationRepository.instance.rejectInvitation(inv.id);
    if (!context.mounted) return;
    if (ok) {
      AnalyticsService.logEvent('family_invitation_reject');
      ref.invalidate(notificationInvitationsProvider);
      AppSnack.show(
        context,
        'Zaproszenie odrzucone',
        kind: SnackKind.info,
      );
    } else {
      AppSnack.show(
        context,
        'Nie udało się odrzucić zaproszenia',
        kind: SnackKind.error,
      );
    }
  }
}

// ─── Notification tile ────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relative = timeago.format(notification.createdAt, locale: 'pl');
    return Material(
      color: notification.isRead
          ? Colors.transparent
          : theme.colorScheme.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Icon(kind: notification.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body!,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      relative,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final FamilyInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InvitationTile({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relative = timeago.format(invitation.createdAt, locale: 'pl');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Icon(
                  kind: NotificationKind.system, overrideGlyph: '💌'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zaproszenie do rodziny',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invitation.familyName != null
                          ? 'Dołącz do rodziny "${invitation.familyName}" i razem oszczędzajcie.'
                          : 'Ktoś zaprosił Cię do rodziny ParagonPro.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      relative,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Odrzuć'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Akceptuj'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Emoji-based icon — keeps the kind→glyph mapping in one place.
class _Icon extends StatelessWidget {
  final NotificationKind kind;
  final String? overrideGlyph;
  const _Icon({required this.kind, this.overrideGlyph});

  String _glyph() {
    if (overrideGlyph != null) return overrideGlyph!;
    switch (kind) {
      case NotificationKind.warrantyExpiring:
        return '🛡️';
      case NotificationKind.achievementUnlocked:
        return '🏆';
      case NotificationKind.familyReceipt:
        return '👨‍👩‍👧‍👦';
      case NotificationKind.familyInvitation:
        return '✉️';
      case NotificationKind.removedFromFamily:
        return '👋';
      case NotificationKind.monthlyReport:
        return '📊';
      case NotificationKind.ksefSynced:
        return '📄';
      case NotificationKind.ksefDigest:
        return '📨';
      case NotificationKind.subscriptionExpiring:
        return '⏰';
      case NotificationKind.subscriptionRenewed:
        return '✅';
      case NotificationKind.system:
        return 'ℹ️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(_glyph(), style: const TextStyle(fontSize: 18)),
    );
  }
}
