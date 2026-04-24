import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../../receipts/data/models/receipt_model.dart';

class KsefInvoiceTable extends StatelessWidget {
  final List<ReceiptModel> invoices;
  final ValueChanged<String>? onDownloadXml;

  const KsefInvoiceTable({
    super.key,
    required this.invoices,
    this.onDownloadXml,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: invoices.map((inv) => _InvoiceCard(
        invoice: inv,
        onDownloadXml: onDownloadXml != null && inv.ksefNumber != null
            ? () => onDownloadXml!(inv.ksefNumber!)
            : null,
      )).toList(),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final ReceiptModel invoice;
  final VoidCallback? onDownloadXml;

  const _InvoiceCard({required this.invoice, this.onDownloadXml});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: merchant + date
            Row(
              children: [
                Expanded(
                  child: Text(
                    invoice.merchantName ?? '—',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  Formatters.formatDate(invoice.purchaseDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // NIP + KSeF number
            if (invoice.sellerNip != null)
              Text(
                'NIP: ${invoice.sellerNip}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            if (invoice.ksefNumber != null) ...[
              const SizedBox(height: 2),
              Text(
                invoice.ksefNumber!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            // Amounts row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _AmountCol('Netto', invoice.netAmount),
                  _AmountCol('VAT', invoice.vatAmount),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Brutto',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(invoice.grossAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // VAT rate + XML button
            if (invoice.vatRate != null || onDownloadXml != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (invoice.vatRate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'VAT ${invoice.vatRate}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Spacer(),
                  if (onDownloadXml != null)
                    TextButton.icon(
                      onPressed: onDownloadXml,
                      icon: const Icon(Icons.code_rounded, size: 16),
                      label: const Text('XML',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountCol extends StatelessWidget {
  final String label;
  final double? amount;

  const _AmountCol(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          Text(
            Formatters.formatCurrency(amount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
