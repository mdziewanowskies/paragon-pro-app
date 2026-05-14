import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/profile_service.dart';
import '../../../onboarding/first_login/first_login_splash.dart';
import '../../../../core/utils/auth_error_mapper.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/google_sign_in_button.dart';
import '../widgets/forgot_password_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      Haptics.error();
      return;
    }
    Haptics.tap();
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      Haptics.success();
      AnalyticsService.loginSuccess('email');
      // Sprint 2: trigger "Konfigurujemy Twoją aplikację" splash dla
      // pierwszego logowania. No-op jeśli flaga już zapisana.
      await ref.read(firstLoginSplashProvider.notifier).trigger();
      await _navigatePostLogin();
    } catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigatePostLogin() async {
    if (!mounted) return;
    try {
      await ref.read(profileProvider.notifier).refresh();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final profile = ref.read(profileProvider).value;
    if (!mounted) return;
    if (profile == null || !profile.profileCompleted) {
      context.go('/profile-setup');
    } else {
      context.go('/');
    }
  }

  Future<void> _openForgotPassword() async {
    Haptics.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ForgotPasswordSheet(
        prefilledEmail: _emailController.text.trim(),
      ),
    );
  }

  void _handleAuthError(Object e, StackTrace stackTrace) {
    debugPrint('=== LOGIN ERROR ===');
    debugPrint('Error type: ${e.runtimeType}');
    debugPrint('Error: $e');
    debugPrint('Stack: $stackTrace');
    developer.log('Login failed', error: e, stackTrace: stackTrace, name: 'Auth');
    if (!mounted) return;
    final isUnconfirmed =
        e is AuthApiException && e.code == 'email_not_confirmed';
    if (isUnconfirmed) {
      // Send the user back to the verify screen instead of just toasting.
      context.go(
        '/verify-email?email=${Uri.encodeQueryComponent(_emailController.text.trim())}',
      );
      return;
    }
    _showErrorDialog(AuthErrorMapper.message(e));
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Nie udało się zalogować')),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // Ambient gradient background; the form sits on a clean card.
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.heroGradient),
            ),
          ),
          // Decorative blurred blobs.
          Positioned(
            top: -120,
            right: -80,
            child: _Blob(
              color: Colors.white.withValues(alpha: 0.18),
              size: 280,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _Blob(
              color: Colors.black.withValues(alpha: 0.18),
              size: 220,
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
                      // ── Hero ───────────────────────────────────────
                      const AppLogo(size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Witaj z powrotem',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Zaloguj się, aby zarządzać swoimi paragonami',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Card ───────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.mediumShadow,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LabeledField(
                                label: 'Email',
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'twoj@email.pl',
                                    prefixIcon:
                                        Icon(Icons.alternate_email_rounded),
                                  ),
                                  validator: Validators.email,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _LabeledField(
                                label: 'Hasło',
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.password,
                                  ],
                                  onFieldSubmitted: (_) => _login(),
                                  decoration: InputDecoration(
                                    hintText: 'Twoje hasło',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded),
                                      onPressed: () => setState(() =>
                                          _obscurePassword =
                                              !_obscurePassword),
                                    ),
                                  ),
                                  validator: Validators.password,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Zapomniałeś hasła?'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Zaloguj się',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const OrDivider(),
                              const SizedBox(height: 16),
                              const GoogleSignInButton(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Register prompt ────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Nie masz konta?',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Zarejestruj się',
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

/// Field label rendered above the input — gives the form a more
/// settled, professional feel than relying purely on floating labels.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
