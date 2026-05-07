import 'dart:developer' as developer;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/utils/auth_error_mapper.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _termsAccepted = false;
  bool _termsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final formValid = _formKey.currentState!.validate();
    final termsValid = _termsAccepted;
    setState(() => _termsError = !termsValid);
    if (!formValid || !termsValid) {
      Haptics.error();
      return;
    }
    Haptics.tap();
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      Haptics.success();
      AnalyticsService.signupSuccess();
      if (mounted) {
        // Email confirmation is required before login. Hand the user
        // off to the verify screen rather than profile setup — it will
        // auto-forward once Supabase signs them in via deep link.
        final email = Uri.encodeQueryComponent(
            _emailController.text.trim());
        context.go('/verify-email?email=$email');
      }
    } catch (e, stackTrace) {
      debugPrint('=== REGISTER ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      developer.log('Register failed',
          error: e, stackTrace: stackTrace, name: 'Auth');
      if (mounted) _showErrorDialog(AuthErrorMapper.message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Nie udało się utworzyć konta')),
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

  void _showInProgressDoc(String name) {
    Haptics.tap();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, size: 22, color: Colors.amber),
            SizedBox(width: 10),
            Expanded(child: Text('Dokument w opracowaniu')),
          ],
        ),
        content: Text(
          '$name jest aktualnie przygotowywany przez nasz zespół prawny '
          'i będzie dostępny w aplikacji wkrótce. Tworząc konto akceptujesz '
          'jego końcową wersję — opublikujemy ją tu zanim wejdzie w życie.',
        ),
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
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.heroGradient),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: _Blob(
                color: Colors.white.withValues(alpha: 0.18), size: 280),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _Blob(
                color: Colors.black.withValues(alpha: 0.18), size: 220),
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
                        'Załóż konto',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Zacznij ogarniać paragony w 60 sekund',
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
                                    AutofillHints.email,
                                    AutofillHints.username,
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
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'Min. 8 znaków',
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded),
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
                              const SizedBox(height: 16),
                              _LabeledField(
                                label: 'Potwierdź hasło',
                                child: TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  onFieldSubmitted: (_) => _register(),
                                  decoration: InputDecoration(
                                    hintText: 'Powtórz hasło',
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureConfirm
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm =
                                              !_obscureConfirm),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value !=
                                        _passwordController.text) {
                                      return 'Hasła nie są identyczne';
                                    }
                                    return Validators.password(value);
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _TermsCheckbox(
                                value: _termsAccepted,
                                error: _termsError,
                                onChanged: (v) => setState(() {
                                  _termsAccepted = v;
                                  if (v) _termsError = false;
                                }),
                                onLinkTap: _showInProgressDoc,
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _register,
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
                                          'Załóż konto',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Masz już konto?',
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

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final bool error;
  final ValueChanged<bool> onChanged;
  final void Function(String docName) onLinkTap;

  const _TermsCheckbox({
    required this.value,
    required this.error,
    required this.onChanged,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = TextStyle(
      fontSize: 12.5,
      height: 1.4,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
    );
    final link = TextStyle(
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: error
            ? AppColors.lightDestructive.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: error
              ? AppColors.lightDestructive.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: RichText(
                text: TextSpan(
                  style: base,
                  children: [
                    const TextSpan(text: 'Akceptuję '),
                    TextSpan(
                      text: 'Regulamin',
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => onLinkTap('Regulamin'),
                    ),
                    const TextSpan(text: ' oraz '),
                    TextSpan(
                      text: 'Politykę Prywatności',
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            onLinkTap('Polityka Prywatności'),
                    ),
                    const TextSpan(text: ' ParagonPro.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
