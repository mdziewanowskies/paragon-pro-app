import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../widgets/achievements_list.dart';
import '../widgets/monthly_challenges.dart';
import '../widgets/leaderboard.dart';

// Providers
final gamificationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return {};

  final data = await SupabaseService.client
      .from('user_gamification')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  return data ?? {'points': 0, 'level': 1, 'streak_count': 0, 'total_receipts': 0};
});

final achievementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return [];

  final allAchievements = await SupabaseService.client
      .from('achievements')
      .select()
      .order('points');

  final userAchievements = await SupabaseService.client
      .from('user_achievements')
      .select('achievement_id, unlocked_at')
      .eq('user_id', userId);

  final unlockedIds =
      (userAchievements as List).map((e) => e['achievement_id']).toSet();

  return (allAchievements as List).map((a) {
    return <String, dynamic>{
      ...Map<String, dynamic>.from(a),
      'unlocked': unlockedIds.contains(a['id']),
    };
  }).toList();
});

final challengesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return [];

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);

  List<dynamic> challenges;
  try {
    // Try text-based month column first (YYYY-MM format)
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    challenges = await SupabaseService.client
        .from('monthly_challenges')
        .select()
        .eq('month', monthKey)
        .eq('active', true);
  } catch (_) {
    try {
      // Fallback: date-based month column — query by range
      challenges = await SupabaseService.client
          .from('monthly_challenges')
          .select()
          .gte('month', monthStart.toIso8601String().split('T').first)
          .lte('month', monthEnd.toIso8601String().split('T').first)
          .eq('active', true);
    } catch (_) {
      // Last fallback: just get all active challenges
      challenges = await SupabaseService.client
          .from('monthly_challenges')
          .select()
          .eq('active', true);
    }
  }

  final progress = await SupabaseService.client
      .from('user_challenge_progress')
      .select()
      .eq('user_id', userId);

  final progressMap = {
    for (var p in (progress as List)) p['challenge_id']: p,
  };

  return challenges.map((c) {
    final p = progressMap[c['id']];
    return <String, dynamic>{
      ...Map<String, dynamic>.from(c),
      'current_value': p?['current_value'] ?? 0,
      'completed': p?['completed'] ?? false,
    };
  }).toList();
});

final leaderboardProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await SupabaseService.client
      .from('user_gamification')
      .select('user_id, points, level, total_receipts')
      .order('points', ascending: false)
      .limit(20);

  // Fetch usernames
  final userIds = (data as List).map((e) => e['user_id'] as String).toList();
  if (userIds.isEmpty) return [];

  final profiles = await SupabaseService.client
      .from('profiles')
      .select('user_id, username, first_name')
      .inFilter('user_id', userIds);

  final profileMap = {
    for (var p in (profiles as List)) p['user_id']: p,
  };

  return data.asMap().entries.map((entry) {
    final rank = entry.key + 1;
    final d = entry.value;
    final profile = profileMap[d['user_id']];
    return {
      'rank': rank,
      'username': profile?['username'] ?? profile?['first_name'] ?? 'Użytkownik',
      'points': d['points'] ?? 0,
      'level': d['level'] ?? 1,
      'isCurrentUser': d['user_id'] == SupabaseService.auth.currentUser?.id,
    };
  }).toList();
});

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(gamificationProvider);
        ref.invalidate(achievementsProvider);
        ref.invalidate(challengesProvider);
        ref.invalidate(leaderboardProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Achievements
            Text(
              'Osiągnięcia',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ref.watch(achievementsProvider).when(
                  loading: () => const SizedBox(
                      height: 120, child: LoadingSpinner()),
                  error: (e, _) => Text('Błąd: $e'),
                  data: (data) => AchievementsList(achievements: data),
                ),
            const SizedBox(height: 24),
            // Monthly challenges
            Text(
              'Wyzwania miesięczne',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ref.watch(challengesProvider).when(
                  loading: () => const SizedBox(
                      height: 120, child: LoadingSpinner()),
                  error: (e, _) => Text('Błąd: $e'),
                  data: (data) => MonthlyChallenges(challenges: data),
                ),
            const SizedBox(height: 24),
            // Leaderboard
            Text(
              'Ranking',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ref.watch(leaderboardProvider).when(
                  loading: () => const SizedBox(
                      height: 200, child: LoadingSpinner()),
                  error: (e, _) => Text('Błąd: $e'),
                  data: (data) => Leaderboard(entries: data),
                ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
