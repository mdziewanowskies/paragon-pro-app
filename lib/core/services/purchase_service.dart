import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'supabase_service.dart';

const _revenueCatApiKey = 'test_NoVmdZvFeAgfvMQrhzdosZpdoLD';

class RevenueCatService {
  static bool _initialized = false;

  // Entitlement ID from RevenueCat dashboard
  static const entitlementId = 'ParagonPro Pro';

  // ─── Initialize ──────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final userId = SupabaseService.auth.currentUser?.id;

      final config = PurchasesConfiguration(_revenueCatApiKey);
      if (userId != null) {
        config..appUserID = userId;
      }

      await Purchases.configure(config);
      _initialized = true;
      debugPrint('RevenueCat initialized (user: $userId)');

      // Listen for customer info changes
      Purchases.addCustomerInfoUpdateListener((info) {
        debugPrint('RevenueCat customer info updated');
        _syncEntitlementToSupabase(info);
      });
    } catch (e) {
      debugPrint('RevenueCat init failed: $e');
    }
  }

  // ─── Login / Logout sync with Supabase auth ──────────────

  static Future<void> loginUser(String userId) async {
    if (!_initialized) await initialize();
    try {
      await Purchases.logIn(userId);
      debugPrint('RevenueCat logged in: $userId');
    } catch (e) {
      debugPrint('RevenueCat login error: $e');
    }
  }

  static Future<void> logoutUser() async {
    try {
      if (await Purchases.isAnonymous) return;
      await Purchases.logOut();
      debugPrint('RevenueCat logged out');
    } catch (e) {
      debugPrint('RevenueCat logout error: $e');
    }
  }

  // ─── Entitlement check ───────────────────────────────────

  static Future<bool> isProUser() async {
    if (!_initialized) await initialize();
    try {
      // Check RevenueCat first (mobile purchases)
      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.all[entitlementId]?.isActive == true) {
        return true;
      }
    } catch (e) {
      debugPrint('isProUser RC error: $e');
    }

    // Fallback: check Supabase (web purchases via Stripe)
    return await _isProInSupabase();
  }

  static Future<SubscriptionStatus> getStatus() async {
    if (!_initialized) await initialize();

    // Check RevenueCat first
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.all[entitlementId];

      if (entitlement?.isActive == true) {
        final productId = entitlement!.productIdentifier;
        const tier = 'premium';

        return SubscriptionStatus(
          tier: tier,
          isActive: true,
          productId: productId,
          expirationDate: entitlement.expirationDate != null
              ? DateTime.tryParse(entitlement.expirationDate!)
              : null,
          isTrial: entitlement.periodType == PeriodType.trial,
          willRenew: entitlement.willRenew,
          isLifetime: productId.contains('lifetime'),
        );
      }
    } catch (e) {
      debugPrint('getStatus RC error: $e');
    }

    // Fallback: check Supabase (web/Stripe subscription)
    if (await _isProInSupabase()) {
      return SubscriptionStatus(
        tier: 'premium',
        isActive: true,
        productId: 'web_stripe',
        isLifetime: false,
      );
    }

    return SubscriptionStatus.free();
  }

  /// Check Supabase user_subscriptions for web/Stripe purchases
  static Future<bool> _isProInSupabase() async {
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) return false;

      final data = await SupabaseService.client
          .from('user_subscriptions')
          .select('tier')
          .eq('user_id', userId)
          .maybeSingle();

      final tier = data?['tier'] as String? ?? 'free';
      debugPrint('Supabase subscription tier: $tier');
      return tier == 'premium';
    } catch (e) {
      debugPrint('Supabase subscription check error: $e');
      return false;
    }
  }

  // ─── Get offerings ───────────────────────────────────────

  static Future<Offerings?> getOfferings() async {
    if (!_initialized) await initialize();
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('getOfferings error: $e');
      return null;
    }
  }

  // ─── Purchase a package ──────────────────────────────────

  static Future<bool> purchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      final info = await Purchases.getCustomerInfo();
      final isActive =
          info.entitlements.all[entitlementId]?.isActive ?? false;

      if (isActive) {
        await _syncEntitlementToSupabase(info);
      }
      return isActive;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase cancelled');
        return false;
      }
      debugPrint('Purchase error: $errorCode — $e');
      rethrow;
    }
  }

  // ─── Restore purchases ──────────────────────────────────

  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final isActive =
          info.entitlements.all[entitlementId]?.isActive ?? false;
      await _syncEntitlementToSupabase(info);
      return isActive;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  // ─── Show native RevenueCat paywall ──────────────────────

  static Future<bool> showPaywall() async {
    try {
      final result = await RevenueCatUI.presentPaywall();
      debugPrint('Paywall result: $result');

      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        final info = await Purchases.getCustomerInfo();
        await _syncEntitlementToSupabase(info);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('showPaywall error: $e');
      return false;
    }
  }

  static Future<bool> showPaywallIfNeeded() async {
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(entitlementId);
      debugPrint('PaywallIfNeeded result: $result');
      return result == PaywallResult.purchased ||
          result == PaywallResult.restored;
    } catch (e) {
      debugPrint('showPaywallIfNeeded error: $e');
      return false;
    }
  }

  // ─── Show Customer Center (manage subscription) ──────────

  static Future<void> showCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint('CustomerCenter error: $e');
    }
  }

  // ─── Sync to Supabase ────────────────────────────────────

  static Future<void> _syncEntitlementToSupabase(
      CustomerInfo info) async {
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) return;

      final entitlement = info.entitlements.all[entitlementId];
      String tier = 'free';

      if (entitlement?.isActive == true) {
        tier = 'premium';
      }

      await SupabaseService.client.from('user_subscriptions').upsert({
        'user_id': userId,
        'tier': tier,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint('Synced tier "$tier" to Supabase for $userId');
    } catch (e) {
      debugPrint('Sync tier error: $e');
    }
  }
}

// ─── Data class ─────────────────────────────────────────────

class SubscriptionStatus {
  final String tier;
  final bool isActive;
  final String? productId;
  final DateTime? expirationDate;
  final bool isTrial;
  final bool willRenew;
  final bool isLifetime;

  SubscriptionStatus({
    required this.tier,
    required this.isActive,
    this.productId,
    this.expirationDate,
    this.isTrial = false,
    this.willRenew = false,
    this.isLifetime = false,
  });

  factory SubscriptionStatus.free() =>
      SubscriptionStatus(tier: 'free', isActive: false);

  bool get isFree => tier == 'free';
  bool get isPremium => isActive;
  String get tierLabel {
    if (isLifetime) return 'Lifetime';
    if (isTrial) return 'Trial Premium';
    switch (tier) {
      case 'premium':
        return 'Premium';
      default:
        return 'Darmowy';
    }
  }
}

// ─── Riverpod providers ─────────────────────────────────────

final revenueCatStatusProvider =
    FutureProvider<SubscriptionStatus>((ref) async {
  return await RevenueCatService.getStatus();
});

final revenueCatOfferingsProvider =
    FutureProvider<Offerings?>((ref) async {
  return await RevenueCatService.getOfferings();
});
