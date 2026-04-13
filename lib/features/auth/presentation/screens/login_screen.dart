import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_logo.dart';

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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if profile is completed
      await ref.read(profileProvider.notifier).refresh();
      final profile = ref.read(profileProvider).value;

      if (mounted) {
        if (profile == null || !profile.profileCompleted) {
          context.go('/profile-setup');
        } else {
          context.go('/');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('=== LOGIN ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      developer.log('Login failed', error: e, stackTrace: stackTrace, name: 'Auth');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd logowania: ${_getErrorMessage(e)}'),
            backgroundColor: AppColors.lightDestructive,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(dynamic error) {
    final msg = error.toString();
    final msgLower = msg.toLowerCase();
    if (msgLower.contains('invalid login credentials') ||
        msgLower.contains('invalid_credentials')) {
      return 'Nieprawidłowy email lub hasło';
    }
    if (msgLower.contains('email not confirmed')) {
      return 'Potwierdź email przed logowaniem';
    }
    if (msgLower.contains('socketexception') || msgLower.contains('connection refused')) {
      return 'Brak połączenia z serwerem. Sprawdź internet.';
    }
    // In debug mode show full error
    if (kDebugMode) {
      return msg.length > 200 ? msg.substring(0, 200) : msg;
    }
    return 'Spróbuj ponownie później';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.mediumShadow,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 56),
                      const SizedBox(height: 12),
                      Text(
                        'Zaloguj się',
                        style:
                            Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Witaj z powrotem!',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Hasło',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Zaloguj się'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Nie masz konta? Zarejestruj się'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
