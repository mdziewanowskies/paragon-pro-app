import 'package:flutter_test/flutter_test.dart';
import 'package:paragon_pro/core/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.resolveForTest', () {
    test('receipt universal link → /receipts', () {
      expect(
        DeepLinkService.resolveForTest(
            Uri.parse('https://paragonpro.app/receipt/abc123')),
        '/receipts',
      );
    });

    test('warranty universal link → /', () {
      expect(
        DeepLinkService.resolveForTest(
            Uri.parse('https://paragonpro.app/warranty/abc123')),
        '/',
      );
    });

    test('invite link forwards the code', () {
      expect(
        DeepLinkService.resolveForTest(
            Uri.parse('paragonpro://invite?code=XYZ789')),
        '/register?invite=XYZ789',
      );
    });

    test('paywall link → /pricing', () {
      expect(
        DeepLinkService.resolveForTest(
            Uri.parse('https://paragonpro.app/pricing')),
        '/pricing',
      );
    });

    test('Google OAuth callback ignored', () {
      expect(
        DeepLinkService.resolveForTest(Uri.parse(
            'com.googleusercontent.apps.123-abc:/oauth2redirect/google?code=abc')),
        isNull,
      );
    });

    test('Supabase auth callback ignored', () {
      expect(
        DeepLinkService.resolveForTest(
            Uri.parse('com.paragonpro.paragonpro://login-callback/')),
        isNull,
      );
    });

    test('unknown URLs return null', () {
      expect(
        DeepLinkService.resolveForTest(
            Uri.parse('https://paragonpro.app/unrelated')),
        isNull,
      );
    });
  });
}
