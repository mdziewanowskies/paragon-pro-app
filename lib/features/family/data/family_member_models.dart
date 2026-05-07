/// Combined member view — joins family_members with profile and
/// gamification data so the UI doesn't have to do its own merge.
class FamilyMember {
  final String memberRowId;
  final String userId;
  final String role; // 'admin' | 'member'
  final DateTime joinedAt;

  // Profile (from get_family_member_profiles)
  final String? username;
  final String? firstName;
  final String? lastName;

  // Gamification (from get_family_gamification)
  final int points;
  final int level;
  final int totalReceipts;
  final int streakCount;
  final DateTime? streakLastDate;

  const FamilyMember({
    required this.memberRowId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.username,
    this.firstName,
    this.lastName,
    this.points = 0,
    this.level = 1,
    this.totalReceipts = 0,
    this.streakCount = 0,
    this.streakLastDate,
  });

  bool get isAdmin => role == 'admin';

  /// Whether this user has lit-up streak today/yesterday — purely
  /// cosmetic, used to color the 🔥 row.
  bool get streakActive {
    final last = streakLastDate;
    if (last == null) return false;
    final diff = DateTime.now().difference(last).inDays;
    return diff <= 1 && streakCount > 0;
  }
}
