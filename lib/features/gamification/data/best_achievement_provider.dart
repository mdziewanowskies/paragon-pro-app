import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

final bestAchievementProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    final userAchievements = await SupabaseService.client
        .from('user_achievements')
        .select('achievement_id, achievements(name, icon, points)')
        .eq('user_id', userId)
        .order('unlocked_at', ascending: false);

    final list = userAchievements as List;
    if (list.isEmpty) return null;

    // Find the one with highest points
    Map<String, dynamic>? best;
    int bestPoints = -1;
    for (final ua in list) {
      final a = ua['achievements'] as Map<String, dynamic>?;
      if (a != null) {
        final pts = a['points'] as int? ?? 0;
        if (pts > bestPoints) {
          bestPoints = pts;
          best = a;
        }
      }
    }
    return best;
  } catch (_) {
    return null;
  }
});
