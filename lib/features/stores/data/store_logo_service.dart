import 'package:flutter/material.dart';

class StoreLogoService {
  StoreLogoService._();

  static const Map<String, String> _storeDomains = {
    'lidl': 'lidl.pl',
    'biedronka': 'biedronka.pl',
    'żabka': 'zabka.pl',
    'zabka': 'zabka.pl',
    'sklep żabka': 'zabka.pl',
    'sklep zabka': 'zabka.pl',
    'żappka': 'zabka.pl',
    'kaufland': 'kaufland.pl',
    'auchan': 'auchan.pl',
    'carrefour': 'carrefour.pl',
    'dino': 'marketdino.pl',
    'aldi': 'aldi.pl',
    'media markt': 'mediamarkt.pl',
    'mediamarkt': 'mediamarkt.pl',
    'media expert': 'mediaexpert.pl',
    'mediaexpert': 'mediaexpert.pl',
    'x-kom': 'x-kom.pl',
    'xkom': 'x-kom.pl',
    'komputronik': 'komputronik.pl',
    'ispot': 'ispot.pl',
    'castorama': 'castorama.pl',
    'ikea': 'ikea.com',
    'leroy merlin': 'leroymerlin.pl',
    'decathlon': 'decathlon.pl',
    'zara': 'zara.com',
    'h&m': 'hm.com',
    'reserved': 'reserved.com',
    'ccc': 'ccc.eu',
    'pepco': 'pepco.pl',
    'rossmann': 'rossmann.pl',
    'hebe': 'hebe.pl',
    'orlen': 'orlen.pl',
    'bolt': 'bolt.eu',
    'athlon': 'athlon.com',
    'allegro': 'allegro.pl',
    'empik': 'empik.com',
    'action': 'action.com',
    'jysk': 'jysk.pl',
    'deichmann': 'deichmann.com',
    'nike': 'nike.com',
    'adidas': 'adidas.pl',
    'starbucks': 'starbucks.com',
    'mcdonalds': 'mcdonalds.pl',
    'kfc': 'kfc.pl',
    'netto': 'netto.pl',
    'tesco': 'tesco.pl',
    'stokrotka': 'stokrotka.pl',
    'inmedio': 'inmedio.pl',
    'żywiec': 'zywiec.com.pl',
    'apart': 'apart.pl',
    'sinsay': 'sinsay.com',
    'mohito': 'mohito.com',
    'cropp': 'cropp.com',
    'house': 'housebrand.com',
    'smyk': 'smyk.com',
    'home&you': 'homeandyou.pl',
  };

  static String? getFaviconUrl(String storeName) {
    final domain = _matchDomain(storeName);
    if (domain == null) return null;
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
  }

  static String? _matchDomain(String storeName) {
    final normalized = storeName.toLowerCase().trim();

    // Exact match
    if (_storeDomains.containsKey(normalized)) {
      return _storeDomains[normalized];
    }

    // Partial match
    for (final entry in _storeDomains.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }

    return null;
  }

  static String getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  static Color getColor(String name) {
    int hash = 0;
    for (final c in name.codeUnits) {
      hash = ((hash << 5) - hash) + c;
      hash &= 0xFFFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.45).toColor();
  }
}
