import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/category_style.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/receipt_image.dart';
import '../../data/models/receipt_model.dart';

/// V3 "peek & pop" sheet dla paragonu. Audyt: "Long-press na karcie =
/// preview sheet z miniaturą zdjęcia w pełnej szerokości + przyciskami
/// Edytuj / Usuń (peek & pop)".
///
/// Wjazd przez `showModalBottomSheet` z `isScrollControlled: true`.
/// Strukura:
/// - Grabber
/// - Miniatura zdjęcia (full width, height 220 px, radius 20)
/// - Hero: ikona kategorii + nazwa sklepu (sentence-case) + kwota XL
/// - Meta: kategoria, data, ewentualnie KSeF tagi
/// - Stopka: 3 outline akcje (Edytuj / +Gwarancja / Reklamacja) + 1
///   destrukcyjna Usuń jako filled-tonal
class ReceiptPreviewSheet extends StatelessWidget {
  final ReceiptModel receipt;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddWarranty;
  final VoidCallback? onComplaint;

  const ReceiptPreviewSheet({
    super.key,
    required this.receipt,
    this.onEdit,
    this.onDelete,
    this.onAddWarranty,
    this.onComplaint,
  });

  /// Helper do otwierania sheet'a. Long-press na karcie wywołuje to.
  static Future<void> show(
    BuildContext context, {
    required ReceiptModel receipt,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onAddWarranty,
    VoidCallback? onComplaint,
  }) {
    Haptics.medium();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => ReceiptPreviewSheet(
        receipt: receipt,
        onEdit: onEdit,
        onDelete: onDelete,
        onAddWarranty: onAddWarranty,
        onComplaint: onComplaint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = CategoryStyle.of(receipt.category);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface0,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
            ),
          ),
          child: Column(
            children: [
              // Grabber
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  children: [
                    if (receipt.hasValidImageUrl)
                      Hero(
                        tag: 'receipt-image-${receipt.id}',
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          child: SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: ReceiptImage(
                              imageUrl: receipt.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    else
                      _DocumentPlaceholder(visual: visual),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: visual.color.withValues(alpha: 0.18),
                            border: Border.all(
                              color:
                                  visual.color.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(visual.icon,
                              size: 22, color: visual.color),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatMerchant(receipt.merchantName),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _metaLine(receipt, visual),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.formatCurrency(receipt.amount),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                            if (receipt.isKsefInvoice &&
                                receipt.vatRate != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.full),
                                ),
                                child: Text(
                                  'VAT ${receipt.vatRate}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (receipt.notes != null &&
                        receipt.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                              color: AppColors.surfaceDivider),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_outlined,
                                size: 14,
                                color: AppColors.textTertiary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                receipt.notes!.trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      if (onEdit != null)
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.edit_rounded,
                            label: 'Edytuj',
                            onTap: () {
                              Navigator.pop(context);
                              onEdit!();
                            },
                          ),
                        ),
                      if (onEdit != null && onAddWarranty != null)
                        const SizedBox(width: AppSpacing.sm),
                      if (onAddWarranty != null)
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.shield_rounded,
                            label: 'Gwarancja',
                            onTap: () {
                              Navigator.pop(context);
                              onAddWarranty!();
                            },
                            accent: AppColors.primary400,
                          ),
                        ),
                      if (onComplaint != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _IconAction(
                          icon: Icons.gavel_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            onComplaint!();
                          },
                          tooltip: 'Reklamacja',
                        ),
                      ],
                      if (onDelete != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _IconAction(
                          icon: Icons.delete_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            onDelete!();
                          },
                          accent: AppColors.danger500,
                          tooltip: 'Usuń',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatMerchant(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Nieznany sklep';
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\s+[A-Z]?\d{3,}\b'), '');
    s = s.replaceFirst(RegExp(r'^SKLEP\s+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _metaLine(ReceiptModel r, CategoryVisual visual) {
    final parts = <String>[visual.label];
    if (r.purchaseDate != null) {
      parts.add(Formatters.formatRelativeDate(r.purchaseDate));
    }
    if (r.isKsefInvoice) parts.add('KSeF');
    if (r.aiProcessed) parts.add('AI');
    return parts.join(' · ');
  }
}

class _DocumentPlaceholder extends StatelessWidget {
  final CategoryVisual visual;
  const _DocumentPlaceholder({required this.visual});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.color.withValues(alpha: 0.18),
            visual.color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: visual.color.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(visual.icon, size: 56, color: visual.color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Brak zdjęcia',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: visual.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;
  final String? tooltip;
  const _IconAction({
    required this.icon,
    required this.onTap,
    this.accent,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.textSecondary;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(
                color: color.withValues(alpha: 0.32),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
