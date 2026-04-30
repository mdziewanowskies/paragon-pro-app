import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../shared/widgets/loading_spinner.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isPurchasing = false;
  bool _isYearly = true;

  String _formatPrice(Package? pkg, String fallback) {
    if (pkg == null) return fallback;
    final price = pkg.storeProduct.priceString;
    // If store returns PLN price, use it; otherwise show our fallback
    if (price.contains('zł') || price.contains('PLN')) return price;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isPurchasing = true);
    try {
      final success = await RevenueCatService.purchase(package);
      if (success && mounted) {
        ref.invalidate(revenueCatStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium aktywowany! Dziękujemy!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        final code = PurchasesErrorHelper.getErrorCode(e);
        if (code != PurchasesErrorCode.purchaseCancelledError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd: ${e.message}')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isPurchasing = true);
    try {
      final restored = await RevenueCatService.restorePurchases();
      if (mounted) {
        ref.invalidate(revenueCatStatusProvider);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offerings = ref.watch(revenueCatOfferingsProvider);
    final status = ref.watch(revenueCatStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: offerings.when(
          loading: () => const LoadingSpinner(),
          error: (_, __) => _buildPaywall(null, status.value),
          data: (data) => _buildPaywall(data?.current, status.value),
        ),
      ),
    );
  }

  Widget _buildPaywall(Offering? offering, SubscriptionStatus? current) {
    Package? monthly;
    Package? yearly;

    if (offering != null) {
      for (final pkg in offering.availablePackages) {
        if (pkg.packageType == PackageType.annual) yearly = pkg;
        if (pkg.packageType == PackageType.monthly) monthly = pkg;
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, size: 28),
              onPressed: () => context.go('/'),
              padding: const EdgeInsets.all(16),
            ),
          ),

          // Hero
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Colors.amber, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'ParagonPro Premium',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '7 dni za darmo — anuluj kiedy chcesz',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Features
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: const [
                _FeatureRow(Icons.all_inclusive_rounded,
                    'Nielimitowane skanowanie paragonów'),
                _FeatureRow(
                    Icons.auto_awesome, 'Zaawansowane rozpoznawanie AI'),
                _FeatureRow(Icons.description_rounded,
                    'Pełna integracja z KSeF'),
                _FeatureRow(Icons.analytics_rounded,
                    'Zaawansowana analityka wydatków'),
                _FeatureRow(Icons.family_restroom_rounded,
                    'Konto rodzinne do 5 osób'),
                _FeatureRow(Icons.shield_rounded,
                    'Przypomnienia o gwarancjach'),
                _FeatureRow(Icons.picture_as_pdf_rounded,
                    'Eksport PDF, CSV i XML'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Plan toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  _PlanTab(
                    label: 'Miesięcznie',
                    price: _formatPrice(monthly, '19,99 zł'),
                    isSelected: !_isYearly,
                    onTap: () => setState(() => _isYearly = false),
                  ),
                  _PlanTab(
                    label: 'Rocznie',
                    price: _formatPrice(yearly, '179,99 zł'),
                    badge: '-20%',
                    isSelected: _isYearly,
                    onTap: () => setState(() => _isYearly = true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_isYearly)
            Text(
              yearly != null
                  ? 'to tylko ${(yearly.storeProduct.price / 12).toStringAsFixed(2)} zł/miesiąc'
                  : 'to tylko 15,00 zł/miesiąc',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.8),
              ),
            ),
          const SizedBox(height: 24),

          // CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isPurchasing
                    ? null
                    : () {
                        final pkg = _isYearly ? yearly : monthly;
                        if (pkg != null) {
                          _purchasePackage(pkg);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Produkty nie są jeszcze skonfigurowane w sklepie'),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isPurchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Wypróbuj 7 dni za darmo',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Restore + legal
          TextButton(
            onPressed: _isPurchasing ? null : _restore,
            child: const Text('Przywróć zakupy'),
          ),

          if (current?.isActive == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton(
                onPressed: () => RevenueCatService.showCustomerCenter(),
                child: const Text('Zarządzaj subskrypcją'),
              ),
            ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Subskrypcja odnawia się automatycznie. Możesz anulować w dowolnym momencie w ustawieniach App Store lub Google Play.',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanTab({
    required this.label,
    required this.price,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
