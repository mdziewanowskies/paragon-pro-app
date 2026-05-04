import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
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

  /// Native Google sign-in via flutter_appauth (ASWebAuthenticationSession
  /// on iOS). Generates a raw nonce locally, hands the SHA-256 hash to
  /// Google as the `nonce` OAuth param, and forwards the raw value to
  /// Supabase so gotrue's hash check lines up. Returns null when the
  /// user cancels.
  Future<AuthResponse?> signInWithGoogle() async {
    if (kIsWeb) {
      await SupabaseService.auth.signInWithOAuth(OAuthProvider.google);
      return null; // browser handles the rest
    }

    final iosClientId = AppConstants.googleIosClientId;
    if (iosClientId.isEmpty || iosClientId.contains('REPLACE_WITH')) {
      throw StateError(
        'GOOGLE_IOS_CLIENT_ID not configured.',
      );
    }

    final rawNonce = _generateNonce();
    final hashedNonce =
        sha256.convert(utf8.encode(rawNonce)).toString();

    final redirectUrl = _googleIosRedirectUrl(iosClientId);

    const appAuth = FlutterAppAuth();

    AuthorizationTokenResponse? result;
    try {
      result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          iosClientId,
          redirectUrl,
          discoveryUrl:
              'https://accounts.google.com/.well-known/openid-configuration',
          scopes: const ['openid', 'email', 'profile'],
          nonce: hashedNonce,
          promptValues: const ['select_account'],
        ),
      );
    } catch (e) {
      // flutter_appauth wraps both user cancellation and other errors
      // in PlatformException. Treat user cancel as a non-error.
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('user_cancel')) {
        return null;
      }
      rethrow;
    }

    final idToken = result.idToken;
    final accessToken = result.accessToken;
    if (idToken == null) {
      throw StateError('Google Sign-In returned no ID token');
    }

    return await SupabaseService.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
      nonce: rawNonce,
    );
  }

  /// Builds Google's standard iOS OAuth redirect URI from the client ID.
  /// Format: com.googleusercontent.apps.<id>:/oauth2redirect/google
  /// The scheme half (com.googleusercontent.apps.<id>) must also exist
  /// as a CFBundleURLScheme in Info.plist.
  String _googleIosRedirectUrl(String iosClientId) {
    final reversed = iosClientId
        .replaceAll('.apps.googleusercontent.com', '');
    return 'com.googleusercontent.apps.$reversed:/oauth2redirect/google';
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
    await AnalyticsService.setUserId(null);
    await SupabaseService.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await SupabaseService.auth.resetPasswordForEmail(email);
  }

  User? get currentUser => SupabaseService.auth.currentUser;

  bool get isLoggedIn => currentUser != null;
}
