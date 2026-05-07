import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/locked_feature_view.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../data/family_repository.dart';
import '../widgets/family_danger_zone.dart';
import '../widgets/family_expense_share_donut.dart';
import '../widgets/family_leaderboard.dart';
import '../widgets/family_lite_banner.dart';
import '../widgets/family_management.dart';
import '../widgets/family_members_list.dart';
import '../widgets/family_pending_invitations.dart';
import '../widgets/family_recent_activity.dart';
import '../widgets/family_stats_card.dart';
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

  // Get members (without join to profiles — no FK relationship).
  // Include `id` so the danger zone widget can reference the row
  // when leaving the family.
  final members = await SupabaseService.client
      .from('family_members')
      .select('id, user_id, role, joined_at')
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
    // Family Sharing is Family Lite + Premium only. Free users hit a
    // soft upsell instead of the empty management UI.
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    final invitations = ref.watch(pendingInvitationsProvider);
    final hasPendingInvite =
        (invitations.valueOrNull ?? const []).isNotEmpty;
    if (sub != null && !sub.familySharingEnabled && !hasPendingInvite) {
      return const LockedFeatureView(
        icon: Icons.family_restroom_rounded,
        title: 'Rodzina — wspólne paragony i wydatki',
        description:
            'Zaproś bliskich, dzielcie się paragonami, śledźcie '
            'wydatki rodziny i zbierajcie punkty razem w gamifikacji.',
        perks: [
          'Do 5 osób w jednej rodzinie Premium',
          'Wspólny widok wydatków i kategorii',
          'Rodzinna gamifikacja i ranking',
          'Każdy członek rodziny dostaje Family Lite (15 paragonów/mies)',
        ],
        ctaLabel: 'Odblokuj Rodzinę z Premium',
        analyticsEvent: 'paywall_view_family',
      );
    }

    final family = ref.watch(familyProvider);

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
            // Family Lite informational banner (no-op for other tiers).
            const FamilyLiteBanner(),
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
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: GenericCardSkeleton(),
              ),
              error: (e, _) => Text('Błąd: $e'),
              data: (data) {
                if (data == null) {
                  return _NoFamilyView(
                    onCreated: () => ref.invalidate(familyProvider),
                  );
                }
                final familyId = data['familyId'] as String;
                final role = data['role'] as String? ?? 'member';
                final isAdmin = role == 'admin';
                final me = SupabaseService.auth.currentUser;
                final myMember = (data['members'] as List? ?? const [])
                    .cast<Map<String, dynamic>>()
                    .firstWhere(
                  (m) => m['user_id'] == me?.id,
                  orElse: () => <String, dynamic>{},
                );
                final memberCount =
                    (data['members'] as List?)?.length ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FamilyManagement(
                      familyData: data,
                      onInviteSent: () =>
                          ref.invalidate(familyProvider),
                    ),
                    const SizedBox(height: 16),
                    FamilyLeaderboard(
                      familyId: familyId,
                      currentUserId: me?.id ?? '',
                    ),
                    const SizedBox(height: 12),
                    FamilyStatsCard(
                      familyId: familyId,
                      memberCount: memberCount,
                    ),
                    const SizedBox(height: 12),
                    FamilyExpenseShareDonut(
                      familyId: familyId,
                      memberCount: memberCount,
                    ),
                    const SizedBox(height: 12),
                    FamilyRecentActivity(familyId: familyId),
                    const SizedBox(height: 12),
                    FamilyMembersList(
                      familyId: familyId,
                      currentUserIsAdmin: isAdmin,
                      currentUserId: me?.id ?? '',
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 12),
                      FamilyPendingInvitations(familyId: familyId),
                    ],
                    const SizedBox(height: 16),
                    if (myMember.isNotEmpty && myMember['id'] != null)
                      FamilyDangerZone(
                        familyId: familyId,
                        memberRowId: myMember['id'] as String,
                        isAdmin: isAdmin,
                        onLeft: () => ref.invalidate(familyProvider),
                      ),
                    const SizedBox(height: 16),
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

class _NoFamilyView extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const _NoFamilyView({required this.onCreated});

  @override
  ConsumerState<_NoFamilyView> createState() => _NoFamilyViewState();
}

class _NoFamilyViewState extends ConsumerState<_NoFamilyView> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Only Premium / Family tier accounts can create a family. Family
  /// Lite is inherited so doesn't qualify here either.
  bool _canCreate(SubscriptionInfo? sub) {
    if (sub == null) return false;
    return sub.tier == 'premium' || sub.tier == 'family';
  }

  Future<void> _createFamily() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Haptics.error();
      AppSnack.show(
        context,
        'Podaj nazwę rodziny.',
        kind: SnackKind.warning,
      );
      return;
    }

    Haptics.tap();
    setState(() => _isCreating = true);
    try {
      // Trigger add_family_creator_as_admin handles the family_members
      // insert server-side; we only insert the family row.
      await FamilyRepository.instance.createFamily(name);
      // New family changes the user's effective tier — refresh.
      try {
        await ref.read(subscriptionProvider.notifier).refresh();
      } catch (_) {}
      _nameController.clear();
      widget.onCreated();
      Haptics.success();
      if (mounted) {
        AppSnack.show(
          context,
          'Rodzina "$name" utworzona!',
          kind: SnackKind.success,
        );
      }
    } catch (e) {
      Haptics.error();
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      String body;
      if (msg.contains('insufficient_tier') ||
          msg.contains('not allowed') ||
          msg.contains('tier')) {
        body = 'Tworzenie rodziny wymaga pakietu Premium lub Family.';
      } else if (msg.contains('rate limit')) {
        body = 'Zbyt wiele prób. Odczekaj chwilę i spróbuj ponownie.';
      } else {
        body = 'Nie udało się utworzyć rodziny. Spróbuj ponownie.';
      }
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nie udało się utworzyć'),
          content: Text(body),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Rozumiem'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _openCreateDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Utwórz rodzinę'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nazwa rodziny',
            hintText: 'Np. Kowalscy',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _createFamily();
          },
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
                    Navigator.pop(ctx);
                    _createFamily();
                  },
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    final canCreate = _canCreate(sub);
    return EmptyState(
      icon: Icons.family_restroom_rounded,
      title: canCreate ? 'Brak rodziny' : 'Rodzina wymaga Premium',
      subtitle: canCreate
          ? 'Utwórz rodzinę, aby wspólnie śledzić wydatki i dzielić paragony.'
          : 'Funkcja rodziny jest dostępna w pakiecie Premium lub Family. '
              'Twoi członkowie automatycznie otrzymają plan Family Lite.',
      actionLabel: canCreate ? 'Utwórz rodzinę' : 'Przejdź na Premium',
      onAction: canCreate
          ? _openCreateDialog
          : () => context.go('/pricing'),
    );
  }
}
