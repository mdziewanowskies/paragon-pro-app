import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/haptics.dart';
import '../../core/utils/auth_error_mapper.dart';
import 'app_snackbar.dart';

/// "Continue with Google" button. Triggers Supabase OAuth via the
/// Lovable-managed Google credentials — no client-side configuration
/// or Supabase Dashboard touchpoints required. The actual session
/// arrives asynchronously via `onAuthStateChange` and is handled by
/// the router.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() =>
      _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _loading = false;

  Future<void> _signIn() async {
    if (_loading) return;
    Haptics.tap();
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      // If the deep-link callback already established a session, the
      // signInWithOAuth Future may still throw on browser-dismissal
      // bookkeeping. Silence that — the user is logged in.
      if (ref.read(authServiceProvider).isLoggedIn) return;
      AppSnack.show(
        context,
        AuthErrorMapper.message(e),
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _loading ? null : _signIn,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          backgroundColor: theme.colorScheme.surface,
        ),
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/google_g.svg',
                    height: 20,
                    width: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Kontynuuj z Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Visual divider with a centered "lub" label — drops between the
/// primary email/password CTA and the social sign-in buttons.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.25);
    return Row(
      children: [
        Expanded(child: Divider(color: color, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'lub',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        Expanded(child: Divider(color: color, height: 1)),
      ],
    );
  }
}
