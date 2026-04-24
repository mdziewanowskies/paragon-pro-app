class MerchantNameNormalizer {
  MerchantNameNormalizer._();

  static const Map<String, String> _brandDictionary = {
    'lidl': 'Lidl',
    'biedronka': 'Biedronka',
    'żabka': 'Żabka',
    'zabka': 'Żabka',
    'zappka': 'Żabka',
    'kaufland': 'Kaufland',
    'auchan': 'Auchan',
    'carrefour': 'Carrefour',
    'dino': 'Dino',
    'aldi': 'Aldi',
    'media markt': 'Media Markt',
    'mediamarkt': 'Media Markt',
    'media expert': 'Media Expert',
    'mediaexpert': 'Media Expert',
    'x-kom': 'x-kom',
    'xkom': 'x-kom',
    'komputronik': 'Komputronik',
    'ispot': 'iSpot',
    'castorama': 'Castorama',
    'ikea': 'IKEA',
    'leroy merlin': 'Leroy Merlin',
    'decathlon': 'Decathlon',
    'zara': 'Zara',
    'h&m': 'H&M',
    'reserved': 'Reserved',
    'ccc': 'CCC',
    'pepco': 'Pepco',
    'rossmann': 'Rossmann',
    'hebe': 'Hebe',
    'orlen': 'Orlen',
    'allegro': 'Allegro',
    'empik': 'Empik',
    'netto': 'Netto',
    'stokrotka': 'Stokrotka',
    'jysk': 'JYSK',
    'deichmann': 'Deichmann',
    'nike': 'Nike',
    'adidas': 'Adidas',
    'starbucks': 'Starbucks',
    'mcdonalds': "McDonald's",
    'mcdonald': "McDonald's",
    'kfc': 'KFC',
    'avangarda': 'Avangarda Elektroniki',
    'promes': 'PROMES',
    'athlon': 'Athlon Car Lease',
  };

  static String normalize(String raw) {
    if (raw.trim().isEmpty) return raw;

    var name = raw.trim();

    // Remove cashier names (UPPERCASE FIRSTNAME LASTNAME pattern at end)
    name = name.replaceAll(
        RegExp(r'\s+[A-ZĄĆĘŁŃÓŚŹŻ]{2,}\s+[A-ZĄĆĘŁŃÓŚŹŻ]{2,}-?[A-ZĄĆĘŁŃÓŚŹŻ]*$'),
        '');

    // Remove "fragrances:" and similar English artifacts
    name = name.replaceAll(RegExp(r'\s*fragrances?:?\s*', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'\s*EnBeeS\s*', caseSensitive: false), '');

    // Fix missing space after colon
    name = name.replaceAll(RegExp(r':(\S)'), ': \$1');

    // Normalize whitespace
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Try brand dictionary match
    final lower = name.toLowerCase();
    for (final entry in _brandDictionary.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Clean up legal suffixes for readability
    name = name
        .replaceAll(RegExp(r'\s*sp\.?\s*z\s*o\.?\s*o\.?', caseSensitive: false), ' Sp. z o.o.')
        .replaceAll(RegExp(r'\s*sp\.?\s*j\.?', caseSensitive: false), ' Sp.j.')
        .replaceAll(RegExp(r'\s*s\.?\s*c\.?$', caseSensitive: false), ' S.C.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return name;
  }
}
