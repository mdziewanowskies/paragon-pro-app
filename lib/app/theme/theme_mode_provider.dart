import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V3 motyw aplikacji — `system` (śledzi OS), `light` lub `dark`.
/// Persystowane w SharedPreferences pod `app.theme_mode`. Domyślny
/// tryb: `system` żeby Apple/Google reviewerzy widzieli zgodność
/// z OS preference.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _prefsKey = 'app.theme_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = _decode(raw);
    } catch (_) {
      // Jeśli SharedPreferences nie wstaje (rare iOS edge case na
      // pierwszym uruchomieniu) — zostajemy z system default.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(mode));
    } catch (_) {
      // Persist fail nie psuje user experience — motyw zadziała w
      // ramach sesji, zresetuje się przy kolejnym starcie.
    }
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  static ThemeMode _decode(String raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
