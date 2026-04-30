import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pdf_font_loader.dart';
import '../../../receipts/data/models/receipt_model.dart';

class ComplaintLetterDialog extends ConsumerStatefulWidget {
  final ReceiptModel receipt;

  const ComplaintLetterDialog({super.key, required this.receipt});

  @override
  ConsumerState<ComplaintLetterDialog> createState() =>
      _ComplaintLetterDialogState();
}

class _ComplaintLetterDialogState extends ConsumerState<ComplaintLetterDialog> {
  int _step = 0; // 0: form, 1: generating, 2: preview
  final _letterController = TextEditingController();

  // Form controllers
  final _merchantAddressController = TextEditingController();
  final _productNameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _cityController = TextEditingController();

  // Demand checkboxes
  bool _demandExchange = false;
  bool _demandRepair = false;
  bool _demandPriceReduction = false;
  bool _demandRefund = true;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).value;
    _cityController.text = profile?.city ?? '';
  }

  @override
  void dispose() {
    _merchantAddressController.dispose();
    _productNameController.dispose();
    _reasonController.dispose();
    _cityController.dispose();
    _letterController.dispose();
    super.dispose();
  }

  List<String> get _selectedDemands {
    final demands = <String>[];
    if (_demandExchange) demands.add('Wymiana towaru');
    if (_demandRepair) demands.add('Naprawa');
    if (_demandPriceReduction) demands.add('Obniżenie ceny');
    if (_demandRefund) demands.add('Zwrot pieniędzy');
    return demands;
  }

  Future<void> _generate() async {
    if (_productNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj nazwę produktu')),
      );
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opisz powód reklamacji')),
      );
      return;
    }
    if (_selectedDemands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz co najmniej jedno żądanie')),
      );
      return;
    }

    setState(() => _step = 1);

    try {
      final profile = ref.read(profileProvider).value;
      final customerName = profile?.fullName ?? '';
      final customerAddress = profile?.fullAddress ?? '';

      final response = await SupabaseService.invokeFunction(
        'generate-complaint-letter',
        body: {
          'merchantName': widget.receipt.merchantName,
          'merchantAddress': _merchantAddressController.text.trim(),
          'receiptNumber': widget.receipt.receiptNumber,
          'productName': _productNameController.text.trim(),
          'purchaseDate':
              widget.receipt.purchaseDate?.toIso8601String().split('T').first,
          'complaintReason': _reasonController.text.trim(),
          'amount': widget.receipt.amount,
          'customerName': customerName,
          'customerAddress': customerAddress,
          'complaintCity': _cityController.text.trim(),
          'complaintDate': Formatters.formatDate(DateTime.now()),
          'demands': _selectedDemands,
          'bankAccount': profile?.bankAccountNumber,
        },
      );

      String letter = '';
      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        letter = data['letter'] as String? ??
            data['text'] as String? ??
            data['content'] as String? ??
            response.data.toString();
      } else if (response.data is String) {
        letter = response.data as String;
      }

      if (mounted) {
        setState(() {
          _letterController.text = letter;
          _step = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd generowania pisma: $e')),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _letterController.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tekst skopiowany do schowka')),
      );
    }
  }

  Future<void> _generateAndSharePdf() async {
    final profile = ref.read(profileProvider).value;
    final (font, fontBold) = await PdfFontLoader.loadWithFallback();

    final pdf = pw.Document();

    final paragraphs = _letterController.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PISMO REKLAMACYJNE',
                style: pw.TextStyle(font: fontBold, fontSize: 16),
              ),
              pw.Text(
                Formatters.formatDate(DateTime.now()),
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 16),
          // Letter content
          ...paragraphs.map((p) {
            final isBold = p.trim().endsWith(':') ||
                p.toUpperCase() == p && p.length > 3;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                p,
                style: pw.TextStyle(
                  font: isBold ? fontBold : font,
                  fontSize: 11,
                  lineSpacing: 4,
                ),
              ),
            );
          }),
          // Signature area
          pw.SizedBox(height: 40),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Text(
            profile?.fullName ?? '',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Wygenerowano w ParagonPro • Strona ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
          ),
        ),
      ),
    );

    final merchantName = widget.receipt.merchantName
            ?.replaceAll(RegExp(r'[^\w\s]'), '')
            .replaceAll(' ', '_') ??
        'reklamacja';
    final fileName =
        'reklamacja_${merchantName}_${DateTime.now().millisecondsSinceEpoch}';

    final pdfBytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(pdfBytes);
    if (context.mounted) {
      await shareFiles(context, [XFile(file.path)],
          subject: 'Pismo reklamacyjne');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _step == 2
                          ? 'Pismo reklamacyjne'
                          : 'Generuj pismo reklamacyjne',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _StepDot(label: '1', active: _step >= 0),
                  Expanded(child: _StepLine(active: _step >= 1)),
                  _StepDot(label: '2', active: _step >= 1),
                  Expanded(child: _StepLine(active: _step >= 2)),
                  _StepDot(label: '3', active: _step >= 2),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _step == 0
                    ? _buildFormStep()
                    : _step == 1
                        ? _buildGeneratingStep()
                        : _buildPreviewStep(),
              ),
            ),
            // Actions
            if (_step != 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    if (_step == 2)
                      TextButton(
                        onPressed: () => setState(() => _step = 0),
                        child: const Text('Wróć'),
                      ),
                    const Spacer(),
                    if (_step == 0)
                      ElevatedButton.icon(
                        onPressed: _generate,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Generuj pismo'),
                      ),
                    if (_step == 2) ...[
                      OutlinedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Kopiuj'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _generateAndSharePdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded,
                            size: 18),
                        label: const Text('Pobierz PDF'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    final profile = ref.watch(profileProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Receipt info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.receipt.merchantName ?? 'Nieznany sklep',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (widget.receipt.amount != null)
                Text(
                    'Kwota: ${Formatters.formatCurrency(widget.receipt.amount)}'),
              if (widget.receipt.purchaseDate != null)
                Text(
                    'Data: ${Formatters.formatDate(widget.receipt.purchaseDate)}'),
              if (widget.receipt.receiptNumber != null)
                Text('Nr: ${widget.receipt.receiptNumber}'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Store address
        const Text('Dane sklepu',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _merchantAddressController,
          decoration: const InputDecoration(
            labelText: 'Adres sklepu',
            hintText: 'ul. Przykładowa 1, 00-000 Miasto',
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),

        // Product info
        const Text('Dane produktu',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _productNameController,
          decoration: const InputDecoration(
            labelText: 'Nazwa produktu *',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          decoration: const InputDecoration(
            labelText: 'Powód reklamacji *',
            hintText: 'Opisz wadę lub problem...',
            isDense: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Demands
        const Text('Żądania',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        CheckboxListTile(
          value: _demandExchange,
          onChanged: (v) => setState(() => _demandExchange = v ?? false),
          title: const Text('Wymiana towaru', style: TextStyle(fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _demandRepair,
          onChanged: (v) => setState(() => _demandRepair = v ?? false),
          title: const Text('Naprawa', style: TextStyle(fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _demandPriceReduction,
          onChanged: (v) =>
              setState(() => _demandPriceReduction = v ?? false),
          title: const Text('Obniżenie ceny', style: TextStyle(fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _demandRefund,
          onChanged: (v) => setState(() => _demandRefund = v ?? false),
          title: const Text('Zwrot pieniędzy', style: TextStyle(fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),

        // Customer data
        const Text('Dane klienta',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: profile != null &&
                  profile.fullName.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (profile.fullAddress.isNotEmpty)
                      Text(profile.fullAddress,
                          style: const TextStyle(fontSize: 13)),
                    if (profile.bankAccountNumber != null)
                      Text('Konto: ${profile.bankAccountNumber}',
                          style: const TextStyle(fontSize: 12)),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Uzupełnij profil (imię, nazwisko, adres) w ustawieniach.',
                        style: TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'Miejscowość (do pisma)',
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratingStep() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Generowanie pisma reklamacyjnego...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AI przygotowuje pismo zgodne z art. 556 KC',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Pismo wygenerowane',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.green),
            ),
            const Spacer(),
            Icon(Icons.edit_note_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              'Edytowalne',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _letterController,
          maxLines: null,
          minLines: 12,
          style: const TextStyle(fontSize: 13, height: 1.6),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Możesz edytować treść pisma przed pobraniem PDF.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;

  const _StepDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active
                ? Colors.white
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;

  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: active
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}
