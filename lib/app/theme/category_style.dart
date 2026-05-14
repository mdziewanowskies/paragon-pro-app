import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Mapuje kategorię paragonu / faktury na ikonę + kolor z palety
/// semantycznej. Audyt: "ikona kategorii w kolorowym kółku po lewej —
/// 5 semantycznych kolorów (Żywność / Tech / Auto / Usługi / Inne)".
///
/// Backend bazy dopuszcza dowolny string `category`, dlatego mamy
/// kanoniczne dopasowania (po prefiksach polskich kategorii) i sensowny
/// fallback dla pozostałych. Dodawanie nowej kategorii = jeden wpis
/// w `_canonical`.
class CategoryStyle {
  CategoryStyle._();

  /// Zwraca [_CategoryVisual] dla podanej kategorii. Null / pusty
  /// string traktowany jest jak "Inne".
  static CategoryVisual of(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _fallback;
    final lower = raw.toLowerCase().trim();
    for (final entry in _canonical) {
      for (final key in entry.keys) {
        if (lower.startsWith(key) || lower.contains(' $key')) {
          return entry.visual;
        }
      }
    }
    return _fallback;
  }

  // ── Kolejność ma znaczenie: bardziej specyficzne pierwsze. ─────
  static final List<_CategoryRule> _canonical = [
    _CategoryRule(
      keys: ['żywno', 'zywno', 'spożyw', 'spozyw', 'jedze', 'food',
             'sklep spoży', 'sklep spozy', 'restau', 'kawiar'],
      visual: CategoryVisual(
        icon: Icons.restaurant_rounded,
        color: AppColors.accentGold,
        label: 'Żywność',
      ),
    ),
    _CategoryRule(
      keys: ['tech', 'elektro', 'komputer', 'sprzęt', 'sprzet', 'agd', 'rtv'],
      visual: CategoryVisual(
        icon: Icons.devices_rounded,
        color: AppColors.accentAqua,
        label: 'Tech',
      ),
    ),
    _CategoryRule(
      keys: ['auto', 'samoch', 'pali', 'transport', 'stacja', 'paliwa'],
      visual: CategoryVisual(
        icon: Icons.directions_car_rounded,
        color: AppColors.accentViolet,
        label: 'Auto',
      ),
    ),
    _CategoryRule(
      keys: ['zdrow', 'aptek', 'lekar', 'medyc'],
      visual: CategoryVisual(
        icon: Icons.local_pharmacy_rounded,
        color: AppColors.danger500,
        label: 'Zdrowie',
      ),
    ),
    _CategoryRule(
      keys: ['odzież', 'odziez', 'ubran', 'moda', 'buty'],
      visual: CategoryVisual(
        icon: Icons.checkroom_rounded,
        color: AppColors.accentViolet,
        label: 'Odzież',
      ),
    ),
    _CategoryRule(
      keys: ['rozryw', 'kino', 'gier', 'bilet'],
      visual: CategoryVisual(
        icon: Icons.local_activity_rounded,
        color: AppColors.accentGoldDeep,
        label: 'Rozrywka',
      ),
    ),
    _CategoryRule(
      keys: ['dom', 'meble', 'remont', 'budow'],
      visual: CategoryVisual(
        icon: Icons.home_rounded,
        color: AppColors.primary400,
        label: 'Dom',
      ),
    ),
    _CategoryRule(
      keys: ['usług', 'uslug', 'service'],
      visual: CategoryVisual(
        icon: Icons.handyman_rounded,
        color: AppColors.primary500,
        label: 'Usługi',
      ),
    ),
    _CategoryRule(
      keys: ['fakt', 'ksef', 'invoice'],
      visual: CategoryVisual(
        icon: Icons.description_rounded,
        color: AppColors.primary800,
        label: 'Faktura',
      ),
    ),
  ];

  static const CategoryVisual _fallback = CategoryVisual(
    icon: Icons.shopping_bag_rounded,
    color: AppColors.textSecondary,
    label: 'Inne',
  );
}

/// Skondensowany "design token" dla kategorii — ikona, kolor i
/// kanoniczna etykieta (jeśli chcemy normalizować nazwy).
class CategoryVisual {
  final IconData icon;
  final Color color;
  final String label;

  const CategoryVisual({
    required this.icon,
    required this.color,
    required this.label,
  });
}

class _CategoryRule {
  final List<String> keys;
  final CategoryVisual visual;
  const _CategoryRule({required this.keys, required this.visual});
}
