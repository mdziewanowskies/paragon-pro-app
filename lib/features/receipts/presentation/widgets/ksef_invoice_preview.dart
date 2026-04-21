import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/receipt_model.dart';

class KsefInvoicePreviewDialog extends StatelessWidget {
  final ReceiptModel receipt;

  const KsefInvoicePreviewDialog({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 440,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.description_rounded,
                      color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'FAKTURA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  if (receipt.ksefNumber != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      receipt.ksefNumber!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Sprzedawca'),
                    const SizedBox(height: 6),
                    Text(
                      receipt.merchantName ?? '—',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (receipt.sellerNip != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'NIP: ${receipt.sellerNip}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    if (receipt.merchantAddress != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        receipt.merchantAddress!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (receipt.buyerNip != null) ...[
                      _SectionLabel('Nabywca'),
                      const SizedBox(height: 6),
                      Text('NIP: ${receipt.buyerNip}',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 20),
                    ],
                    _SectionLabel('Szczegóły'),
                    const SizedBox(height: 10),
                    _DetailRow(
                        'Numer faktury', receipt.receiptNumber ?? '—'),
                    _DetailRow('Data wystawienia',
                        Formatters.formatDate(receipt.purchaseDate)),
                    if (receipt.vatRate != null)
                      _DetailRow('Stawka VAT', receipt.vatRate!),
                    const SizedBox(height: 20),
                    // Amounts card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          if (receipt.netAmount != null)
                            _AmountRow('Netto', receipt.netAmount!),
                          if (receipt.vatAmount != null) ...[
                            const SizedBox(height: 6),
                            _AmountRow('VAT', receipt.vatAmount!),
                          ],
                          if (receipt.netAmount != null ||
                              receipt.vatAmount != null) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'BRUTTO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                Formatters.formatCurrency(
                                    receipt.grossAmount ?? receipt.amount),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zamknij'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  const _AmountRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(Formatters.formatCurrency(amount),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
