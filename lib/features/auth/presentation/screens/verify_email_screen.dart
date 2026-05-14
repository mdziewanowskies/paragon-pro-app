import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/auth_error_mapper.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../onboarding/first_login/first_login_splash.dart';

/// Shown after a successful sign-up. Tells the user to confirm their
/// email + offers Resend / Open mail / Change email actions. When the
/// confirmation link in the email is tapped, Supabase routes back to
/// the app via the deep-link callback and a session lands on
/// auth.onAuthStateChange — at which point we navigate forward.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _resendCooldown = Duration(seconds: 30);

  StreamSubscription? _authSub;
  bool _resending = false;
  DateTime? _lastResend;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Auto-forward as soon as the user confirms the email and the
    // session shows up via deep-link callback.
    _authSub = SupabaseService.auth.onAuthStateChange.listen((event) async {
      if (!mounted) return;
      if (event.event == AuthChangeEvent.signedIn ||
          SupabaseService.auth.currentUser != null) {
        Haptics.success();
        // Sprint 2: konfigurujemy splash dla nowego usera po email
        // verify → session arrival.
        await ref.read(firstLoginSplashProvider.notifier).trigger();
        if (mounted) context.go('/profile-setup');
      }
    });
    // Tick once a second to refresh the resend cooldown countdown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _lastResend != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _cooldownLeft {
    if (_lastResend == null) return Duration.zero;
    final passed = DateTime.now().difference(_lastResend!);
    final left = _resendCooldown - passed;
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _resend() async {
    if (_cooldownLeft > Duration.zero || _resending) return;
    Haptics.tap();
    setState(() => _resending = true);
    try {
      await ref
          .read(authServiceProvider)
          .resendSignupConfirmation(widget.email);
      _lastResend = DateTime.now();
      Haptics.success();
      if (!mounted) return;
      AppSnack.show(
        context,
        'Wysłaliśmy nowy link na ${widget.email}',
        kind: SnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.show(
        context,
        AuthErrorMapper.message(e),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _openMail() async {
    Haptics.tap();
    final uri = Uri.parse('mailto:');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppSnack.show(
        context,
        'Nie udało się otworzyć aplikacji pocztowej',
        kind: SnackKind.warning,
      );
    }
  }

  void _changeEmail() {
    Haptics.tap();
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cooldown = _cooldownLeft.inSeconds;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.heroGradient),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 56),
                      const SizedBox(height: 14),
                      Text(
                        'Sprawdź email',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aktywuj konto, by zacząć korzystać z aplikacji',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.mediumShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mark_email_unread_rounded,
                                  color: Colors.amber,
                                  size: 38,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Wysłaliśmy link aktywacyjny na adres:',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.email,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Kliknij link w wiadomości, aby aktywować '
                              'konto. Sprawdź też folder spam.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _openMail,
                                icon: const Icon(Icons.mail_rounded,
                                    size: 18),
                                label: const Text('Otwórz pocztę'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: cooldown > 0 || _resending
                                    ? null
                                    : _resend,
                                icon: _resending
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded,
                                        size: 18),
                                label: Text(
                                  cooldown > 0
                                      ? 'Wyślij ponownie (${cooldown}s)'
                                      : 'Wyślij ponownie',
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _changeEmail,
                              child: const Text(
                                'Wpisałem zły email — wróć do rejestracji',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Już aktywowałeś konto?',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Zaloguj się',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

