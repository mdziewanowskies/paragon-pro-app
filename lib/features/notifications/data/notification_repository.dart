import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import 'models/notification_models.dart';

/// Thin Supabase wrapper for notifications + family invitations.
///
/// All methods are best-effort: any backend failure is logged and
/// surfaced as an empty list / false return so the UI never crashes
/// on a network blip.
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  Future<List<AppNotification>> fetchNotifications() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return [];
    try {
      final rows = await SupabaseService.client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List)
          .map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('fetchNotifications failed: $e');
      return const [];
    }
  }

  Future<List<FamilyInvitation>> fetchPendingInvitations() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return [];
    final email = user.email ?? '';
    final filter = email.isEmpty
        ? 'invited_user_id.eq.${user.id}'
        : 'invited_user_id.eq.${user.id},invited_email.eq.$email';
    try {
      final rows = await SupabaseService.client
          .from('family_invitations')
          .select('*, families(name)')
          .eq('status', 'pending')
          .or(filter)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => FamilyInvitation.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('fetchPendingInvitations failed: $e');
      return const [];
    }
  }

  Future<void> markRead(String id) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint('markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return;
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('markAllRead failed: $e');
    }
  }

  Future<bool> acceptInvitation({
    required String invitationId,
    required String familyId,
  }) async {
    try {
      await SupabaseService.rpc(
        'accept_family_invitation_tx',
        params: {
          '_invitation_id': invitationId,
          '_family_id': familyId,
        },
      );
      return true;
    } catch (e) {
      debugPrint('acceptInvitation failed: $e');
      return false;
    }
  }

  Future<bool> rejectInvitation(String invitationId) async {
    try {
      await SupabaseService.client
          .from('family_invitations')
          .update({'status': 'rejected'}).eq('id', invitationId);
      return true;
    } catch (e) {
      debugPrint('rejectInvitation failed: $e');
      return false;
    }
  }
}
