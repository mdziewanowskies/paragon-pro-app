import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../data/family_constants.dart';
import '../../data/family_data_provider.dart';
import '../../data/family_member_models.dart';
import '../../data/family_repository.dart';

enum _MembersSort { points, name, joined }

/// Sortable list of family members with avatar (initials), display
/// name, admin badge, points, level, streak, total receipts.
/// Admin-only delete button on each non-admin row.
class FamilyMembersList extends ConsumerStatefulWidget {
  final String familyId;
  final bool currentUserIsAdmin;
  final String currentUserId;

  const FamilyMembersList({
    super.key,
    required this.familyId,
    required this.currentUserIsAdmin,
    required this.currentUserId,
  });

  @override
  ConsumerState<FamilyMembersList> createState() =>
      _FamilyMembersListState();
}

class _FamilyMembersListState extends ConsumerState<FamilyMembersList> {
  _MembersSort _sort = _MembersSort.points;

  List<FamilyMember> _sorted(List<FamilyMember> source) {
    final list = [...source];
    switch (_sort) {
      case _MembersSort.points:
        list.sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          if (byPoints != 0) return byPoints;
          return b.totalReceipts.compareTo(a.totalReceipts);
        });
        break;
      case _MembersSort.name:
        list.sort((a, b) => FamilyDisplay.displayName(
              firstName: a.firstName,
              lastName: a.lastName,
              username: a.username,
            ).toLowerCase().compareTo(
                  FamilyDisplay.displayName(
                    firstName: b.firstName,
                    lastName: b.lastName,
                    username: b.username,
                  ).toLowerCase(),
                ));
        break;
      case _MembersSort.joined:
        list.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        break;
    }
    return list;
  }

  Future<void> _confirmRemove(FamilyMember m) async {
    Haptics.medium();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć członka rodziny?'),
        content: Text(
          'Usunięcie ${FamilyDisplay.displayName(firstName: m.firstName, lastName: m.lastName, username: m.username)} '
          'sprawi, że straci dostęp do wspólnych paragonów i rodzinnej '
          'gamifikacji. Jego subskrypcja Family Lite zostanie wyłączona.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FamilyRepository.instance.removeMember(m.memberRowId);
      // Realtime on family_members will invalidate subscription on
      // both sides; refetch the list locally to reflect the removal
      // immediately for the admin UI.
      ref.invalidate(familyMembersProvider(widget.familyId));
      Haptics.success();
    } catch (_) {
      Haptics.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMembers = ref.watch(familyMembersProvider(widget.familyId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Członkowie',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            PopupMenuButton<_MembersSort>(
              tooltip: 'Sortuj',
              icon: const Icon(Icons.sort_rounded, size: 20),
              onSelected: (v) {
                Haptics.selection();
                setState(() => _sort = v);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: _MembersSort.points,
                    child: Text('Po punktach')),
                PopupMenuItem(
                    value: _MembersSort.name, child: Text('Po nazwie')),
                PopupMenuItem(
                    value: _MembersSort.joined,
                    child: Text('Po dacie dołączenia')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        asyncMembers.when(
          loading: () => Column(
            children: const [
              GenericCardSkeleton(),
              GenericCardSkeleton(),
            ],
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Nie udało się wczytać członków: $e'),
          ),
          data: (res) {
            if (res.members.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Brak członków'),
              );
            }
            final list = _sorted(res.members);
            return Column(
              children: [
                for (final m in list)
                  _MemberRow(
                    member: m,
                    canRemove:
                        widget.currentUserIsAdmin && !m.isAdmin,
                    isMe: m.userId == widget.currentUserId,
                    onRemove: () => _confirmRemove(m),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final FamilyMember member;
  final bool canRemove;
  final bool isMe;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member,
    required this.canRemove,
    required this.isMe,
    required this.onRemove,
  });

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name + (isMe ? ' (Ty)' : ''),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (member.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded,
                                  color: Colors.amber, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _StatChip(
                        icon: Icons.star_rounded,
                        text: '${member.points} pkt',
                        color: Colors.amber,
                      ),
                      _StatChip(
                        icon: Icons.bolt_rounded,
                        text: 'Lvl ${member.level}',
                        color: theme.colorScheme.primary,
                      ),
                      _StatChip(
                        icon: Icons.local_fire_department_rounded,
                        text: '${member.streakCount}',
                        color: member.streakActive
                            ? Colors.deepOrange
                            : Colors.grey,
                      ),
                      _StatChip(
                        icon: Icons.receipt_long_rounded,
                        text: '${member.totalReceipts}',
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canRemove)
              IconButton(
                icon: const Icon(Icons.person_remove_rounded,
                    color: Colors.redAccent, size: 20),
                tooltip: 'Usuń z rodziny',
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
