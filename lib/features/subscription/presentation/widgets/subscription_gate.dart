import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/subscription_service.dart';

class SubscriptionGate extends ConsumerWidget {
  final Widget child;
  final bool requireAi;
  final bool requireFamily;
  final bool requireAdvancedAnalytics;
  final String featureName;

  const SubscriptionGate({
    super.key,
    required this.child,
    this.requireAi = false,
    this.requireFamily = false,
    this.requireAdvancedAnalytics = false,
    this.featureName = 'Ta funkcja',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);

    return subscription.when(
      loading: () => child,
      error: (_, __) => child,
      data: (sub) {
        bool blocked = false;
        if (requireAi && !sub.aiFeaturesEnabled) blocked = true;
        if (requireFamily && !sub.familySharingEnabled) blocked = true;
        if (requireAdvancedAnalytics && !sub.advancedAnalytics) {
          blocked = true;
        }

        if (!blocked) return child;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    size: 40, color: Colors.amber),
              ),
              const SizedBox(height: 16),
              Text(
                'Funkcja Premium',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '$featureName jest dostępna w planie Premium.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/pricing'),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Ulepsz plan'),
              ),
            ],
          ),
        );
      },
    );
  }
}
