import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'family_member_models.dart';
import 'family_repository.dart';

class FamilyMembersResult {
  final List<FamilyMember> members;
  const FamilyMembersResult(this.members);
}

/// Fetches members + profiles + gamification for [familyId] in
/// parallel and zips them into [FamilyMember] objects.
///
/// Realtime listener on `family_members` invalidates the underlying
/// providers (subscriptionProvider + notificationInvitations) — for
/// this screen we just re-watch the FutureProvider after a manual
/// invalidate from the UI.
final familyMembersProvider = FutureProvider.autoDispose
    .family<FamilyMembersResult, String>((ref, familyId) async {
  final repo = FamilyRepository.instance;

  final membersRows = await repo.members(familyId);
  if (membersRows.isEmpty) return const FamilyMembersResult([]);

  final userIds = membersRows
      .map((r) => r['user_id'] as String?)
      .whereType<String>()
      .toList();

  final results = await Future.wait([
    repo.profilesByUserIds(userIds),
    repo.gamification(familyId),
  ]);
  final profiles = results[0];
  final gam = results[1];

  final profileById = {
    for (final p in profiles) (p['user_id'] as String): p,
  };
  final gamById = {
    for (final g in gam) (g['user_id'] as String): g,
  };

  final out = <FamilyMember>[];
  for (final m in membersRows) {
    final uid = m['user_id'] as String?;
    if (uid == null) continue;
    final p = profileById[uid] ?? const <String, dynamic>{};
    final g = gamById[uid] ?? const <String, dynamic>{};
    out.add(FamilyMember(
      memberRowId: m['id'] as String,
      userId: uid,
      role: (m['role'] as String?) ?? 'member',
      joinedAt: DateTime.tryParse(m['joined_at'] as String? ?? '') ??
          DateTime.now(),
      username: p['username'] as String?,
      firstName: p['first_name'] as String?,
      lastName: p['last_name'] as String?,
      points: (g['points'] as num?)?.toInt() ?? 0,
      level: (g['level'] as num?)?.toInt() ?? 1,
      totalReceipts: (g['total_receipts'] as num?)?.toInt() ?? 0,
      streakCount: (g['streak_count'] as num?)?.toInt() ?? 0,
      streakLastDate:
          DateTime.tryParse(g['streak_last_date'] as String? ?? ''),
    ));
  }
  return FamilyMembersResult(out);
});

/// Pending + expired invitations for an admin to manage.
final familyPendingInvitesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, familyId) async {
  return await FamilyRepository.instance.pendingInvitationsForFamily(familyId);
});

/// Recent receipts for the family activity feed (3.9).
final familyRecentReceiptsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, familyId) async {
  return await FamilyRepository.instance.recentReceipts(familyId, limit: 10);
});
