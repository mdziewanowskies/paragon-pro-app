import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase auth exceptions to a single Polish business-friendly
/// message. Use this instead of touching exception fields directly so
/// every screen shows the same copy and errors get added in one place.
class AuthErrorMapper {
  AuthErrorMapper._();

  static String message(Object error) {
    // Strongly-typed cases first.
    if (error is AuthWeakPasswordException) {
      if (error.reasons.contains('pwned')) {
        return 'To hasło pojawiło się w znanych wyciekach z innych serwisów '
            'i nie jest bezpieczne. Wybierz inne, najlepiej unikalne hasło.';
      }
      return 'Hasło jest zbyt słabe. Użyj co najmniej 8 znaków, mieszając '
          'wielkie i małe litery, cyfry i symbole.';
    }

    if (error is AuthApiException) {
      switch (error.code) {
        case 'email_not_confirmed':
          return 'Twoje konto nie jest jeszcze aktywne. Sprawdź skrzynkę '
              'pocztową i kliknij link potwierdzający, którego do Ciebie '
              'wysłaliśmy.';
        case 'invalid_credentials':
          return 'Nieprawidłowy email lub hasło.';
        case 'user_already_exists':
        case 'email_exists':
          return 'Konto z tym adresem email już istnieje. Zaloguj się '
              'lub użyj opcji „Zapomniałeś hasła?".';
        case 'over_email_send_rate_limit':
          return 'Zbyt wiele prób w krótkim czasie. Odczekaj kilka minut '
              'i spróbuj ponownie.';
        case 'signup_disabled':
          return 'Rejestracja jest aktualnie wyłączona. Spróbuj później.';
        case 'email_address_invalid':
        case 'validation_failed':
          return 'Podany adres email jest nieprawidłowy.';
        case 'user_not_found':
          return 'Nie znaleźliśmy konta o podanym adresie email.';
        case 'same_password':
          return 'Nowe hasło musi się różnić od dotychczasowego.';
      }
      // Fallback by message text — Supabase doesn't always set `code`.
      final msg = error.message.toLowerCase();
      if (msg.contains('rate limit')) {
        return 'Zbyt wiele prób w krótkim czasie. Odczekaj kilka minut '
            'i spróbuj ponownie.';
      }
      if (msg.contains('already registered') ||
          msg.contains('already exists')) {
        return 'Konto z tym adresem email już istnieje.';
      }
    }

    // Network / connectivity.
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('connection') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable')) {
      return 'Brak połączenia z serwerem. Sprawdź internet i spróbuj ponownie.';
    }
    if (raw.contains('timeout')) {
      return 'Serwer nie odpowiedział w wyznaczonym czasie. Spróbuj ponownie.';
    }

    // OAuth / external-browser failures (no specific Supabase code).
    if (raw.contains('could not launch') ||
        raw.contains('no_browser') ||
        raw.contains('cannot launch')) {
      return 'Nie udało się otworzyć okna logowania. Sprawdź czy masz '
          'zainstalowaną przeglądarkę i spróbuj ponownie.';
    }
    if (raw.contains('oauth') || raw.contains('provider')) {
      return 'Logowanie zewnętrzne chwilowo niedostępne. Spróbuj ponownie '
          'lub użyj loginu hasłem.';
    }

    return 'Coś poszło nie tak. Spróbuj ponownie później.';
  }
}
