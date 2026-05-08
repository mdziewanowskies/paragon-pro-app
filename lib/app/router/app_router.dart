import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/deep_link_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/supabase_service.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/subscription/presentation/screens/paywall_screen.dart';
import '../../features/receipts/presentation/screens/receipt_grid_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/smooth_page_transition.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Supabase auth state changes into go_router's redirect cycle
  // so OAuth deep-link returns and email/pwd sign-in both navigate the
  // user out of /login automatically.
  final notifier = ValueNotifier<int>(0);
  final sub = SupabaseService.auth.onAuthStateChange.listen((_) {
    notifier.value++;
  });
  ref.onDispose(() {
    sub.cancel();
    notifier.dispose();
  });

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: (context, state) {
      final user = SupabaseService.auth.currentUser;
      final isAuth = user != null;
      final loc = state.matchedLocation;
      final isOnAuth = loc == '/login' ||
          loc == '/register' ||
          loc == '/onboarding';
      // /verify-email is a hybrid: you reach it without a session
      // (post-signup) and it self-navigates once the session lands.
      // Don't kick the unauth user off it, don't kick the auth user
      // off it either — the screen handles its own forward.
      final isVerify = loc == '/verify-email';

      if (!isAuth && !isOnAuth && !isVerify) return '/onboarding';
      if (isAuth && isOnAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            smoothPage(child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            smoothPage(child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            smoothPage(child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return smoothPage(child: VerifyEmailScreen(email: email));
        },
      ),
      GoRoute(
        path: '/profile-setup',
        pageBuilder: (context, state) =>
            smoothPage(child: const ProfileSetupScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) {
          // Push notifications and in-app deep links can land here with
          // ?tab=N to focus a specific bottom-nav destination. Keying
          // the page on the tab forces a rebuild when the query
          // changes, so /?tab=3 from any screen lands on warranties.
          final tab = int.tryParse(
              state.uri.queryParameters['tab'] ?? '');
          return smoothPage(
            key: tab != null ? ValueKey('home-tab-$tab') : null,
            child: DashboardScreen(initialTab: tab),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            smoothPage(child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            smoothPage(child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/pricing',
        pageBuilder: (context, state) =>
            smoothPage(child: const PaywallScreen()),
      ),
      GoRoute(
        path: '/receipts',
        pageBuilder: (context, state) =>
            smoothPage(child: const ReceiptGridScreen()),
      ),
    ],
  )
    ..let(DeepLinkService.attach)
    ..let((r) async => MessagingService.attachRouter(r));
});

extension on GoRouter {
  /// Tiny `let` so we can pipe the just-built router into
  /// service attach hooks without juggling a temp variable.
  GoRouter let(Future<void> Function(GoRouter) fn) {
    fn(this);
    return this;
  }
}
