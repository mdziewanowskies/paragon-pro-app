import 'package:flutter_test/flutter_test.dart';
import 'package:paragon_pro/core/services/subscription_service.dart';

void main() {
  SubscriptionInfo make({
    required String tier,
    int monthly = 0,
    int max = 5,
    bool ai = false,
    bool family = false,
    bool analytics = false,
    SubscriptionSource source = SubscriptionSource.own,
  }) {
    return SubscriptionInfo(
      tier: tier,
      source: source,
      maxReceiptsPerMonth: max,
      aiFeaturesEnabled: ai,
      familySharingEnabled: family,
      advancedAnalytics: analytics,
      prioritySupport: false,
      currentMonthReceipts: monthly,
    );
  }

  group('SubscriptionInfo tier flags', () {
    test('free is free', () {
      final s = make(tier: 'free');
      expect(s.isFree, isTrue);
      expect(s.isFamilyLite, isFalse);
      expect(s.isPremium, isFalse);
      expect(s.hasAnyTierPerks, isFalse);
      expect(s.tierLabel, 'Darmowy');
    });

    test('family_lite is its own thing', () {
      final s = make(
        tier: 'family_lite',
        max: 15,
        family: true,
        source: SubscriptionSource.family,
      );
      expect(s.isFree, isFalse);
      expect(s.isFamilyLite, isTrue);
      expect(s.isPremium, isFalse);
      expect(s.hasAnyTierPerks, isTrue);
      expect(s.isInheritedFromFamily, isTrue);
      expect(s.tierLabel, 'Family Lite');
    });

    test('premium is premium', () {
      final s = make(
        tier: 'premium',
        max: -1,
        ai: true,
        family: true,
        analytics: true,
      );
      expect(s.isPremium, isTrue);
      expect(s.isFamilyLite, isFalse);
      expect(s.hasAnyTierPerks, isTrue);
      expect(s.isInheritedFromFamily, isFalse);
      expect(s.tierLabel, 'Premium');
    });
  });

  group('SubscriptionInfo upload limits', () {
    test('free: 5 monthly cap, blocks at 5', () {
      final s = make(tier: 'free', max: 5, monthly: 5);
      expect(s.canUpload, isFalse);
    });

    test('family_lite: 15 monthly cap, allows up to 14', () {
      final under =
          make(tier: 'family_lite', max: 15, monthly: 14, family: true);
      final at = make(tier: 'family_lite', max: 15, monthly: 15, family: true);
      expect(under.canUpload, isTrue);
      expect(at.canUpload, isFalse);
    });

    test('premium: unlimited never blocks', () {
      final s = make(tier: 'premium', max: -1, monthly: 9999);
      expect(s.canUpload, isTrue);
      expect(s.isUnlimited, isTrue);
    });
  });

  group('SubscriptionInfo factory', () {
    test('SubscriptionInfo.free defaults are free-tier shaped', () {
      final s = SubscriptionInfo.free();
      expect(s.tier, 'free');
      expect(s.source, SubscriptionSource.own);
      expect(s.maxReceiptsPerMonth, 5);
      expect(s.familySharingEnabled, isFalse);
      expect(s.aiFeaturesEnabled, isFalse);
    });
  });
}
