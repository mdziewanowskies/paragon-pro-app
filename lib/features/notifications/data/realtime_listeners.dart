import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/supabase_service.dart';
import 'notification_providers.dart';

/// Wires Supabase Realtime channels for the current user. Replaces
/// 30s/60s pollers with push-driven invalidation, matching the web
/// app's `useRealtimeNotifications` + `useSubscription` hooks.
///
/// Channels:
/// - `notifications:{uid}` — invalidates [notificationsProvider] on
///   any new row in `notifications` for this user.
/// - `family-membership:{uid}` — invalidates
///   [notificationInvitationsProvider] and [subscriptionProvider]
///   when this user's row in `family_members` changes (added or
///   removed). Tier auto-recomputes via get_effective_tier.
///
/// Hook this once at app start (or per signed-in user) and dispose
/// on logout.
class RealtimeListeners {
  RealtimeListeners._(this._ref);
  final Ref _ref;

  final List<RealtimeChannel> _channels = [];
  StreamSubscription? _authSub;

  static RealtimeListeners attach(Ref ref) {
    final svc = RealtimeListeners._(ref);
    svc._start();
    ref.onDispose(svc.dispose);
    return svc;
  }

  void _start() {
    _bind(SupabaseService.auth.currentUser?.id);
    _authSub = SupabaseService.auth.onAuthStateChange.listen((event) {
      _unbind();
      _bind(SupabaseService.auth.currentUser?.id);
    });
  }

  void _bind(String? userId) {
    if (userId == null) return;
    final client = SupabaseService.client;

    final notifChannel = client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            _ref.invalidate(notificationsProvider);
          },
        )
        .subscribe();

    final familyChannel = client
        .channel('family-membership:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'family_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            // Tier may have flipped (joined → family_lite, removed
            // → free); refresh subscription and pending invites.
            _ref.invalidate(notificationInvitationsProvider);
            try {
              _ref.read(subscriptionProvider.notifier).refresh();
            } catch (_) {}
          },
        )
        .subscribe();

    _channels.addAll([notifChannel, familyChannel]);
    debugPrint('RealtimeListeners bound for $userId');
  }

  void _unbind() {
    for (final ch in _channels) {
      try {
        SupabaseService.client.removeChannel(ch);
      } catch (_) {}
    }
    _channels.clear();
  }

  void dispose() {
    _unbind();
    _authSub?.cancel();
    _authSub = null;
  }
}

/// Single realtime listener instance bound to provider lifecycle.
final realtimeListenersProvider = Provider<RealtimeListeners>((ref) {
  return RealtimeListeners.attach(ref);
});
