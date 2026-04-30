import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';

class SubscriptionInfo {
  final String tier;
  final int maxReceiptsPerMonth;
  final bool aiFeaturesEnabled;
  final bool familySharingEnabled;
  final bool advancedAnalytics;
  final bool prioritySupport;
  final int currentMonthReceipts;

  SubscriptionInfo({
    required this.tier,
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
  bool get isFree => tier == 'free';
  bool get isPremium => tier == 'premium';

  factory SubscriptionInfo.free({int currentReceipts = 0}) {
    return SubscriptionInfo(
      tier: 'free',
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
  @override
  Future<SubscriptionInfo> build() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return SubscriptionInfo.free();
    return await _fetchSubscription(user.id);
  }

  Future<SubscriptionInfo> _fetchSubscription(String userId) async {
    try {
      // Get user subscription
      final sub = await SupabaseService.client
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final tier = sub?['tier'] as String? ?? 'free';

      // Get limits for tier
      final limits = await SupabaseService.client
          .from('subscription_limits')
          .select()
          .eq('tier', tier)
          .maybeSingle();

      // Get current month receipt count
      final count = await SupabaseService.rpc(
        'count_user_receipts_this_month',
        params: {'_user_id': userId},
      );

      return SubscriptionInfo(
        tier: tier,
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
