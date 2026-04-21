import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Cache all achievements (they're global, don't change often)
final _allAchievementsProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  try {
    final data = await SupabaseService.client
        .from('achievements')
        .select('id, name, icon, points');
    final map = <String, Map<String, dynamic>>{};
    for (final a in data as List) {
      map[a['id'] as String] = Map<String, dynamic>.from(a);
    }
    return map;
  } catch (e) {
    debugPrint('Failed to load achievements: $e');
    return {};
  }
});

final userAchievementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  try {
    // Step 1: Get user's unlocked achievement IDs
    final unlocked = await SupabaseService.client
        .from('user_achievements')
        .select('achievement_id, unlocked_at')
        .eq('user_id', userId);

    final list = unlocked as List;
    if (list.isEmpty) return [];

    // Step 2: Get achievement details from cached global list
    final allAchievements = await ref.watch(_allAchievementsProvider.future);

    return list.map((ua) {
      final achievementId = ua['achievement_id'] as String;
      final a = allAchievements[achievementId];
      return <String, dynamic>{
        'name': a?['name'] ?? 'Osiągnięcie',
        'icon': a?['icon'] ?? '\u{1F3C6}',
        'points': a?['points'] ?? 0,
        'unlocked_at': ua['unlocked_at'],
      };
    }).toList();
  } catch (e) {
    debugPrint('Failed to load achievements for $userId: $e');
    return [];
  }
});

final bestAchievementProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, userId) async {
  final achievements = await ref.watch(userAchievementsProvider(userId).future);
  if (achievements.isEmpty) return null;

  Map<String, dynamic>? best;
  int bestPoints = -1;
  for (final a in achievements) {
    final pts = a['points'] as int? ?? 0;
    if (pts > bestPoints) {
      bestPoints = pts;
      best = a;
    }
  }
  return best;
});
