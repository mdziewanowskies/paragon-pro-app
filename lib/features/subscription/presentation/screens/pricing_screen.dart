import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/subscription_service.dart';

class PricingScreen extends ConsumerWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final currentTier =
        subscription.value?.tier ?? 'free';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Plany cenowe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Wybierz plan',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ulepsz plan, aby odblokować pełnię możliwości',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _PlanCard(
              title: 'Darmowy',
              price: '0 zł',
              period: '/miesiąc',
              features: const [
                '5 paragonów/miesiąc',
                'Podstawowe OCR',
                'Brak KSeF',
                'Brak konta rodzinnego',
              ],
              isCurrent: currentTier == 'free',
              onSelect: null,
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'Premium',
              price: '19,99 zł',
              period: '/miesiąc',
              features: const [
                'Nielimitowane paragony',
                'Zaawansowane OCR AI',
                'Pełna integracja KSeF',
                'Konto rodzinne',
                'Zaawansowana analityka',
                'Eksport PDF/CSV/XML',
                'Priorytetowe wsparcie',
              ],
              isPopular: true,
              isCurrent: currentTier == 'premium',
              onSelect: currentTier == 'family'
                  ? null
                  : () => _checkout(context, 'family'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, String tier) async {
    try {
      final response = await SupabaseService.invokeFunction(
        'create-checkout-session',
        body: {
          'tier': tier,
          'userId': SupabaseService.auth.currentUser!.id,
        },
      );

      final url = response.data?['url'] as String?;
      if (url != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Przekierowanie do płatności...')),
        );
        // In real app: launch URL
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    }
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isPopular;
  final bool isCurrent;
  final VoidCallback? onSelect;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    this.isPopular = false,
    this.isCurrent = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isPopular ? 2 : 1,
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: const Text(
                'Najpopularniejszy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(f,
                                  style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: isCurrent
                      ? OutlinedButton(
                          onPressed: null,
                          child: const Text('Aktualny plan'),
                        )
                      : ElevatedButton(
                          onPressed: onSelect,
                          child: Text(
                              onSelect == null ? 'Aktualny plan' : 'Wybierz'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
