import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../shared/widgets/loading_spinner.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isYearly = false;
  bool _isPurchasing = false;
  String? _purchasingId;

  Future<void> _purchase(Package package) async {
    setState(() {
      _isPurchasing = true;
      _purchasingId = package.identifier;
    });

    try {
      final success = await PurchaseService.purchase(package);
      if (success && mounted) {
        ref.invalidate(purchaseStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subskrypcja aktywowana! Dziękujemy!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _purchasingId = null;
        });
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _isPurchasing = true);
    try {
      final restored = await PurchaseService.restorePurchases();
      if (mounted) {
        ref.invalidate(purchaseStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restored
                ? 'Zakupy przywrócone!'
                : 'Nie znaleziono aktywnych subskrypcji'),
          ),
        );
        if (restored) context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd przywracania: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offerings = ref.watch(offeringsProvider);
    final status = ref.watch(purchaseStatusProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Wybierz plan'),
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _restore,
            child: const Text('Przywróć'),
          ),
        ],
      ),
      body: offerings.when(
        loading: () => const LoadingSpinner(),
        error: (e, _) => _buildFallbackPricing(status.value),
        data: (data) {
          if (data == null || data.current == null) {
            return _buildFallbackPricing(status.value);
          }

          final offering = data.current!;
          return _buildPaywall(offering, status.value);
        },
      ),
    );
  }

  Widget _buildPaywall(Offering offering, SubscriptionStatus? currentStatus) {
    // Find packages
    Package? premiumMonthly;
    Package? premiumYearly;
    Package? familyMonthly;
    Package? familyYearly;

    for (final pkg in offering.availablePackages) {
      final id = pkg.storeProduct.identifier;
      if (id.contains('premium') && id.contains('yearly')) {
        premiumYearly = pkg;
      } else if (id.contains('premium')) {
        premiumMonthly = pkg;
      } else if (id.contains('family') && id.contains('yearly')) {
        familyYearly = pkg;
      } else if (id.contains('family')) {
        familyMonthly = pkg;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Trial banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                const SizedBox(height: 8),
                const Text(
                  '7 dni za darmo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wypróbuj Premium bez zobowiązań. Anuluj kiedy chcesz.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Period toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isYearly = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isYearly
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Miesięcznie',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: !_isYearly ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isYearly = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isYearly
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Rocznie',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _isYearly ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '-17%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Premium plan
          _PlanCard(
            title: 'Premium',
            price: _isYearly
                ? (premiumYearly?.storeProduct.priceString ?? '290 zł/rok')
                : (premiumMonthly?.storeProduct.priceString ?? '29 zł/mies'),
            period: _isYearly ? '/rok' : '/miesiąc',
            features: const [
              '100 paragonów/miesiąc',
              'Zaawansowane OCR AI',
              'Pełna analityka',
              'Integracja KSeF',
              'Eksport PDF/CSV/XML',
              'Priorytetowe wsparcie',
            ],
            trial: '7 dni za darmo',
            isPopular: true,
            isCurrent: currentStatus?.tier == 'premium',
            isLoading: _isPurchasing &&
                (_purchasingId ==
                    (_isYearly
                        ? premiumYearly?.identifier
                        : premiumMonthly?.identifier)),
            onSelect: () {
              final pkg = _isYearly ? premiumYearly : premiumMonthly;
              if (pkg != null) _purchase(pkg);
            },
          ),
          const SizedBox(height: 14),

          // Family plan
          _PlanCard(
            title: 'Rodzinny',
            price: _isYearly
                ? (familyYearly?.storeProduct.priceString ?? '490 zł/rok')
                : (familyMonthly?.storeProduct.priceString ?? '49 zł/mies'),
            period: _isYearly ? '/rok' : '/miesiąc',
            features: const [
              'Wszystko z Premium',
              '500 paragonów/miesiąc',
              'Wspólne konto rodzinne',
              'Do 5 członków rodziny',
              'Statystyki rodzinne',
            ],
            trial: '7 dni za darmo',
            isCurrent: currentStatus?.tier == 'family',
            isLoading: _isPurchasing &&
                (_purchasingId ==
                    (_isYearly
                        ? familyYearly?.identifier
                        : familyMonthly?.identifier)),
            onSelect: () {
              final pkg = _isYearly ? familyYearly : familyMonthly;
              if (pkg != null) _purchase(pkg);
            },
          ),
          const SizedBox(height: 20),

          // Free plan info
          if (currentStatus?.isFree == true)
            Text(
              'Aktualnie korzystasz z planu Darmowego (10 paragonów/miesiąc)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 12),
          // Trial info
          if (currentStatus?.isTrial == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Jesteś w okresie próbnym. Subskrypcja zacznie się po 7 dniach.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Legal
          Text(
            'Subskrypcja odnawia się automatycznie. Możesz anulować w dowolnym momencie w ustawieniach App Store / Google Play.',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Fallback when RevenueCat not configured / offline
  Widget _buildFallbackPricing(SubscriptionStatus? status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Nie udało się pobrać planów cenowych',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sprawdź połączenie z internetem i spróbuj ponownie.',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(offeringsProvider),
            child: const Text('Ponów'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _restore,
            child: const Text('Przywróć zakupy'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final String? trial;
  final bool isPopular;
  final bool isCurrent;
  final bool isLoading;
  final VoidCallback? onSelect;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    this.trial,
    this.isPopular = false,
    this.isCurrent = false,
    this.isLoading = false,
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (trial != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trial!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
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
                          onPressed: isLoading ? null : onSelect,
                          child: isLoading
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : Text(trial != null
                                  ? 'Wypróbuj za darmo'
                                  : 'Wybierz'),
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
