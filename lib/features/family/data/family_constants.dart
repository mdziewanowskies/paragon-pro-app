/// Single source of truth for the validation rules and limits the
/// backend enforces — duplicated client-side so we can fail fast
/// before round-tripping to Supabase.
class FamilyConstants {
  FamilyConstants._();

  static const int sizeLimit = 5;
  static const int emailMaxLen = 255;
  static const int usernameMinLen = 3;
  static const int usernameMaxLen = 32;

  static final RegExp emailRe =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp usernameRe =
      RegExp(r'^[a-zA-Z0-9_.\-]+$');

  /// Returns null when valid, otherwise a Polish error string.
  static String? validateInviteEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'Podaj adres email.';
    if (trimmed.length > emailMaxLen) {
      return 'Adres email jest zbyt długi (max $emailMaxLen znaków).';
    }
    if (!emailRe.hasMatch(trimmed)) {
      return 'Nieprawidłowy format adresu email.';
    }
    return null;
  }

  static String? validateUsername(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'Podaj nazwę użytkownika.';
    if (trimmed.length < usernameMinLen) {
      return 'Nazwa użytkownika musi mieć min. $usernameMinLen znaki.';
    }
    if (trimmed.length > usernameMaxLen) {
      return 'Nazwa użytkownika musi mieć max. $usernameMaxLen znaków.';
    }
    if (!usernameRe.hasMatch(trimmed)) {
      return 'Nazwa może zawierać tylko litery, cyfry i znaki _ . -';
    }
    return null;
  }
}

/// Display name + initials helpers — keep the same anonymization rules
/// the web spec calls out ('Anna K.' shape).
class FamilyDisplay {
  FamilyDisplay._();

  static String displayName({
    String? firstName,
    String? lastName,
    String? username,
  }) {
    final f = (firstName ?? '').trim();
    final l = (lastName ?? '').trim();
    if (f.isNotEmpty && l.isNotEmpty) return '$f ${l[0]}.';
    if (f.isNotEmpty) return f;
    if (username != null && username.trim().isNotEmpty) return username.trim();
    return 'Członek rodziny';
  }

  static String initials({
    String? firstName,
    String? lastName,
    String? username,
  }) {
    final f = (firstName ?? '').trim();
    final l = (lastName ?? '').trim();
    if (f.isNotEmpty && l.isNotEmpty) {
      return '${f[0]}${l[0]}'.toUpperCase();
    }
    if (f.length >= 2) return f.substring(0, 2).toUpperCase();
    if (f.isNotEmpty) return f.toUpperCase();
    if (username != null && username.trim().length >= 2) {
      return username.trim().substring(0, 2).toUpperCase();
    }
    return '??';
  }
}
