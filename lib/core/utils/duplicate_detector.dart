import 'dart:math';

/// Lightweight duplicate detection for free-text record fingerprints.
///
/// Used by the warranty creation flow (F1-T1) to flag near-identical
/// products before insert, but it's intentionally generic — pass any
/// pair of strings.
class DuplicateDetector {
  DuplicateDetector._();

  /// Lowercases and strips everything that isn't a letter or digit.
  /// '  Z 7930 EnBeeS!! ' -> 'z7930enbees'.
  static String normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Levenshtein edit distance between two strings.
  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final m = a.length;
    final n = b.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1, // insertion
          prev[j] + 1, // deletion
          prev[j - 1] + cost, // substitution
        ].reduce(min);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  /// Extract serial-number-like tokens — alphanumeric runs at least 4
  /// chars long that mix digits and letters (e.g. 'Z7930', 'SN12345').
  static Set<String> extractSerialTokens(String input) {
    final result = <String>{};
    final pattern = RegExp(r'[A-Za-z0-9]{4,}');
    for (final m in pattern.allMatches(input)) {
      final token = m.group(0)!;
      final hasDigit = token.contains(RegExp(r'\d'));
      final hasLetter = token.contains(RegExp(r'[A-Za-z]'));
      if (hasDigit && hasLetter) {
        result.add(token.toUpperCase());
      }
    }
    return result;
  }

  /// Returns true when [a] and [b] should be treated as duplicates:
  /// either Levenshtein distance ≤ [maxDistance] on normalized text,
  /// or they share at least one serial-like token.
  static bool isDuplicate(
    String a,
    String b, {
    int maxDistance = 2,
  }) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (distance(na, nb) <= maxDistance) return true;

    final sa = extractSerialTokens(a);
    final sb = extractSerialTokens(b);
    return sa.intersection(sb).isNotEmpty;
  }
}
