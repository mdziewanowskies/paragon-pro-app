import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/supabase_service.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/subscription/presentation/screens/paywall_screen.dart';
import '../../features/receipts/presentation/screens/receipt_grid_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/smooth_page_transition.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = SupabaseService.auth.currentUser;
      final isAuth = user != null;
      final isOnAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/onboarding';

      if (!isAuth && !isOnAuth) return '/onboarding';
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
        path: '/profile-setup',
        pageBuilder: (context, state) =>
            smoothPage(child: const ProfileSetupScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            smoothPage(child: const DashboardScreen()),
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
  );
});
