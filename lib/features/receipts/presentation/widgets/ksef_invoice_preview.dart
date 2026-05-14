import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/receipt_model.dart';

/// V3 podgląd faktury KSeF — bottom sheet z grabberem (audit:
/// "Sheet z grabberem (radius 28 na górze, height 12 grabber). Pull-down-
/// to-dismiss z spring. Zamknij znika z dołu — gest robotę kończy").
///
/// Tytuł sekcji w sentence-case (nie UPPERCASE) — to dokument, nie
/// formularz urzędowy. Avatar litera kontrahenta zamiast generycznego
/// ikona-dokumentu w hero. Status payment-pill po prawej. Identyfikator
/// KSeF (długi hex) wyłącznie w sekcji "Numer w KSeF" z przyciskiem
/// "Skopiuj" — nie eksponowany na samym wejściu.
class KsefInvoiceSheet extends StatelessWidget {
  final ReceiptModel receipt;

  const KsefInvoiceSheet({super.key, required this.receipt});

  /// Helper do otwierania sheet'a z dowolnego miejsca. Używać zamiast
  /// `showDialog(builder: ...)` które było w poprzedniej wersji.
  static Future<void> show(BuildContext context, ReceiptModel receipt) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => KsefInvoiceSheet(receipt: receipt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final merchant = receipt.merchantName ?? '—';
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
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
              // Hero — avatar + nazwa + brutto XL
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(merchant: merchant),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            merchant,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Faktura · ${Formatters.formatRelativeDate(receipt.purchaseDate)}',
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
                          Formatters.formatCurrency(
                              receipt.grossAmount ?? receipt.amount),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            receipt.vatRate != null
                                ? 'VAT ${receipt.vatRate}'
                                : 'wystawiona',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  children: [
                    const _SectionLabel('Sprzedawca'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      merchant,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (receipt.sellerNip != null) ...[
                      const SizedBox(height: 4),
                      _MetaRow(
                        icon: Icons.badge_outlined,
                        text: 'NIP: ${receipt.sellerNip}',
                      ),
                    ],
                    if (receipt.merchantAddress != null) ...[
                      const SizedBox(height: 4),
                      _MetaRow(
                        icon: Icons.location_on_outlined,
                        text: receipt.merchantAddress!,
                      ),
                    ],
                    if (receipt.buyerNip != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionLabel('Nabywca'),
                      const SizedBox(height: AppSpacing.sm),
                      _MetaRow(
                        icon: Icons.badge_outlined,
                        text: 'NIP: ${receipt.buyerNip}',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('Szczegóły płatności'),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailLine(
                      label: 'Numer faktury',
                      value: receipt.receiptNumber ?? '—',
                    ),
                    _DetailLine(
                      label: 'Data wystawienia',
                      value: Formatters.formatDate(receipt.purchaseDate),
                    ),
                    if (receipt.netAmount != null)
                      _DetailLine(
                        label: 'Netto',
                        value: Formatters.formatCurrency(receipt.netAmount),
                      ),
                    if (receipt.vatAmount != null)
                      _DetailLine(
                        label: 'VAT',
                        value: Formatters.formatCurrency(receipt.vatAmount),
                      ),
                    _DetailLine(
                      label: 'Brutto',
                      value: Formatters.formatCurrency(
                          receipt.grossAmount ?? receipt.amount),
                      emphasis: true,
                    ),
                    if (receipt.ksefNumber != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionLabel('Numer w KSeF'),
                      const SizedBox(height: AppSpacing.sm),
                      _KsefIdRow(ksefNumber: receipt.ksefNumber!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
              // Stopka — 3 akcje (audyt: "Pobierz XML / Dodaj do
              // raportu / ⋯"). Brak jednego dominującego CTA "Zamknij" —
              // gest pull-down kończy interakcję.
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
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO Sprint 3: XML download integration
                            Haptics.tap();
                          },
                          icon: const Icon(Icons.code_rounded, size: 16),
                          label: const Text('Pobierz XML'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filledTonal(
                        onPressed: () {
                          // TODO Sprint 3: more actions sheet
                          Haptics.tap();
                        },
                        icon: const Icon(Icons.more_horiz_rounded),
                        tooltip: 'Więcej',
                      ),
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
}

/// Backward-compatibility shim — istniejące call sites używają nazwy
/// `KsefInvoicePreviewDialog`. Renderuje ten sam sheet w starym
/// `showDialog` opakowaniu (czarne tło, fade-in).
class KsefInvoicePreviewDialog extends StatelessWidget {
  final ReceiptModel receipt;
  const KsefInvoicePreviewDialog({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    // Po starcie automatycznie zamykamy dialog i otwieramy nowy sheet
    // — pozwala to nie ruszać call sites, a jednocześnie używać nowej
    // estetyki bottom sheet'a zgodnie z audytem.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop();
      KsefInvoiceSheet.show(context, receipt);
    });
    return const SizedBox.shrink();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    // Audyt: "nagłówki Sentence Case 13/600 (#9CA3AF), nie uppercase".
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  const _DetailLine({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasis ? 16 : 14,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
              color: emphasis
                  ? AppColors.primary400
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KsefIdRow extends StatelessWidget {
  final String ksefNumber;
  const _KsefIdRow({required this.ksefNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.surfaceDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ksefNumber,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: ksefNumber));
              Haptics.success();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Skopiowano numer KSeF'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: AppColors.primary400,
            tooltip: 'Skopiuj',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String merchant;
  const _Avatar({required this.merchant});

  @override
  Widget build(BuildContext context) {
    final letter = merchant.trim().isEmpty
        ? '?'
        : merchant.trim()[0].toUpperCase();
    final hue = (merchant.hashCode.abs() % 360).toDouble();
    final color1 = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();
    final color2 =
        HSLColor.fromAHSL(1, (hue + 30) % 360, 0.55, 0.38).toColor();

    return Container(
      width: 52,
      height: 52,
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
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      color: AppColors.surfaceDivider,
    );
  }
}
