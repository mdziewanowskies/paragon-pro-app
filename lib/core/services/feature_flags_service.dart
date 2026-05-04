import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight feature-flag layer.
///
/// Until we wire up Firebase Remote Config / LaunchDarkly (deferred —
/// requires backend + dashboards), this service is purely client-side:
/// every active experiment gets a stable per-install bucket assignment
/// from [_PrefsKey]'s seeded RNG, which means a given user always
/// lands in the same arm across restarts.
///
/// Usage:
/// ```
/// final variant = await FeatureFlags.paywallVariant();
/// if (variant == PaywallVariant.trialFirst) { ... }
/// ```
///
/// To override during QA, set the env var via --dart-define=
/// PAYWALL_VARIANT=monthly_default | yearly_default | trial_first.
class FeatureFlags {
  FeatureFlags._();

  static SharedPreferences? _prefs;
  static const _bucketKey = 'feature_flags.install_bucket';

  static Future<int> _bucket() async {
    _prefs ??= await SharedPreferences.getInstance();
    final existing = _prefs!.getInt(_bucketKey);
    if (existing != null) return existing;
    final fresh = Random.secure().nextInt(1 << 30);
    await _prefs!.setInt(_bucketKey, fresh);
    return fresh;
  }

  /// Stable hash → variant assignment. [salt] keys the experiment,
  /// so flipping it forces a re-bucket if we ever need to redo a test.
  static Future<int> _arm(int armCount, {required String salt}) async {
    final bucket = await _bucket();
    final h = bucket ^ salt.hashCode;
    return h.abs() % armCount;
  }

  // ─── Experiments ────────────────────────────────────────────────────

  /// F3-T3: monthly default vs yearly default vs trial-first.
  static Future<PaywallVariant> paywallVariant() async {
    const override =
        String.fromEnvironment('PAYWALL_VARIANT', defaultValue: '');
    switch (override) {
      case 'monthly_default':
        return PaywallVariant.monthlyDefault;
      case 'yearly_default':
        return PaywallVariant.yearlyDefault;
      case 'trial_first':
        return PaywallVariant.trialFirst;
    }
    final arm =
        await _arm(PaywallVariant.values.length, salt: 'paywall_variant_v1');
    final variant = PaywallVariant.values[arm];
    if (kDebugMode) {
      debugPrint('FeatureFlags.paywallVariant → ${variant.name}');
    }
    return variant;
  }
}

enum PaywallVariant {
  /// Original behaviour — Monthly tab pre-selected.
  monthlyDefault,

  /// Yearly tab pre-selected (default of current production paywall).
  yearlyDefault,

  /// Skip plan selection initially — user sees only "Start 7-day free
  /// trial" CTA, picks plan after trial starts.
  trialFirst,
}
