import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';

class MonthlyChallenges extends StatelessWidget {
  final List<Map<String, dynamic>> challenges;
  final VoidCallback? onBrowseChallenges;

  const MonthlyChallenges({
    super.key,
    required this.challenges,
    this.onBrowseChallenges,
  });

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: EmptyState(
            icon: Icons.flag_rounded,
            title: 'Nie masz jeszcze aktywnego wyzwania na ten miesiąc',
            subtitle:
                'Wyzwania pomagają oszczędzać i zarabiać dodatkowe punkty.',
            actionLabel: onBrowseChallenges != null
                ? 'Dołącz do pierwszego wyzwania'
                : null,
            onAction: onBrowseChallenges,
          ),
        ),
      );
    }

    return Column(
      children: challenges.map((c) {
        final target = c['target_value'] as int? ?? 1;
        final current = c['current_value'] as int? ?? 0;
        final completed = c['completed'] as bool? ?? false;
        final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      completed
                          ? Icons.check_circle_rounded
                          : Icons.flag_rounded,
                      color: completed ? AppColors.lightPrimary : Colors.orange,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c['name'] as String? ?? 'Wyzwanie',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${c['reward_points'] ?? 0} pkt',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
                if (c['description'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    c['description'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completed
                                ? AppColors.lightPrimary
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$current / $target',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
