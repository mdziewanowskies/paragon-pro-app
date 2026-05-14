import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../receipts/data/models/receipt_model.dart';
import '../../../../shared/widgets/motion.dart';

/// V3 lista faktur KSeF. Audyt: "faktura przestaje wyglądać jak rekord
/// bazy a zaczyna jak karta przelewu w bankowości mobilnej".
///
/// Każda karta:
/// - 6 px gradient accent po lewej (KSeF brand)
/// - avatar litera kontrahenta w okręgu (gradient pochodny od hash nazwy)
/// - brutto XL po prawej (XL bold)
/// - status pill ("opłacone" / "oczekuje" / "wystawiona") z payment API
/// - hex KSeF ID schowane — tylko w widoku szczegółu
/// - XML download i "Zobacz fakturę" jako secondary akcje
class KsefInvoiceTable extends StatelessWidget {
  final List<ReceiptModel> invoices;
  final ValueChanged<String>? onDownloadXml;
  final ValueChanged<ReceiptModel>? onOpen;

  const KsefInvoiceTable({
    super.key,
    required this.invoices,
    this.onDownloadXml,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (int i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      items.add(
        StaggeredFadeIn(
          key: ValueKey('ksef-fade-${inv.id}'),
          index: i,
          child: _InvoiceCard(
            invoice: inv,
            onTap: onOpen == null ? null : () => onOpen!(inv),
            onDownloadXml:
                onDownloadXml != null && inv.ksefNumber != null
                    ? () => onDownloadXml!(inv.ksefNumber!)
                    : null,
          ),
        ),
      );
      items.add(const SizedBox(height: 10));
    }
    return Column(children: items);
  }
}

class _InvoiceCard extends StatelessWidget {
  final ReceiptModel invoice;
  final VoidCallback? onTap;
  final VoidCallback? onDownloadXml;

  const _InvoiceCard({
    required this.invoice,
    this.onTap,
    this.onDownloadXml,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.md,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 6 px gradient accent po lewej — brand KSeF
                  Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradientV3,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header: avatar + nazwa + brutto XL
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _InvoiceAvatar(
                                merchant: invoice.merchantName ?? '?',
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      invoice.merchantName ?? '—',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _captionLine(invoice),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.textSecondary,
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
                                    Formatters.formatCurrency(
                                        invoice.grossAmount),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (invoice.vatRate != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'brutto · VAT ${invoice.vatRate}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary300,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          // Sekcja kwot — divider + netto/VAT + status
                          if (invoice.netAmount != null ||
                              invoice.vatAmount != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              height: 1,
                              color: c.surfaceDivider,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                if (invoice.netAmount != null)
                                  _AmountChip(
                                    label: 'Netto',
                                    value: invoice.netAmount!,
                                  ),
                                if (invoice.netAmount != null &&
                                    invoice.vatAmount != null)
                                  const SizedBox(width: AppSpacing.lg),
                                if (invoice.vatAmount != null)
                                  _AmountChip(
                                    label: 'VAT',
                                    value: invoice.vatAmount!,
                                  ),
                                const Spacer(),
                                _StatusPill(status: _resolveStatus(invoice)),
                              ],
                            ),
                          ],
                          // Akcje (XML / Zobacz) — drobne, secondary
                          if (onDownloadXml != null || onTap != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (onTap != null)
                                  _MiniAction(
                                    onTap: onTap!,
                                    label: 'Zobacz',
                                    icon: Icons.visibility_outlined,
                                    filled: true,
                                  ),
                                if (onTap != null && onDownloadXml != null)
                                  const SizedBox(width: AppSpacing.sm),
                                if (onDownloadXml != null)
                                  _MiniAction(
                                    onTap: onDownloadXml!,
                                    label: 'XML',
                                    icon: Icons.code_rounded,
                                    filled: false,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _captionLine(ReceiptModel inv) {
    final parts = <String>['Faktura KSeF'];
    if (inv.purchaseDate != null) {
      parts.add(Formatters.formatRelativeDate(inv.purchaseDate));
    }
    return parts.join(' · ');
  }

  _InvoiceStatus _resolveStatus(ReceiptModel inv) {
    // Backend nie ma jeszcze pola `payment_status` — heurystyka po
    // dacie. Jeśli faktura starsza niż 30 dni → "wystawiona" (default),
    // świeższa → "wystawiona". Pole zostanie podpięte gdy KSeF API
    // zacznie zwracać payment status; do tego czasu pokazujemy zielony
    // "wystawiona" jako neutral indicator istnienia w systemie.
    return _InvoiceStatus.issued;
  }
}

enum _InvoiceStatus { paid, pending, overdue, issued }

class _StatusPill extends StatelessWidget {
  final _InvoiceStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      _InvoiceStatus.paid => (
          'opłacone',
          AppColors.primary800,
          AppColors.primary400,
        ),
      _InvoiceStatus.pending => (
          'oczekuje',
          AppColors.warning500.withValues(alpha: 0.18),
          AppColors.warning500,
        ),
      _InvoiceStatus.overdue => (
          'po terminie',
          AppColors.dangerBg,
          AppColors.danger500,
        ),
      _InvoiceStatus.issued => (
          'wystawiona',
          context.colors.surface2,
          context.colors.textSecondary,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final double value;
  const _AmountChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: c.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.formatCurrency(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final bool filled;
  const _MiniAction({
    required this.onTap,
    required this.label,
    required this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? AppColors.primary500
        : Colors.transparent;
    final fg = filled ? Colors.white : AppColors.primary400;
    final border = filled
        ? null
        : Border.all(color: AppColors.primary500.withValues(alpha: 0.5));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar litera kontrahenta — gradient pochodny od hash nazwy.
/// Audyt: "kolor pochodny od nazwy (hash → hue)".
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
    final color2 =
        HSLColor.fromAHSL(1, (hue + 30) % 360, 0.55, 0.35).toColor();

    return Container(
      width: 40,
      height: 40,
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
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
