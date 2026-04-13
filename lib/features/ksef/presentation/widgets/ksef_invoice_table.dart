import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../../receipts/data/models/receipt_model.dart';

class KsefInvoiceTable extends StatelessWidget {
  final List<ReceiptModel> invoices;

  const KsefInvoiceTable({super.key, required this.invoices});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Nr KSeF')),
            DataColumn(label: Text('Sprzedawca')),
            DataColumn(label: Text('NIP')),
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Netto'), numeric: true),
            DataColumn(label: Text('VAT'), numeric: true),
            DataColumn(label: Text('Brutto'), numeric: true),
            DataColumn(label: Text('Stawka')),
          ],
          rows: invoices.map((inv) {
            return DataRow(cells: [
              DataCell(Text(
                inv.ksefNumber ?? '-',
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                inv.merchantName ?? '-',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              )),
              DataCell(Text(
                inv.sellerNip ?? '-',
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                Formatters.formatDate(inv.purchaseDate),
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                Formatters.formatCurrency(inv.netAmount),
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                Formatters.formatCurrency(inv.vatAmount),
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                Formatters.formatCurrency(inv.grossAmount),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              )),
              DataCell(Text(
                inv.vatRate ?? '-',
                style: const TextStyle(fontSize: 12),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
