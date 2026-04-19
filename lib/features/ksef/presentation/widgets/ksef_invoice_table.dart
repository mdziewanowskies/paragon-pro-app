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
    return Card(
      child: Column(
        children: [
          SingleChildScrollView(
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
                DataColumn(label: Text('')),
              ],
              rows: invoices.map((inv) {
                return DataRow(cells: [
                  DataCell(Text(
                    inv.ksefNumber ?? '-',
                    style: const TextStyle(fontSize: 12),
                  )),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        inv.merchantName ?? '-',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
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
                  DataCell(
                    inv.ksefNumber != null &&
                            inv.ksefNumber!.isNotEmpty &&
                            onDownloadXml != null
                        ? IconButton(
                            icon: const Icon(Icons.code_rounded, size: 18),
                            tooltip: 'Pobierz XML',
                            onPressed: () =>
                                onDownloadXml!(inv.ksefNumber!),
                            visualDensity: VisualDensity.compact,
                          )
                        : const SizedBox.shrink(),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
