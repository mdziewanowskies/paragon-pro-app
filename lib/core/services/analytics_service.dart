import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics facade.
///
/// All event names follow the convention `<module>_<action>_<object>`
/// from the V3 plan, so a quick `git grep AnalyticsService.logEvent`
/// is enough to audit what we ship.
///
/// In debug builds events are echoed to stdout — drop them in Firebase
/// console DebugView while iterating.
class AnalyticsService {
  AnalyticsService._();

  static FirebaseAnalytics? _instance;
  static bool _initialized = false;

  static FirebaseAnalytics get _analytics {
    return _instance ??= FirebaseAnalytics.instance;
  }

  /// Wire up after Firebase.initializeApp(). Safe to call multiple times.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      // No-op if FirebaseApp.configure() failed earlier; we don't want
      // a missing GoogleService-Info.plist to crash the app boot path.
      _instance = FirebaseAnalytics.instance;
      await _analytics.setAnalyticsCollectionEnabled(true);
      _initialized = true;
    } catch (e) {
      debugPrint('AnalyticsService init failed: $e');
    }
  }

  /// Generic event. Pass a name in `module_action_object` shape.
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? params,
  }) async {
    if (kDebugMode) {
      debugPrint('analytics: $name ${params ?? ''}');
    }
    if (!_initialized) return;
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('analytics logEvent($name) failed: $e');
    }
  }

  /// Tag the current user once we know who they are. Pass null on logout.
  static Future<void> setUserId(String? id) async {
    if (!_initialized) return;
    try {
      await _analytics.setUserId(id: id);
    } catch (_) {}
  }

  static Future<void> setUserProperty(String name, String? value) async {
    if (!_initialized) return;
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (_) {}
  }

  // ─── Convenience wrappers for the events we already fire ────────────

  static Future<void> receiptAdded({bool aiProcessed = false}) =>
      logEvent('receipt_add_success',
          params: {'ai_processed': aiProcessed.toString()});

  static Future<void> receiptDeleted() => logEvent('receipt_delete_success');

  static Future<void> warrantyAdded({required int months}) =>
      logEvent('warranty_add_success', params: {'months': months});

  static Future<void> warrantyDuplicateBlocked() =>
      logEvent('warranty_duplicate_blocked');

  static Future<void> rankingEmptyStateShown() =>
      logEvent('ranking_empty_state_shown');

  static Future<void> challengeEmptyStateShown() =>
      logEvent('challenge_empty_state_shown');

  static Future<void> paywallShown({String? source}) =>
      logEvent('paywall_view',
          params: source != null ? {'source': source} : null);

  static Future<void> purchaseStarted(String productId) =>
      logEvent('purchase_start', params: {'product_id': productId});

  static Future<void> purchaseCompleted(String productId) =>
      logEvent('purchase_complete', params: {'product_id': productId});

  static Future<void> loginSuccess(String method) =>
      logEvent('auth_login_success', params: {'method': method});

  static Future<void> signupSuccess() => logEvent('auth_signup_success');

  static Future<void> onboardingPageShown(int pageIndex) =>
      logEvent('onboarding_page_view', params: {'page': pageIndex});

  static Future<void> onboardingCompleted() =>
      logEvent('onboarding_complete');
}
