import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../../receipts/data/models/receipt_model.dart';

class VatSummary extends StatelessWidget {
  final List<ReceiptModel> invoices;

  const VatSummary({super.key, required this.invoices});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, double>> vatGroups = {};
    for (final inv in invoices) {
      final rate = inv.vatRate ?? 'Inne';
      vatGroups[rate] ??= {'net': 0, 'vat': 0, 'gross': 0};
      vatGroups[rate]!['net'] =
          (vatGroups[rate]!['net'] ?? 0) + (inv.netAmount ?? 0);
      vatGroups[rate]!['vat'] =
          (vatGroups[rate]!['vat'] ?? 0) + (inv.vatAmount ?? 0);
      vatGroups[rate]!['gross'] =
          (vatGroups[rate]!['gross'] ?? 0) + (inv.grossAmount ?? 0);
    }

    double totalNet = 0, totalVat = 0, totalGross = 0;
    for (final g in vatGroups.values) {
      totalNet += g['net'] ?? 0;
      totalVat += g['vat'] ?? 0;
      totalGross += g['gross'] ?? 0;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Podsumowanie VAT',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Per-rate rows
            ...vatGroups.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.key,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Netto ${Formatters.formatCurrency(e.value['net'])}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(e.value['gross']),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            // Totals
            Row(
              children: [
                Text(
                  'SUMA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Netto: ${Formatters.formatCurrency(totalNet)}  |  VAT: ${Formatters.formatCurrency(totalVat)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(totalGross),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
