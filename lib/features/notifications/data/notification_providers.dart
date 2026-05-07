import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/notification_models.dart';
import 'notification_repository.dart';

/// Polls notifications every 60s.
final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) async* {
  final repo = NotificationRepository.instance;
  yield await repo.fetchNotifications();
  await for (final _ in Stream.periodic(const Duration(seconds: 60))) {
    yield await repo.fetchNotifications();
  }
});

/// Polls pending family invitations every 30s.
final notificationInvitationsProvider =
    StreamProvider.autoDispose<List<FamilyInvitation>>((ref) async* {
  final repo = NotificationRepository.instance;
  yield await repo.fetchPendingInvitations();
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield await repo.fetchPendingInvitations();
  }
});

/// Total badge count = unread notifications + pending invitations.
final notificationBadgeProvider = Provider.autoDispose<int>((ref) {
  final notifs = ref.watch(notificationsProvider).valueOrNull ?? const [];
  final invites =
      ref.watch(notificationInvitationsProvider).valueOrNull ?? const [];
  final unread = notifs.where((n) => !n.isRead).length;
  return unread + invites.length;
});
