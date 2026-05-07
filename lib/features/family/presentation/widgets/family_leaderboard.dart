import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/family_constants.dart';
import '../../data/family_data_provider.dart';
import '../../data/family_member_models.dart';

/// Family ranking — sorts members by points then total_receipts and
/// renders 🏆🥈🥉 / #N positions plus a motivational footer:
///   not #1 → 'Brakuje Ci X pkt do miejsca #Y'
///   #1     → 'Jesteś liderem rodziny! 🏆'
class FamilyLeaderboard extends ConsumerWidget {
  final String familyId;
  final String currentUserId;

  const FamilyLeaderboard({
    super.key,
    required this.familyId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMembers = ref.watch(familyMembersProvider(familyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: asyncMembers.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) =>
              const Text('Nie udało się wczytać rankingu'),
          data: (res) => _buildContent(context, res.members),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<FamilyMember> raw) {
    if (raw.isEmpty) return const Text('Brak członków rodziny');
    final ranked = [...raw];
    ranked.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      return b.totalReceipts.compareTo(a.totalReceipts);
    });

    final myIndex =
        ranked.indexWhere((m) => m.userId == currentUserId);
    final me = myIndex >= 0 ? ranked[myIndex] : null;

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              'Ranking rodziny',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < ranked.length; i++)
          _LeaderRow(
            position: i + 1,
            member: ranked[i],
            isMe: ranked[i].userId == currentUserId,
          ),
        if (me != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  myIndex == 0
                      ? Icons.emoji_events_rounded
                      : Icons.trending_up_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _motivation(myIndex, ranked, me),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _motivation(
      int myIndex, List<FamilyMember> ranked, FamilyMember me) {
    if (myIndex == 0) return 'Jesteś liderem rodziny! 🏆';
    final ahead = ranked[myIndex - 1];
    final delta = ahead.points - me.points;
    if (delta <= 0) return 'Idziesz łeb w łeb z miejscem #${myIndex}!';
    return 'Brakuje Ci $delta pkt do miejsca #$myIndex.';
  }
}

class _LeaderRow extends StatelessWidget {
  final int position;
  final FamilyMember member;
  final bool isMe;

  const _LeaderRow({
    required this.position,
    required this.member,
    required this.isMe,
  });

  String get _positionGlyph {
    switch (position) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$position';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = FamilyDisplay.displayName(
      firstName: member.firstName,
      lastName: member.lastName,
      username: member.username,
    );
    final initials = FamilyDisplay.initials(
      firstName: member.firstName,
      lastName: member.lastName,
      username: member.username,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _positionGlyph,
              style: TextStyle(
                fontSize: position <= 3 ? 22 : 14,
                fontWeight: FontWeight.w800,
                color: position <= 3
                    ? null
                    : theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 16,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name + (isMe ? ' (Ty)' : ''),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        isMe ? FontWeight.w800 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Lvl ${member.level} • ${member.totalReceipts} paragonów',
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
            '${member.points} pkt',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isMe ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
