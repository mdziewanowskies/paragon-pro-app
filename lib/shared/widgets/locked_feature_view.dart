import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/haptics.dart';

/// Full-screen replacement shown when the current user can't access a
/// feature for tier reasons. The feature is *intentionally* visible in
/// the navigation (V3 'naturalny funnel' pattern) — the user clicks
/// the tab, sees what they're missing, and is one tap away from
/// upgrading.
class LockedFeatureView extends StatelessWidget {
  /// Headline above the bullets, e.g. 'KSeF — funkcja Premium'.
  final String title;

  /// Sub-headline explaining the feature in one sentence.
  final String description;

  /// Visible perks gained by upgrading (rendered with green checks).
  final List<String> perks;

  /// Lead icon shown in the amber halo.
  final IconData icon;

  /// CTA button label.
  final String ctaLabel;

  /// Analytics event name fired on view, e.g. 'paywall_view_ksef'.
  final String? analyticsEvent;

  /// Where the CTA navigates. Defaults to /pricing.
  final String route;

  const LockedFeatureView({
    super.key,
    required this.title,
    required this.description,
    required this.perks,
    this.icon = Icons.workspace_premium_rounded,
    this.ctaLabel = 'Odblokuj Premium',
    this.analyticsEvent,
    this.route = '/pricing',
  });

  @override
  Widget build(BuildContext context) {
    if (analyticsEvent != null) {
      AnalyticsService.logEvent(analyticsEvent!);
    }
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, size: 48, color: Colors.amber),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in perks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Haptics.tap();
                      context.go(route);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: Text(ctaLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
