import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../widgets/family_management.dart';
import '../widgets/family_stats.dart';
import '../widgets/invitation_card.dart';

final familyProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return null;

  final membership = await SupabaseService.client
      .from('family_members')
      .select('family_id, role, families(id, name, created_by)')
      .eq('user_id', userId)
      .maybeSingle();

  if (membership == null) return null;

  final familyId = membership['family_id'] as String;

  // Get members (without join to profiles — no FK relationship)
  final members = await SupabaseService.client
      .from('family_members')
      .select('user_id, role, joined_at')
      .eq('family_id', familyId);

  debugPrint('=== Family members for $familyId ===');
  debugPrint('Found ${(members as List).length} members: $members');

  // Fetch profiles separately for each member
  final memberList = members;
  final userIds = memberList
      .map((m) => m['user_id'] as String)
      .toList();

  Map<String, Map<String, dynamic>> profileMap = {};
  if (userIds.isNotEmpty) {
    final profiles = await SupabaseService.client
        .from('profiles')
        .select('user_id, username, first_name, last_name')
        .inFilter('user_id', userIds);
    for (final p in profiles as List) {
      profileMap[p['user_id'] as String] = Map<String, dynamic>.from(p);
    }
  }

  // Attach profile data to each member
  final enrichedMembers = memberList.map((m) {
    final uid = m['user_id'] as String;
    return <String, dynamic>{
      ...Map<String, dynamic>.from(m),
      'profiles': profileMap[uid],
    };
  }).toList();

  // Get pending invitations
  final invitations = await SupabaseService.client
      .from('family_invitations')
      .select()
      .eq('family_id', familyId)
      .eq('status', 'pending');

  return {
    'family': membership['families'],
    'role': membership['role'],
    'members': enrichedMembers,
    'invitations': invitations,
    'familyId': familyId,
  };
});

final pendingInvitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return [];

  final email = SupabaseService.auth.currentUser?.email;
  if (email == null) return [];

  final data = await SupabaseService.client
      .from('family_invitations')
      .select('*, families(name)')
      .eq('invited_email', email)
      .eq('status', 'pending');

  return List<Map<String, dynamic>>.from(data);
});

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);
    final invitations = ref.watch(pendingInvitationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(familyProvider);
        ref.invalidate(pendingInvitationsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending invitations
            invitations.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.mail_rounded,
                                size: 20, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Zaproszenia (${list.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...list.map((inv) => InvitationCard(
                              invitation: inv,
                              onAccept: () async {
                                final userId =
                                    SupabaseService.auth.currentUser!.id;
                                await SupabaseService.client
                                    .from('family_invitations')
                                    .update({'status': 'accepted'})
                                    .eq('id', inv['id']);
                                await SupabaseService.client
                                    .from('family_members')
                                    .insert({
                                  'family_id': inv['family_id'],
                                  'user_id': userId,
                                  'role': 'member',
                                });
                                ref.invalidate(familyProvider);
                                ref.invalidate(pendingInvitationsProvider);
                              },
                              onDecline: () async {
                                await SupabaseService.client
                                    .from('family_invitations')
                                    .update({'status': 'declined'})
                                    .eq('id', inv['id']);
                                ref.invalidate(pendingInvitationsProvider);
                              },
                            )),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
            // Family content
            family.when(
              loading: () => const LoadingSpinner(),
              error: (e, _) => Text('Błąd: $e'),
              data: (data) {
                if (data == null) {
                  return _NoFamilyView(
                    onCreated: () => ref.invalidate(familyProvider),
                  );
                }
                return Column(
                  children: [
                    FamilyManagement(
                      familyData: data,
                      onInviteSent: () => ref.invalidate(familyProvider),
                    ),
                    const SizedBox(height: 16),
                    FamilyStats(familyId: data['familyId'] as String),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFamilyView extends StatefulWidget {
  final VoidCallback onCreated;

  const _NoFamilyView({required this.onCreated});

  @override
  State<_NoFamilyView> createState() => _NoFamilyViewState();
}

class _NoFamilyViewState extends State<_NoFamilyView> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final family = await SupabaseService.client.from('families').insert({
        'name': _nameController.text.trim(),
        'created_by': userId,
      }).select().single();

      await SupabaseService.client.from('family_members').insert({
        'family_id': family['id'],
        'user_id': userId,
        'role': 'admin',
      });

      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.family_restroom_rounded,
      title: 'Brak rodziny',
      subtitle:
          'Utwórz rodzinę, aby wspólnie śledzić wydatki i dzielić paragony.',
      actionLabel: 'Utwórz rodzinę',
      onAction: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Utwórz rodzinę'),
            content: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nazwa rodziny',
                hintText: 'Np. Kowalscy',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anuluj'),
              ),
              ElevatedButton(
                onPressed: _isCreating
                    ? null
                    : () {
                        _createFamily();
                        Navigator.pop(ctx);
                      },
                child: const Text('Utwórz'),
              ),
            ],
          ),
        );
      },
    );
  }
}
