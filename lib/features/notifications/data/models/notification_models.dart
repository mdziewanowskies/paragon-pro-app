/// Server-side notification kinds. Stored as `notifications.type` in
/// Supabase. Anything we don't recognize falls back to [system].
enum NotificationKind {
  warrantyExpiring,
  achievementUnlocked,
  familyReceipt,
  ksefSynced,
  system;

  static NotificationKind fromRaw(String? raw) {
    switch (raw) {
      case 'warranty_expiring':
        return NotificationKind.warrantyExpiring;
      case 'achievement_unlocked':
        return NotificationKind.achievementUnlocked;
      case 'family_receipt':
        return NotificationKind.familyReceipt;
      case 'ksef_synced':
        return NotificationKind.ksefSynced;
      default:
        return NotificationKind.system;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> meta;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
    this.meta = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'].toString(),
      kind: NotificationKind.fromRaw(j['type'] as String?),
      title: (j['title'] as String?) ?? 'Powiadomienie',
      body: j['body'] as String?,
      isRead: (j['is_read'] as bool?) ?? false,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      meta: (j['data'] is Map)
          ? Map<String, dynamic>.from(j['data'] as Map)
          : const {},
    );
  }
}

/// Pending family invitation, served as a synthetic notification with
/// kind == family_invitation but its own model so we can keep the
/// accept/reject affordances cleanly typed.
class FamilyInvitation {
  final String id;
  final String familyId;
  final String? familyName;
  final String? invitedEmail;
  final DateTime createdAt;

  const FamilyInvitation({
    required this.id,
    required this.familyId,
    this.familyName,
    this.invitedEmail,
    required this.createdAt,
  });

  factory FamilyInvitation.fromJson(Map<String, dynamic> j) {
    final family = j['families'];
    return FamilyInvitation(
      id: j['id'].toString(),
      familyId: j['family_id'].toString(),
      familyName: family is Map ? family['name'] as String? : null,
      invitedEmail: j['invited_email'] as String?,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
