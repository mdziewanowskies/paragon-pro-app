import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.auth.currentUser;
});

class AuthService {
  /// Where every Supabase email link should send the user back.
  /// Registered as a CFBundleURLScheme in iOS Info.plist and as an
  /// intent filter in the Android manifest.
  static const _emailCallback =
      'com.paragonpro.paragonpro://login-callback/';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await SupabaseService.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _emailCallback,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await SupabaseService.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await AnalyticsService.setUserId(null);
    await SupabaseService.auth.signOut();
  }

  /// Sends a password reset email through Supabase. The link inside
  /// the email lands back on the app via [_emailCallback].
  Future<void> resetPassword(String email) async {
    await SupabaseService.auth.resetPasswordForEmail(
      email,
      redirectTo: _emailCallback,
    );
  }

  /// Resend the signup confirmation email — used on the verify screen
  /// when the user didn't get the original.
  Future<void> resendSignupConfirmation(String email) async {
    await SupabaseService.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: _emailCallback,
    );
  }

  User? get currentUser => SupabaseService.auth.currentUser;

  bool get isLoggedIn => currentUser != null;
}
