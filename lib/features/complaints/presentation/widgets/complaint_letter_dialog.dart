import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
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
  String _generatedLetter = '';

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
          _generatedLetter = letter;
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
    await Clipboard.setData(ClipboardData(text: _generatedLetter));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tekst skopiowany do schowka')),
      );
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
            Icon(Icons.check_circle,
                color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Pismo wygenerowane',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: SelectableText(
            _generatedLetter,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Możesz skopiować tekst i wkleić do dokumentu lub wysłać emailem.',
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
