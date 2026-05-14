import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/category_style.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/receipt_model.dart';

/// V3 receipt card — compact (96 px wysokości), zorientowana
/// horyzontalnie: [ikona kategorii w okręgu] [nazwa + meta] [kwota XL +
/// chevron]. Zastępuje starą wersję, która miała 280-320 px wysokości
/// (billboard miniatury + 4 ikony akcji + czerwony kosz).
///
/// Audyt: "z karty zniknie 70% szumu wizualnego — lista 19 paragonów
/// mieści się w 2 ekranach (teraz w 5+)".
///
/// Akcje (edit / +gwarancja / usuń) wywołujący wstawia jako
/// `Slidable` z `flutter_slidable` — patrz `receipt_list_screen.dart`.
class ReceiptCard extends StatelessWidget {
  final ReceiptModel receipt;
  final String? currentUserId;
  final VoidCallback? onTap;

  /// Włącza "tryb wyboru" — bez chevrona, z subtelnym borderem
  /// gdy zaznaczony. Używane na liście paragonów w bulk delete.
  final bool selected;

  /// Drobny prompt gamifikacyjny pod meta-linią (np. "+5 pkt do Lvl 3").
  /// Wyświetla się tylko gdy podane.
  final String? gamificationHint;

  const ReceiptCard({
    super.key,
    required this.receipt,
    this.currentUserId,
    this.onTap,
    this.selected = false,
    this.gamificationHint,
  });

  bool get _isFamilyShared =>
      receipt.sharedWithFamily &&
      currentUserId != null &&
      receipt.userId != currentUserId;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryStyle.of(receipt.category);
    final isInvoice = receipt.isKsefInvoice;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected
                ? Border.all(color: AppColors.primary500, width: 2)
                : null,
            boxShadow: AppShadows.md,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Lewa: ikona kategorii lub avatar litera (faktura) ──
              isInvoice
                  ? _InvoiceAvatar(
                      merchant: receipt.merchantName ?? '',
                    )
                  : _CategoryAvatar(visual: visual),
              const SizedBox(width: AppSpacing.md),
              // ── Środek: nazwa + meta ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMerchant(receipt.merchantName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _metaLine(receipt, visual),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_isFamilyShared) ...[
                          const SizedBox(width: 6),
                          const _MiniTag(
                            label: 'Rodzina',
                            color: Color(0xFF60A5FA),
                          ),
                        ],
                        if (receipt.aiProcessed) ...[
                          const SizedBox(width: 6),
                          _MiniTag(
                            label: 'AI',
                            color: AppColors.accentAqua,
                          ),
                        ],
                      ],
                    ),
                    if (gamificationHint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        gamificationHint!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary300,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // ── Prawa: kwota XL + chevron ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formatters.formatCurrency(receipt.amount),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                  ),
                  if (isInvoice && receipt.vatAmount != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'VAT ${Formatters.formatCurrency(receipt.vatAmount)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
              if (!selected)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Sentence-case zamiast SKLEP ZABKA Z5848 → Żabka. Heurystyka:
  // dropujemy końcowe kody numeryczne typu "Z5848" (4+ znaków), capitalizujemy.
  String _formatMerchant(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Nieznany sklep';
    var s = raw.trim();
    // Usuwamy końcowe kody typu " Z5848", " 1234"
    s = s.replaceAll(RegExp(r'\s+[A-Z]?\d{3,}\b'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return raw.trim();
    // Drop prefix "SKLEP " jeśli jest
    s = s.replaceFirst(RegExp(r'^SKLEP\s+', caseSensitive: false), '');
    // Sentence case — każde słowo z dużej, reszta mała
    return s
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _metaLine(ReceiptModel r, CategoryVisual visual) {
    final parts = <String>[];
    if (r.category != null && r.category!.trim().isNotEmpty) {
      parts.add(visual.label);
    } else {
      parts.add(visual.label);
    }
    final date = r.purchaseDate;
    if (date != null) {
      parts.add(Formatters.formatRelativeDate(date));
    }
    return parts.join(' · ');
  }
}

class _CategoryAvatar extends StatelessWidget {
  final CategoryVisual visual;
  const _CategoryAvatar({required this.visual});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visual.color.withValues(alpha: 0.18),
        border: Border.all(
          color: visual.color.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(visual.icon, size: 22, color: visual.color),
    );
  }
}

/// Avatar litera kontrahenta — gradient pochodny od hash nazwy.
/// Używany dla faktur KSeF gdzie nie mamy kategorii produktowej,
/// tylko firmę-wystawcę.
class _InvoiceAvatar extends StatelessWidget {
  final String merchant;
  const _InvoiceAvatar({required this.merchant});

  @override
  Widget build(BuildContext context) {
    final letter = merchant.trim().isEmpty
        ? '?'
        : merchant.trim()[0].toUpperCase();
    final hue = (merchant.hashCode.abs() % 360).toDouble();
    final color1 = HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
    final color2 = HSLColor.fromAHSL(1, (hue + 30) % 360, 0.55, 0.35).toColor();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// Drobny tag używany w meta-linii do oznaczania źródła paragonu
/// (AI / Rodzina / KSeF). Półprzezroczyste tło koloru semantycznego.
class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
