import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';

/// Wraps every family-related Supabase call we issue from the mobile
/// client. Mirrors the helper functions the web app uses; relies on
/// the RPCs and triggers already deployed on the backend.
class FamilyRepository {
  FamilyRepository._();
  static final FamilyRepository instance = FamilyRepository._();

  // ─── Read ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> currentMembership() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return null;
    return await SupabaseService.client
        .from('family_members')
        .select('id, family_id, role, joined_at')
        .eq('user_id', user.id)
        .order('joined_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> familyById(String familyId) async {
    return await SupabaseService.client
        .from('families')
        .select('*')
        .eq('id', familyId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> members(String familyId) async {
    final rows = await SupabaseService.client
        .from('family_members')
        .select('id, user_id, role, joined_at')
        .eq('family_id', familyId);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> profilesByUserIds(
      List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final res = await SupabaseService.rpc(
      'get_family_member_profiles',
      params: {'_user_ids': userIds},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> gamification(String familyId) async {
    final res = await SupabaseService.rpc(
      'get_family_gamification',
      params: {'_family_id': familyId},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> recentReceipts(
    String familyId, {
    int limit = 10,
  }) async {
    final res = await SupabaseService.rpc(
      'get_family_recent_receipts',
      params: {'_family_id': familyId, '_limit': limit},
    );
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<int> familySize(String familyId) async {
    final res = await SupabaseService.rpc(
      'get_family_size',
      params: {'_family_id': familyId},
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return 0;
  }

  /// Resolve a username to a UUID via the matching RPC. Returns null
  /// when no user matches.
  Future<String?> findUserByUsername(String username) async {
    try {
      final res = await SupabaseService.rpc(
        'find_user_by_username',
        params: {'_username': username.trim()},
      );
      return res is String && res.isNotEmpty ? res : null;
    } catch (e) {
      debugPrint('find_user_by_username failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> pendingInvitationsForFamily(
      String familyId) async {
    final rows = await SupabaseService.client
        .from('family_invitations')
        .select('id, invited_email, invited_user_id, status, '
            'expires_at, created_at')
        .eq('family_id', familyId)
        .inFilter('status', ['pending', 'expired'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ─── Mutations ──────────────────────────────────────────────────────

  Future<String> createFamily(String name) async {
    final user = SupabaseService.auth.currentUser!;
    final row = await SupabaseService.client
        .from('families')
        .insert({'name': name.trim(), 'created_by': user.id})
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Insert + fire-and-forget `send-push-notification` Edge Function
  /// when we know the receiver's user_id. Returns the invitation row.
  Future<Map<String, dynamic>> sendInvitation({
    required String familyId,
    required String familyName,
    required String invitedEmail,
    String? invitedUserId,
  }) async {
    final user = SupabaseService.auth.currentUser!;
    final inserted = await SupabaseService.client
        .from('family_invitations')
        .insert({
          'family_id': familyId,
          'invited_by': user.id,
          'invited_email': invitedEmail.toLowerCase(),
          if (invitedUserId != null) 'invited_user_id': invitedUserId,
          'status': 'pending',
          'expires_at': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
        })
        .select()
        .single();

    if (invitedUserId != null) {
      // Best-effort native push — backend Edge Function fans out to
      // FCM (mobile) and Web Push (browser) when invoked.
      unawaitedPush(invitedUserId, familyName);
    }

    return Map<String, dynamic>.from(inserted);
  }

  void unawaitedPush(String userId, String familyName) {
    SupabaseService.invokeFunction(
      'send-push-notification',
      body: {
        'user_ids': [userId],
        'payload': {
          'title': 'Zaproszenie do rodziny',
          'body': 'Zostałeś zaproszony do rodziny „$familyName".',
          'url': '/dashboard?tab=family',
          'tag': 'family-invitation',
        },
      },
    ).catchError((Object e) {
      debugPrint('send-push-notification failed: $e');
      // Edge function returns a wrapped FunctionResponse on success,
      // any value is fine since we ignore the result here.
      throw e;
    }).then((_) {}, onError: (_) {});
  }

  Future<bool> hasPendingInvite({
    required String familyId,
    required String email,
  }) async {
    final hit = await SupabaseService.client
        .from('family_invitations')
        .select('id')
        .eq('family_id', familyId)
        .eq('invited_email', email.toLowerCase())
        .eq('status', 'pending')
        .maybeSingle();
    return hit != null;
  }

  Future<void> cancelInvitation(String invitationId) async {
    await SupabaseService.client
        .from('family_invitations')
        .update({'status': 'cancelled'}).eq('id', invitationId);
  }

  Future<void> rejectInvitation(String invitationId) async {
    await SupabaseService.client
        .from('family_invitations')
        .update({'status': 'rejected'}).eq('id', invitationId);
  }

  /// Accept invitation transactionally with up to 3 retries and
  /// 800ms-per-attempt exponential backoff (matches the web spec).
  Future<void> acceptInvitation({
    required String invitationId,
    required String familyId,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await SupabaseService.rpc('accept_family_invitation_tx', params: {
          '_invitation_id': invitationId,
          '_family_id': familyId,
        });
        return;
      } catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
        }
      }
    }
    throw lastError!;
  }

  Future<void> removeMember(String memberRowId) async {
    await SupabaseService.client
        .from('family_members')
        .delete()
        .eq('id', memberRowId);
  }

  Future<void> deleteFamily(String familyId) async {
    await SupabaseService.client.from('families').delete().eq('id', familyId);
  }
}
