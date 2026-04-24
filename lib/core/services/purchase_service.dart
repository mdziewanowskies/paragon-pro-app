import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'supabase_service.dart';

// RevenueCat API keys — replace with your actual keys
const _revenueCatAppleKey = String.fromEnvironment(
  'REVENUECAT_APPLE_KEY',
  defaultValue: 'appl_YOUR_REVENUECAT_APPLE_API_KEY',
);
const _revenueCatGoogleKey = String.fromEnvironment(
  'REVENUECAT_GOOGLE_KEY',
  defaultValue: 'goog_YOUR_REVENUECAT_GOOGLE_API_KEY',
);

// Product identifiers (must match App Store Connect / Google Play Console)
class SubscriptionProducts {
  static const premiumMonthly = 'paragonpro_premium_monthly';
  static const premiumYearly = 'paragonpro_premium_yearly';
  static const familyMonthly = 'paragonpro_family_monthly';
  static const familyYearly = 'paragonpro_family_yearly';

  // Entitlement identifier in RevenueCat dashboard
  static const premiumEntitlement = 'premium';
  static const familyEntitlement = 'family';
}

class PurchaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? _revenueCatAppleKey
          : _revenueCatGoogleKey;

      // Link with Supabase user ID for webhook sync
      final userId = SupabaseService.auth.currentUser?.id;

      final config = PurchasesConfiguration(apiKey);
      if (userId != null) {
        config..appUserID = userId;
      }

      await Purchases.configure(config);
      _initialized = true;
      debugPrint('PurchaseService initialized');
    } catch (e) {
      debugPrint('PurchaseService init failed: $e');
    }
  }

  // ─── Get offerings (prices, products) ─────────────────────

  static Future<Offerings?> getOfferings() async {
    if (!_initialized) await initialize();
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('getOfferings error: $e');
      return null;
    }
  }

  // ─── Purchase ─────────────────────────────────────────────

  static Future<bool> purchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      final info = await Purchases.getCustomerInfo();
      final isPremium = info.entitlements.all[SubscriptionProducts.premiumEntitlement]?.isActive ?? false;
      final isFamily = info.entitlements.all[SubscriptionProducts.familyEntitlement]?.isActive ?? false;

      // Sync tier to Supabase
      if (isPremium || isFamily) {
        await _syncTierToSupabase(isFamily ? 'family' : 'premium');
      }

      return isPremium || isFamily;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase cancelled by user');
        return false;
      }
      debugPrint('Purchase error: $e');
      rethrow;
    }
  }

  // ─── Restore purchases ───────────────────────────────────

  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPremium = info.entitlements.all[SubscriptionProducts.premiumEntitlement]?.isActive ?? false;
      final isFamily = info.entitlements.all[SubscriptionProducts.familyEntitlement]?.isActive ?? false;

      if (isPremium || isFamily) {
        await _syncTierToSupabase(isFamily ? 'family' : 'premium');
        return true;
      }

      await _syncTierToSupabase('free');
      return false;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  // ─── Check current entitlements ───────────────────────────

  static Future<SubscriptionStatus> getStatus() async {
    if (!_initialized) await initialize();

    try {
      final info = await Purchases.getCustomerInfo();
      final premium = info.entitlements.all[SubscriptionProducts.premiumEntitlement];
      final family = info.entitlements.all[SubscriptionProducts.familyEntitlement];

      if (family?.isActive == true) {
        return SubscriptionStatus(
          tier: 'family',
          isActive: true,
          expirationDate: family?.expirationDate != null
              ? DateTime.tryParse(family!.expirationDate!)
              : null,
          isTrial: family?.periodType == PeriodType.trial,
          willRenew: family?.willRenew ?? false,
        );
      }

      if (premium?.isActive == true) {
        return SubscriptionStatus(
          tier: 'premium',
          isActive: true,
          expirationDate: premium?.expirationDate != null
              ? DateTime.tryParse(premium!.expirationDate!)
              : null,
          isTrial: premium?.periodType == PeriodType.trial,
          willRenew: premium?.willRenew ?? false,
        );
      }

      return SubscriptionStatus(tier: 'free', isActive: false);
    } catch (e) {
      debugPrint('getStatus error: $e');
      return SubscriptionStatus(tier: 'free', isActive: false);
    }
  }

  // ─── Sync to Supabase ────────────────────────────────────

  static Future<void> _syncTierToSupabase(String tier) async {
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) return;

      // Upsert user_subscriptions
      await SupabaseService.client.from('user_subscriptions').upsert({
        'user_id': userId,
        'tier': tier,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint('Synced tier "$tier" to Supabase');
    } catch (e) {
      debugPrint('Sync tier error: $e');
    }
  }
}

class SubscriptionStatus {
  final String tier;
  final bool isActive;
  final DateTime? expirationDate;
  final bool isTrial;
  final bool willRenew;

  SubscriptionStatus({
    required this.tier,
    required this.isActive,
    this.expirationDate,
    this.isTrial = false,
    this.willRenew = false,
  });

  bool get isFree => tier == 'free';
  bool get isPremium => tier == 'premium' || tier == 'family';
  bool get isFamily => tier == 'family';
}

// ─── Riverpod providers ─────────────────────────────────────

final purchaseStatusProvider =
    FutureProvider<SubscriptionStatus>((ref) async {
  return await PurchaseService.getStatus();
});

final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  return await PurchaseService.getOfferings();
});
