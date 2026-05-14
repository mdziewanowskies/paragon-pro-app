import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/haptics.dart';
import '../../../../shared/widgets/celebration_overlay.dart';

class AchievementsList extends StatelessWidget {
  final List<Map<String, dynamic>> achievements;

  const AchievementsList({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Brak osiągnięć do wyświetlenia'),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final a = achievements[index];
        final unlocked = a['unlocked'] as bool? ?? false;
        return _AchievementTile(
          achievement: a,
          unlocked: unlocked,
          onTap: unlocked
              ? () => _replayCelebration(context, a)
              : null,
        );
      },
    );
  }

  Future<void> _replayCelebration(
      BuildContext context, Map<String, dynamic> a) async {
    Haptics.success();
    await CelebrationOverlay.show(
      context,
      icon: Icons.emoji_events_rounded,
      iconColor: AppColors.accentGold,
      title: a['name'] as String? ?? 'Osiągnięcie',
      subtitle: '+${a['points'] ?? 0} pkt',
    );
  }
}

class _AchievementTile extends StatefulWidget {
  final Map<String, dynamic> achievement;
  final bool unlocked;
  final VoidCallback? onTap;

  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.onTap,
  });

  @override
  State<_AchievementTile> createState() => _AchievementTileState();
}

class _AchievementTileState extends State<_AchievementTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.snap,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .chain(CurveTween(curve: AppMotion.snapCurve))
        .animate(_pressCtrl);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = widget.achievement;
    final unlocked = widget.unlocked;
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: unlocked
                ? AppColors.accentGold.withValues(alpha: 0.12)
                : c.surface1,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: unlocked
                  ? AppColors.accentGold.withValues(alpha: 0.5)
                  : c.surfaceDivider,
              width: unlocked ? 1.5 : 1,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              if (!unlocked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: c.textTertiary,
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: unlocked ? 1.0 : 0.4,
                    child: Text(
                      a['icon'] as String? ?? '🏆',
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a['name'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: unlocked
                          ? c.textPrimary
                          : c.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${a['points'] ?? 0} pkt',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: unlocked
                          ? AppColors.accentGoldDeep
                          : c.textTertiary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
