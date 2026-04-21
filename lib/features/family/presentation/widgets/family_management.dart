import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../gamification/data/best_achievement_provider.dart';

class FamilyManagement extends ConsumerStatefulWidget {
  final Map<String, dynamic> familyData;
  final VoidCallback? onInviteSent;

  const FamilyManagement({
    super.key,
    required this.familyData,
    this.onInviteSent,
  });

  @override
  ConsumerState<FamilyManagement> createState() => _FamilyManagementState();
}

class _FamilyManagementState extends ConsumerState<FamilyManagement> {
  final _inviteController = TextEditingController();

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final value = _inviteController.text.trim();
    if (value.isEmpty) return;

    try {
      final userId = SupabaseService.auth.currentUser!.id;
      await SupabaseService.client.from('family_invitations').insert({
        'family_id': widget.familyData['familyId'],
        'invited_by': userId,
        'invited_email': value,
        'status': 'pending',
        'expires_at':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      _inviteController.clear();
      widget.onInviteSent?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zaproszenie wysłane!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.familyData['family'] as Map<String, dynamic>?;
    final members = widget.familyData['members'] as List? ?? [];
    final role = widget.familyData['role'] as String? ?? 'member';
    final isAdmin = role == 'admin';
    final memberIds = members
        .map((m) => m['user_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Family header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.family_restroom_rounded, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family?['name'] as String? ?? 'Rodzina',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${members.length} członków',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAdmin ? 'Admin' : 'Członek',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Members list with achievements
        Text('Członkowie', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...members.map((m) => _MemberTile(
              member: m,
              ref: ref,
              context: context,
            )),

        // Family achievements summary
        const SizedBox(height: 20),
        _FamilyAchievementsSummary(memberIds: memberIds, ref: ref),

        // Invite section
        if (isAdmin) ...[
          const SizedBox(height: 20),
          Text(
            'Zaproś do rodziny',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inviteController,
                  decoration: const InputDecoration(
                    hintText: 'Email lub nazwa użytkownika',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sendInvite,
                child: const Text('Zaproś'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final dynamic member;
  final WidgetRef ref;
  final BuildContext context;

  const _MemberTile({
    required this.member,
    required this.ref,
    required this.context,
  });

  @override
  Widget build(BuildContext outerContext) {
    final profile = member['profiles'] as Map<String, dynamic>?;
    final memberRole = member['role'] as String? ?? 'member';
    final memberId = member['user_id'] as String? ?? '';
    final achievements = ref.watch(userAchievementsProvider(memberId));

    final displayName = profile?['username'] as String? ??
        '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'
            .trim();
    final initial = (profile?['first_name'] as String? ??
            profile?['username'] as String? ??
            '?')
        .characters
        .first
        .toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(outerContext)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Theme.of(outerContext).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isEmpty ? 'Użytkownik' : displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (memberRole == 'admin')
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Achievement badges
            achievements.when(
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: list.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(outerContext)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(outerContext)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a['icon'] as String? ?? '\u{1F3C6}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              a['name'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(outerContext)
                                    .colorScheme
                                    .primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyAchievementsSummary extends StatelessWidget {
  final List<String> memberIds;
  final WidgetRef ref;

  const _FamilyAchievementsSummary({
    required this.memberIds,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    // Collect all achievements from all members
    final Map<String, _AchievementStat> achievementMap = {};
    int totalAchievements = 0;

    for (final memberId in memberIds) {
      final achievements = ref.watch(userAchievementsProvider(memberId));
      achievements.whenData((list) {
        totalAchievements += list.length;
        for (final a in list) {
          final name = a['name'] as String? ?? '';
          final icon = a['icon'] as String? ?? '\u{1F3C6}';
          if (name.isNotEmpty) {
            achievementMap[name] = _AchievementStat(
              name: name,
              icon: icon,
              count: (achievementMap[name]?.count ?? 0) + 1,
              points: a['points'] as int? ?? 0,
            );
          }
        }
      });
    }

    if (achievementMap.isEmpty) return const SizedBox.shrink();

    final sortedAchievements = achievementMap.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final totalPoints = sortedAchievements.fold<int>(
        0, (sum, a) => sum + (a.points * a.count));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Osiągnięcia rodziny',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Summary stats
            Row(
              children: [
                _SummaryChip(
                  icon: Icons.emoji_events_rounded,
                  value: '$totalAchievements',
                  label: 'Łącznie',
                  context: context,
                ),
                const SizedBox(width: 12),
                _SummaryChip(
                  icon: Icons.star_rounded,
                  value: '${sortedAchievements.length}',
                  label: 'Unikalnych',
                  context: context,
                ),
                const SizedBox(width: 12),
                _SummaryChip(
                  icon: Icons.bolt_rounded,
                  value: '$totalPoints',
                  label: 'Punktów',
                  context: context,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Achievement list
            ...sortedAchievements.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(a.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${a.points} pkt',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (a.count > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '×${a.count}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final BuildContext context;

  const _SummaryChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.context,
  });

  @override
  Widget build(BuildContext outerContext) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementStat {
  final String name;
  final String icon;
  final int count;
  final int points;

  _AchievementStat({
    required this.name,
    required this.icon,
    required this.count,
    required this.points,
  });
}
