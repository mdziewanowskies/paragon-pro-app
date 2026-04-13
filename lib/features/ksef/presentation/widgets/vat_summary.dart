import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../../receipts/data/models/receipt_model.dart';

class VatSummary extends StatelessWidget {
  final List<ReceiptModel> invoices;

  const VatSummary({super.key, required this.invoices});

  @override
  Widget build(BuildContext context) {
    // Group by VAT rate
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
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                  ),
                  children: [
                    _header('Stawka'),
                    _header('Netto'),
                    _header('VAT'),
                    _header('Brutto'),
                  ],
                ),
                ...vatGroups.entries.map((e) => TableRow(
                      children: [
                        _cell(e.key),
                        _cell(Formatters.formatCurrency(e.value['net'])),
                        _cell(Formatters.formatCurrency(e.value['vat'])),
                        _cell(Formatters.formatCurrency(e.value['gross']),
                            bold: true),
                      ],
                    )),
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  children: [
                    _cell('SUMA', bold: true),
                    _cell(Formatters.formatCurrency(totalNet), bold: true),
                    _cell(Formatters.formatCurrency(totalVat), bold: true),
                    _cell(Formatters.formatCurrency(totalGross), bold: true),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}
