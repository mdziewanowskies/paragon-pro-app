import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../gamification/data/best_achievement_provider.dart';
import '../../../notifications/data/notification_providers.dart';
import '../../data/family_constants.dart';
import '../../data/family_repository.dart';

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

enum _InviteMode { email, username }

class _FamilyManagementState extends ConsumerState<FamilyManagement> {
  final _inviteController = TextEditingController();
  _InviteMode _mode = _InviteMode.email;
  bool _sending = false;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final familyId = widget.familyData['familyId'] as String?;
    final familyMap = widget.familyData['family'] as Map<String, dynamic>?;
    final familyName = (familyMap?['name'] as String?) ?? 'Rodzina';

    if (familyId == null || familyId.isEmpty) {
      AppSnack.show(
        context,
        'Brak danych rodziny — odśwież ekran',
        kind: SnackKind.error,
      );
      return;
    }

    final raw = _inviteController.text.trim();
    final validationError = _mode == _InviteMode.email
        ? FamilyConstants.validateInviteEmail(raw)
        : FamilyConstants.validateUsername(raw);
    if (validationError != null) {
      Haptics.error();
      AppSnack.show(context, validationError, kind: SnackKind.warning);
      return;
    }

    final repo = FamilyRepository.instance;
    Haptics.tap();
    setState(() => _sending = true);
    try {
      // Enforce the 5-person family cap client-side too — backend has
      // a trigger that does the same check, but failing here saves a
      // round-trip and a confusing PostgrestException.
      final size = await repo.familySize(familyId);
      if (size >= FamilyConstants.sizeLimit) {
        if (mounted) {
          AppSnack.show(
            context,
            'Rodzina osiągnęła limit ${FamilyConstants.sizeLimit} '
                'osób (członkowie + oczekujące zaproszenia).',
            kind: SnackKind.warning,
          );
        }
        return;
      }

      String? invitedUserId;
      String invitedEmail = raw.toLowerCase();

      if (_mode == _InviteMode.username) {
        final foundId = await repo.findUserByUsername(raw);
        if (foundId == null) {
          if (mounted) {
            AppSnack.show(
              context,
              'Nie znaleziono użytkownika "$raw".',
              kind: SnackKind.warning,
            );
          }
          return;
        }
        invitedUserId = foundId;
        // Synthesize a placeholder email for the row when we only have
        // the user_id — matches what the web does. Real email is
        // resolved by the trigger / push handler from auth.users.
        invitedEmail = '$raw@username.local';
      } else {
        // Email mode — try to pre-resolve to a user_id if they have a
        // profile row, so the invitation_user_id column is set and the
        // receiver-side query matches by id (RLS-friendly).
        try {
          final hit = await SupabaseService.client
              .from('profiles')
              .select('user_id')
              .eq('email', invitedEmail)
              .maybeSingle();
          invitedUserId = hit?['user_id'] as String?;
        } catch (_) {
          // RLS may block this read — fine, we fall back to email-only.
        }
      }

      // Self-invite check.
      final me = SupabaseService.auth.currentUser;
      if (invitedUserId != null && invitedUserId == me?.id) {
        if (mounted) {
          AppSnack.show(
            context,
            'Nie możesz zaprosić samego siebie.',
            kind: SnackKind.warning,
          );
        }
        return;
      }

      final hasPending = await repo.hasPendingInvite(
        familyId: familyId,
        email: invitedEmail,
      );
      if (hasPending) {
        if (mounted) {
          AppSnack.show(
            context,
            'Zaproszenie dla "$raw" już oczekuje na akceptację.',
            kind: SnackKind.info,
          );
        }
        return;
      }

      await repo.sendInvitation(
        familyId: familyId,
        familyName: familyName,
        invitedEmail: invitedEmail,
        invitedUserId: invitedUserId,
      );

      _inviteController.clear();
      widget.onInviteSent?.call();
      ref.invalidate(notificationInvitationsProvider);
      Haptics.success();
      if (mounted) {
        AppSnack.show(
          context,
          invitedUserId != null
              ? 'Zaproszenie wysłane. Otrzyma powiadomienie push '
                  'i zobaczy je w aplikacji.'
              : 'Zaproszenie wysłane na $raw. Zobaczy je gdy zaloguje '
                  'się w ParagonPro.',
          kind: SnackKind.success,
        );
      }
    } catch (e) {
      Haptics.error();
      if (mounted) {
        _showSendError(e);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSendError(Object e) {
    final raw = e.toString().toLowerCase();
    String msg;
    if (raw.contains('duplicate') ||
        raw.contains('unique') ||
        raw.contains('23505')) {
      msg = 'Ten adres ma już aktywne zaproszenie do tej rodziny.';
    } else if (raw.contains('row-level security') ||
        raw.contains('rls')) {
      msg = 'Brak uprawnień do wysłania zaproszenia. Tylko admin '
          'rodziny może zapraszać nowych członków.';
    } else if (raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('failed host lookup')) {
      msg = 'Brak połączenia z serwerem. Sprawdź internet.';
    } else {
      msg = 'Nie udało się wysłać zaproszenia. Spróbuj ponownie.';
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Nie udało się wysłać')),
          ],
        ),
        content: Text(msg),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.familyData['family'] as Map<String, dynamic>?;
    final members = widget.familyData['members'] as List? ?? [];
    final role = widget.familyData['role'] as String? ?? 'member';
    final isAdmin = role == 'admin';

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
        // Members list, leaderboard, stats and danger zone are
        // rendered by their dedicated widgets in FamilyScreen — this
        // widget now only owns the hero + invite affordance.

        // Invite section
        if (isAdmin) ...[
          const SizedBox(height: 20),
          Text(
            'Zaproś do rodziny',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Limit ${FamilyConstants.sizeLimit} osób (członkowie + '
                'oczekujące zaproszenia).',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<_InviteMode>(
            segments: const [
              ButtonSegment(
                value: _InviteMode.email,
                label: Text('Email'),
                icon: Icon(Icons.alternate_email_rounded, size: 16),
              ),
              ButtonSegment(
                value: _InviteMode.username,
                label: Text('Nazwa'),
                icon: Icon(Icons.person_rounded, size: 16),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              Haptics.selection();
              setState(() {
                _mode = s.first;
                _inviteController.clear();
              });
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inviteController,
                  keyboardType: _mode == _InviteMode.email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sending ? null : _sendInvite(),
                  decoration: InputDecoration(
                    hintText: _mode == _InviteMode.email
                        ? 'np. anna@example.pl'
                        : 'np. anna_kowalska',
                    isDense: true,
                    prefixIcon: Icon(
                      _mode == _InviteMode.email
                          ? Icons.alternate_email_rounded
                          : Icons.person_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sending ? null : _sendInvite,
                child: _sending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Zaproś'),
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
