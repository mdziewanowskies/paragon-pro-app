import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/utils/pdf_font_loader.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../receipts/data/models/receipt_model.dart';
import '../../../receipts/data/receipt_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/utils/share_helper.dart';
import 'dart:io';

class AdvancedExport extends ConsumerStatefulWidget {
  const AdvancedExport({super.key});

  @override
  ConsumerState<AdvancedExport> createState() => _AdvancedExportState();
}

class _AdvancedExportState extends ConsumerState<AdvancedExport> {
  bool _isExporting = false;
  String? _exportingType;

  Future<List<ReceiptModel>> _getAllReceipts() async {
    final userId = SupabaseService.auth.currentUser!.id;
    return await ref.read(receiptRepositoryProvider).getReceipts(
          userId: userId,
          limit: 10000,
        );
  }

  Future<List<ReceiptModel>> _getKsefInvoices() async {
    final userId = SupabaseService.auth.currentUser!.id;
    return await ref.read(receiptRepositoryProvider).getKsefInvoices(
          userId: userId,
        );
  }

  // ─── CSV Export ─────────────────────────────────────────────

  Future<void> _exportCsv() async {
    setState(() {
      _isExporting = true;
      _exportingType = 'CSV';
    });

    try {
      final receipts = await _getAllReceipts();
      final buffer = StringBuffer();

      // Header
      buffer.writeln(
          'Data;Sklep;Kwota;Kategoria;Nr paragonu;KSeF;NIP sprzedawcy;Netto;VAT;Brutto;Stawka VAT');

      // Rows
      for (final r in receipts) {
        buffer.writeln([
          Formatters.formatDate(r.purchaseDate),
          _csvEscape(r.merchantName ?? ''),
          r.amount?.toStringAsFixed(2) ?? '',
          r.category ?? '',
          r.receiptNumber ?? '',
          r.ksefNumber ?? '',
          r.sellerNip ?? '',
          r.netAmount?.toStringAsFixed(2) ?? '',
          r.vatAmount?.toStringAsFixed(2) ?? '',
          r.grossAmount?.toStringAsFixed(2) ?? '',
          r.vatRate ?? '',
        ].join(';'));
      }

      final csvContent = buffer.toString();
      final fileName =
          'paragonpro_export_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Write to temp and share
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvContent, encoding: utf8);

      if (context.mounted) {
        await shareFiles(context, [XFile(file.path)],
            subject: 'Eksport ParagonPro CSV');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('CSV wygenerowany: ${receipts.length} paragonów')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd eksportu CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _csvEscape(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ─── PDF Report ─────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() {
      _isExporting = true;
      _exportingType = 'PDF';
    });

    try {
      final receipts = await _getAllReceipts();
      final (font, fontBold) = await PdfFontLoader.loadWithFallback();

      final now = DateTime.now();
      final thisMonthReceipts = receipts
          .where((r) =>
              r.purchaseDate != null &&
              r.purchaseDate!.month == now.month &&
              r.purchaseDate!.year == now.year)
          .toList();

      final totalAll =
          receipts.fold<double>(0, (s, r) => s + (r.amount ?? 0));
      final totalMonth = thisMonthReceipts.fold<double>(
          0, (s, r) => s + (r.amount ?? 0));

      // Category breakdown
      final Map<String, double> categories = {};
      for (final r in receipts) {
        final cat = r.category ?? 'Inne';
        categories[cat] = (categories[cat] ?? 0) + (r.amount ?? 0);
      }
      final sortedCategories = categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Title
            pw.Text('Raport ParagonPro',
                style: pw.TextStyle(font: fontBold, fontSize: 22)),
            pw.SizedBox(height: 4),
            pw.Text('Wygenerowano: ${Formatters.formatDate(now)}',
                style: pw.TextStyle(
                    font: font, fontSize: 10, color: PdfColors.grey)),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f0fdf4'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfStat('Paragony łącznie', '${receipts.length}', font,
                      fontBold),
                  _pdfStat(
                      'Wydatki łącznie',
                      Formatters.formatCurrency(totalAll),
                      font,
                      fontBold),
                  _pdfStat(
                      'Ten miesiąc',
                      Formatters.formatCurrency(totalMonth),
                      font,
                      fontBold),
                  _pdfStat('Średni paragon',
                      Formatters.formatCurrency(receipts.isNotEmpty ? totalAll / receipts.length : 0),
                      font, fontBold),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Categories
            pw.Text('Wydatki wg kategorii',
                style: pw.TextStyle(font: fontBold, fontSize: 14)),
            pw.SizedBox(height: 8),
            ...sortedCategories.map((e) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                          child: pw.Text(e.key,
                              style: pw.TextStyle(font: font, fontSize: 11))),
                      pw.Text(Formatters.formatCurrency(e.value),
                          style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      pw.SizedBox(width: 12),
                      pw.Text(
                          '${(totalAll > 0 ? e.value / totalAll * 100 : 0).toStringAsFixed(1)}%',
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: PdfColors.grey)),
                    ],
                  ),
                )),
            pw.SizedBox(height: 20),

            // Recent receipts table
            pw.Text('Lista paragonów',
                style: pw.TextStyle(font: fontBold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.green50),
              cellPadding: const pw.EdgeInsets.all(4),
              headers: ['Data', 'Sklep', 'Kwota', 'Kategoria'],
              data: receipts
                  .take(100)
                  .map((r) => [
                        Formatters.formatDate(r.purchaseDate),
                        (r.merchantName ?? '-').length > 30
                            ? '${r.merchantName!.substring(0, 30)}...'
                            : r.merchantName ?? '-',
                        Formatters.formatCurrency(r.amount),
                        r.category ?? '-',
                      ])
                  .toList(),
            ),
            if (receipts.length > 100)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                    '... i ${receipts.length - 100} więcej paragonów',
                    style: pw.TextStyle(
                        font: font, fontSize: 9, color: PdfColors.grey)),
              ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'ParagonPro • Strona ${context.pageNumber}/${context.pagesCount}',
              style:
                  pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
            ),
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      final pdfFileName =
          'raport_paragonpro_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfDir = await getTemporaryDirectory();
      final pdfFile = File('${pdfDir.path}/$pdfFileName');
      await pdfFile.writeAsBytes(pdfBytes);
      if (context.mounted) {
        await shareFiles(context, [XFile(pdfFile.path)],
            subject: 'Raport ParagonPro');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Raport PDF wygenerowany')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd generowania PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _pdfStat(
      String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(font: fontBold, fontSize: 13)),
      ],
    );
  }

  // ─── XML KSeF Export ────────────────────────────────────────

  Future<void> _exportXml() async {
    setState(() {
      _isExporting = true;
      _exportingType = 'XML';
    });

    try {
      final invoices = await _getKsefInvoices();

      if (invoices.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Brak faktur KSeF do eksportu')),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      buffer.writeln(
          '<Faktury xmlns="http://paragonpro.com/ksef-export" data="${Formatters.formatDate(DateTime.now())}">');

      for (final inv in invoices) {
        buffer.writeln('  <Faktura>');
        buffer.writeln(
            '    <NumerKSeF>${_xmlEscape(inv.ksefNumber ?? '')}</NumerKSeF>');
        buffer.writeln(
            '    <NumerFaktury>${_xmlEscape(inv.receiptNumber ?? '')}</NumerFaktury>');
        buffer.writeln(
            '    <DataWystawienia>${inv.purchaseDate?.toIso8601String().split('T').first ?? ''}</DataWystawienia>');
        buffer.writeln('    <Sprzedawca>');
        buffer.writeln(
            '      <Nazwa>${_xmlEscape(inv.merchantName ?? '')}</Nazwa>');
        buffer.writeln(
            '      <NIP>${inv.sellerNip ?? ''}</NIP>');
        if (inv.merchantAddress != null) {
          buffer.writeln(
              '      <Adres>${_xmlEscape(inv.merchantAddress!)}</Adres>');
        }
        buffer.writeln('    </Sprzedawca>');
        buffer.writeln('    <Nabywca>');
        buffer.writeln('      <NIP>${inv.buyerNip ?? ''}</NIP>');
        buffer.writeln('    </Nabywca>');
        buffer.writeln('    <Kwoty>');
        buffer.writeln(
            '      <Netto>${inv.netAmount?.toStringAsFixed(2) ?? '0.00'}</Netto>');
        buffer.writeln(
            '      <VAT>${inv.vatAmount?.toStringAsFixed(2) ?? '0.00'}</VAT>');
        buffer.writeln(
            '      <Brutto>${inv.grossAmount?.toStringAsFixed(2) ?? '0.00'}</Brutto>');
        buffer.writeln(
            '      <StawkaVAT>${inv.vatRate ?? ''}</StawkaVAT>');
        buffer.writeln('    </Kwoty>');
        buffer.writeln('  </Faktura>');
      }

      buffer.writeln('</Faktury>');

      final xmlContent = buffer.toString();
      final fileName =
          'ksef_export_${DateTime.now().millisecondsSinceEpoch}.xml';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(xmlContent, encoding: utf8);

      if (context.mounted) {
        await shareFiles(context, [XFile(file.path)],
            subject: 'Eksport KSeF XML');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('XML wygenerowany: ${invoices.length} faktur')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd eksportu XML: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_download_rounded),
                const SizedBox(width: 8),
                Text(
                  'Zaawansowany eksport',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ExportOption(
              icon: Icons.table_chart_rounded,
              title: 'Eksport CSV',
              subtitle: 'Paragony i wydatki w formacie CSV',
              isLoading: _isExporting && _exportingType == 'CSV',
              onTap: _isExporting ? null : _exportCsv,
            ),
            const SizedBox(height: 8),
            _ExportOption(
              icon: Icons.picture_as_pdf_rounded,
              title: 'Raport PDF',
              subtitle: 'Pełny raport z podsumowaniem',
              isLoading: _isExporting && _exportingType == 'PDF',
              onTap: _isExporting ? null : _exportPdf,
            ),
            const SizedBox(height: 8),
            _ExportOption(
              icon: Icons.code_rounded,
              title: 'Eksport XML (KSeF)',
              subtitle: 'Faktury w formacie XML',
              isLoading: _isExporting && _exportingType == 'XML',
              onTap: _isExporting ? null : _exportXml,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isLoading ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
