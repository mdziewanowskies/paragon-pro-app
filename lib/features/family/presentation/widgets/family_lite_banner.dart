import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/subscription_service.dart';

/// Informational banner shown on the Family screen for users currently
/// on the Family Lite tier — explains what they have, surfaces the
/// CTA to upgrade to full Premium without nagging.
///
/// Renders nothing for users on Premium or pure Free.
class FamilyLiteBanner extends ConsumerWidget {
  const FamilyLiteBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    if (sub == null || !sub.isFamilyLite) {
      return const SizedBox.shrink();
    }

    final inherited = sub.isInheritedFromFamily;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.18),
            Colors.amber.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    inherited
                        ? 'Family Lite — w Twojej rodzinie ktoś ma Premium'
                        : 'Masz plan Family Lite',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Dostępne dla Ciebie:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            const _BulletRow(
                icon: Icons.check_rounded,
                color: Colors.green,
                text: '15 paragonów / mies'),
            const _BulletRow(
                icon: Icons.check_rounded,
                color: Colors.green,
                text: 'Wspólne wydatki rodziny'),
            const _BulletRow(
                icon: Icons.check_rounded,
                color: Colors.green,
                text: 'Gamifikacja rodzinna'),
            const SizedBox(height: 12),
            Text(
              'Zablokowane (pełne Premium):',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            const _BulletRow(
                icon: Icons.lock_outline_rounded,
                color: Colors.grey,
                text: 'AI OCR i rozpoznawanie paragonów'),
            const _BulletRow(
                icon: Icons.lock_outline_rounded,
                color: Colors.grey,
                text: 'Integracja KSeF'),
            const _BulletRow(
                icon: Icons.lock_outline_rounded,
                color: Colors.grey,
                text: 'Zaawansowana analityka i eksport'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Haptics.tap();
                  context.go('/pricing');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text('Odblokuj pełne Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _BulletRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
