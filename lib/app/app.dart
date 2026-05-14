import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/notifications/data/realtime_listeners.dart';
import '../features/onboarding/first_login/first_login_splash.dart';
import 'router/app_router.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';

class ParagonProApp extends ConsumerWidget {
  const ParagonProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Boot Supabase Realtime channels for notifications + family
    // membership. Replaces 30s/60s polling — `notificationsProvider`
    // and `subscriptionProvider` get invalidated as rows change.
    ref.watch(realtimeListenersProvider);

    return MaterialApp.router(
      title: 'ParagonPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('pl', 'PL'),
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) {
        // Cap text scaling so users with extreme accessibility settings
        // don't shred the layout.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          // Wrap z SplashGate (cold-start gradient + logo na ~1.2s)
          // i FirstLoginGate (3s "Konfigurowanie..." po pierwszym
          // logowaniu). Oba zachowują się jak overlay'e — nie blokują
          // routera, tylko zasłaniają child dopóki nie skończą animacji.
          child: SplashGate(
            child: _FirstLoginGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

class _FirstLoginGate extends ConsumerWidget {
  final Widget child;
  const _FirstLoginGate({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(firstLoginSplashProvider);
    return Stack(
      children: [
        child,
        if (active)
          Positioned.fill(
            child: FirstLoginSplash(
              onDone: () {
                ref.read(firstLoginSplashProvider.notifier).clear();
              },
            ),
          ),
      ],
    );
  }
}

/// Bouncing scroll physics on every platform + drag-with-mouse on web
/// for a uniformly smooth feel.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
