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
        // Members list
        Text(
          'Członkowie',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...members.map((m) {
          final profile = m['profiles'] as Map<String, dynamic>?;
          final memberRole = m['role'] as String? ?? 'member';
          final memberId = m['user_id'] as String? ?? '';
          final bestAchievement = ref.watch(bestAchievementProvider(memberId));

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                (profile?['first_name'] as String? ??
                        profile?['username'] as String? ??
                        '?')
                    .characters
                    .first
                    .toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              profile?['username'] as String? ??
                  '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'
                      .trim(),
            ),
            subtitle: bestAchievement.when(
              data: (a) => a != null
                  ? Row(
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
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  : null,
              loading: () => null,
              error: (_, __) => null,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (memberRole == 'admin')
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              ],
            ),
          );
        }),
        // Invite section
        if (isAdmin) ...[
          const SizedBox(height: 16),
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
