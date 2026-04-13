class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email jest wymagany';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Podaj prawidłowy adres email';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Hasło jest wymagane';
    }
    if (value.length < 6) {
      return 'Hasło musi mieć minimum 6 znaków';
    }
    return null;
  }

  static String? required(String? value, [String fieldName = 'Pole']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName jest wymagane';
    }
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nazwa użytkownika jest wymagana';
    }
    if (value.length < 3) {
      return 'Minimum 3 znaki';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Tylko litery, cyfry i podkreślenia';
    }
    return null;
  }

  static String? postalCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kod pocztowy jest wymagany';
    }
    final postalRegex = RegExp(r'^\d{2}-\d{3}$');
    if (!postalRegex.hasMatch(value)) {
      return 'Format: XX-XXX';
    }
    return null;
  }

  static String? nip(String? value) {
    if (value == null || value.isEmpty) {
      return 'NIP jest wymagany';
    }
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) {
      return 'NIP musi mieć 10 cyfr';
    }
    return null;
  }
}
