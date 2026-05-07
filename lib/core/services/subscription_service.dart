import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_service.dart';
import 'supabase_service.dart';

/// Where the user's effective tier comes from. `own` = they bought
/// it themselves; `family` = they're a member of a Premium admin's
/// family and were auto-upgraded to Family Lite.
enum SubscriptionSource { own, family }

class SubscriptionInfo {
  static const tierFree = 'free';
  static const tierFamilyLite = 'family_lite';
  static const tierPremium = 'premium';

  final String tier;
  final SubscriptionSource source;
  final int maxReceiptsPerMonth;
  final bool aiFeaturesEnabled;
  final bool familySharingEnabled;
  final bool advancedAnalytics;
  final bool prioritySupport;
  final int currentMonthReceipts;

  SubscriptionInfo({
    required this.tier,
    this.source = SubscriptionSource.own,
    required this.maxReceiptsPerMonth,
    required this.aiFeaturesEnabled,
    required this.familySharingEnabled,
    required this.advancedAnalytics,
    required this.prioritySupport,
    required this.currentMonthReceipts,
  });

  // -1 means unlimited
  bool get canUpload =>
      maxReceiptsPerMonth < 0 || currentMonthReceipts < maxReceiptsPerMonth;
  bool get isUnlimited => maxReceiptsPerMonth < 0;
  double get usagePercentage => maxReceiptsPerMonth > 0
      ? currentMonthReceipts / maxReceiptsPerMonth
      : 0;

  bool get isFree => tier == tierFree;
  bool get isFamilyLite => tier == tierFamilyLite;
  bool get isPremium => tier == tierPremium;

  /// True when the user has any non-Free tier benefits — covers both
  /// Family Lite (inherited) and Premium (own purchase).
  bool get hasAnyTierPerks => !isFree;

  /// Inherited from family admin's Premium subscription rather than
  /// purchased by this user.
  bool get isInheritedFromFamily => source == SubscriptionSource.family;

  String get tierLabel {
    switch (tier) {
      case tierPremium:
        return 'Premium';
      case tierFamilyLite:
        return 'Family Lite';
      default:
        return 'Darmowy';
    }
  }

  factory SubscriptionInfo.free({int currentReceipts = 0}) {
    return SubscriptionInfo(
      tier: tierFree,
      maxReceiptsPerMonth: 5,
      aiFeaturesEnabled: false,
      familySharingEnabled: false,
      advancedAnalytics: false,
      prioritySupport: false,
      currentMonthReceipts: currentReceipts,
    );
  }
}

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionInfo>(
        SubscriptionNotifier.new);

class SubscriptionNotifier extends AsyncNotifier<SubscriptionInfo> {
  Timer? _refreshTimer;
  StreamSubscription? _authSub;

  @override
  Future<SubscriptionInfo> build() async {
    // Re-fetch the effective tier every 60s so that backend events
    // we don't get a push for (family removal, premium expiry) still
    // settle in the UI within a minute.
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => refresh(),
    );
    // Auth changes (login / logout) also force a fresh tier read.
    _authSub?.cancel();
    _authSub = SupabaseService.auth.onAuthStateChange.listen((_) {
      refresh();
    });
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _authSub?.cancel();
    });

    final user = SupabaseService.auth.currentUser;
    if (user == null) return SubscriptionInfo.free();
    return await _fetchSubscription(user.id);
  }

  Future<SubscriptionInfo> _fetchSubscription(String userId) async {
    try {
      // Authoritative source: backend RPC computes the effective tier
      // including Family Lite inheritance from a Premium admin's family.
      // Falls back to user_subscriptions if the RPC is unavailable.
      String effectiveTier = SubscriptionInfo.tierFree;
      var source = SubscriptionSource.own;
      try {
        final result = await SupabaseService.rpc(
          'get_effective_tier',
          params: {'_user_id': userId},
        );
        if (result is String && result.isNotEmpty) {
          effectiveTier = result;
        }
      } catch (_) {
        // RPC not deployed yet — fall through to direct read.
      }

      // Direct read of the user's own row to detect inheritance.
      final ownRow = await SupabaseService.client
          .from('user_subscriptions')
          .select('tier')
          .eq('user_id', userId)
          .maybeSingle();
      final ownTier = ownRow?['tier'] as String? ?? SubscriptionInfo.tierFree;

      // If the RPC said family_lite but the user's own tier is free,
      // they're inheriting from a Premium admin.
      if (effectiveTier == SubscriptionInfo.tierFamilyLite &&
          ownTier == SubscriptionInfo.tierFree) {
        source = SubscriptionSource.family;
      }

      // If the RPC was unavailable, just use the user's own tier.
      if (effectiveTier == SubscriptionInfo.tierFree && ownTier != SubscriptionInfo.tierFree) {
        effectiveTier = ownTier;
      }

      // Get limits for the resolved tier.
      final limits = await SupabaseService.client
          .from('subscription_limits')
          .select()
          .eq('tier', effectiveTier)
          .maybeSingle();

      // Get current month receipt count.
      final count = await SupabaseService.rpc(
        'count_user_receipts_this_month',
        params: {'_user_id': userId},
      );

      // Tag the user for segmentation. Firing here means every refresh
      // re-asserts the property — cheap, idempotent.
      AnalyticsService.setUserProperty('subscription_tier', effectiveTier);
      AnalyticsService.setUserProperty(
          'subscription_source', source.name);

      return SubscriptionInfo(
        tier: effectiveTier,
        source: source,
        maxReceiptsPerMonth:
            limits?['max_receipts_per_month'] as int? ?? 10,
        aiFeaturesEnabled:
            limits?['ai_features_enabled'] as bool? ?? false,
        familySharingEnabled:
            limits?['family_sharing_enabled'] as bool? ?? false,
        advancedAnalytics:
            limits?['advanced_analytics'] as bool? ?? false,
        prioritySupport:
            limits?['priority_support'] as bool? ?? false,
        currentMonthReceipts: count as int? ?? 0,
      );
    } catch (_) {
      return SubscriptionInfo.free();
    }
  }

  Future<void> refresh() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      state = AsyncData(SubscriptionInfo.free());
      return;
    }
    state = AsyncData(await _fetchSubscription(user.id));
  }
}
