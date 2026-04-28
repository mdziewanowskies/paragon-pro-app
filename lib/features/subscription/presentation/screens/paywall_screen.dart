import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
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
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    // Try showing native RevenueCat paywall first
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryNativePaywall());
  }

  Future<void> _tryNativePaywall() async {
    try {
      final purchased = await RevenueCatService.showPaywall();
      if (purchased && mounted) {
        ref.invalidate(revenueCatStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subskrypcja aktywowana!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      debugPrint('Native paywall failed, showing custom: $e');
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isPurchasing = true);
    try {
      final success = await RevenueCatService.purchase(package);
      if (success && mounted) {
        ref.invalidate(revenueCatStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subskrypcja aktywowana! Dziękujemy!'),
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
            SnackBar(content: Text('Błąd zakupu: ${e.message}')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        title: const Text('ParagonPro Pro'),
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _restore,
            child: const Text('Przywróć'),
          ),
        ],
      ),
      body: offerings.when(
        loading: () => const LoadingSpinner(),
        error: (_, __) => _buildFallback(),
        data: (data) {
          if (data?.current == null) return _buildFallback();
          return _buildCustomPaywall(
              data!.current!, status.value);
        },
      ),
    );
  }

  Widget _buildCustomPaywall(
      Offering offering, SubscriptionStatus? currentStatus) {
    // Sort packages: lifetime first, then yearly, monthly
    final packages = List<Package>.from(offering.availablePackages);
    packages.sort((a, b) {
      const order = {
        PackageType.lifetime: 0,
        PackageType.annual: 1,
        PackageType.monthly: 2,
      };
      return (order[a.packageType] ?? 3)
          .compareTo(order[b.packageType] ?? 3);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Colors.amber, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'ParagonPro Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '7 dni za darmo • Anuluj kiedy chcesz',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Features
          ...[
            _Feature(Icons.receipt_long_rounded, 'Nielimitowane paragony'),
            _Feature(Icons.auto_awesome, 'Zaawansowane OCR AI'),
            _Feature(Icons.description_rounded, 'Pełna integracja KSeF'),
            _Feature(Icons.analytics_rounded, 'Zaawansowana analityka'),
            _Feature(Icons.picture_as_pdf_rounded, 'Eksport PDF/CSV/XML'),
            _Feature(Icons.family_restroom_rounded,
                'Konto rodzinne (do 5 osób)'),
            _Feature(Icons.support_agent_rounded, 'Priorytetowe wsparcie'),
          ],
          const SizedBox(height: 24),

          // Packages
          ...packages.map((pkg) {
            final product = pkg.storeProduct;
            final isLifetime =
                pkg.packageType == PackageType.lifetime;
            final isYearly = pkg.packageType == PackageType.annual;

            String label;
            String? badge;
            if (isLifetime) {
              label = 'Na zawsze';
              badge = 'Najlepsza wartość';
            } else if (isYearly) {
              label = 'Rocznie';
              badge = 'Oszczędzasz 17%';
            } else {
              label = 'Miesięcznie';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PackageCard(
                label: label,
                price: product.priceString,
                badge: badge,
                isHighlighted: isYearly,
                isLoading: _isPurchasing,
                isCurrent: currentStatus?.productId ==
                    product.identifier,
                onTap: () => _purchasePackage(pkg),
              ),
            );
          }),
          const SizedBox(height: 12),

          // Manage subscription
          if (currentStatus?.isActive == true)
            OutlinedButton(
              onPressed: () => RevenueCatService.showCustomerCenter(),
              child: const Text('Zarządzaj subskrypcją'),
            ),

          // Trial info
          if (currentStatus?.isTrial == true)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_rounded,
                        color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Okres próbny aktywny — subskrypcja zacznie się po 7 dniach',
                        style:
                            TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
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

  Widget _buildFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nie udało się załadować planów',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('Sprawdź połączenie i spróbuj ponownie'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(revenueCatOfferingsProvider);
              },
              child: const Text('Ponów'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _restore,
              child: const Text('Przywróć zakupy'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await RevenueCatService.showPaywall();
              },
              child: const Text('Otwórz natywny paywall'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon,
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

class _PackageCard extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool isHighlighted;
  final bool isLoading;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PackageCard({
    required this.label,
    required this.price,
    this.badge,
    this.isHighlighted = false,
    this.isLoading = false,
    this.isCurrent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCurrent || isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
            width: isHighlighted ? 2 : 1,
          ),
          color: isHighlighted
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.06)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
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
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Aktywny',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
              )
            else if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
