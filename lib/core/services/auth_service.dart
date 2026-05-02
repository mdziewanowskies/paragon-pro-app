import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.auth.currentUser;
});

class AuthService {
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await SupabaseService.auth.signUp(
      email: email,
      password: password,
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

  Future<AuthResponse?> signInWithGoogle() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Use Supabase signInWithOAuth on web; this method is mobile-only.',
      );
    }

    if (AppConstants.googleWebClientId.isEmpty) {
      throw StateError(
        'GOOGLE_WEB_CLIENT_ID not configured. Pass via --dart-define.',
      );
    }

    final googleSignIn = GoogleSignIn(
      clientId: Platform.isIOS && AppConstants.googleIosClientId.isNotEmpty
          ? AppConstants.googleIosClientId
          : null,
      serverClientId: AppConstants.googleWebClientId,
      scopes: const ['email', 'profile', 'openid'],
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw StateError('Google Sign-In returned no ID token');
    }

    return await SupabaseService.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<AuthResponse?> signInWithApple() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Use Supabase signInWithOAuth on web; this method is mobile-only.',
      );
    }
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError(
        'Sign in with Apple is only available on Apple platforms.',
      );
    }

    final rawNonce = _generateNonce();
    final hashedNonce =
        sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple Sign-In returned no ID token');
    }

    return await SupabaseService.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await SupabaseService.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await SupabaseService.auth.resetPasswordForEmail(email);
  }

  User? get currentUser => SupabaseService.auth.currentUser;

  bool get isLoggedIn => currentUser != null;
}
