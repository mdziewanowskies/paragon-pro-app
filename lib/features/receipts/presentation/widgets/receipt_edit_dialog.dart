import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/receipt_model.dart';
import '../../data/receipt_repository.dart';

class ReceiptEditDialog extends ConsumerStatefulWidget {
  final ReceiptModel receipt;
  final VoidCallback? onSaved;

  const ReceiptEditDialog({
    super.key,
    required this.receipt,
    this.onSaved,
  });

  @override
  ConsumerState<ReceiptEditDialog> createState() => _ReceiptEditDialogState();
}

class _ReceiptEditDialogState extends ConsumerState<ReceiptEditDialog> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  // KSeF fields
  late final TextEditingController _ksefNumberController;
  late final TextEditingController _sellerNipController;
  late final TextEditingController _buyerNipController;
  late final TextEditingController _netAmountController;
  late final TextEditingController _vatAmountController;
  String? _category;
  String? _vatRate;
  bool _isKsefInvoice = false;
  bool _sharedWithFamily = false;
  bool _isSaving = false;

  static const _vatRates = ['23%', '8%', '5%', '0%', 'ZW', 'mieszana'];

  @override
  void initState() {
    super.initState();
    _merchantController =
        TextEditingController(text: widget.receipt.merchantName);
    _amountController =
        TextEditingController(text: widget.receipt.amount?.toString() ?? '');
    _notesController = TextEditingController(text: widget.receipt.notes);
    _ksefNumberController =
        TextEditingController(text: widget.receipt.ksefNumber);
    _sellerNipController =
        TextEditingController(text: widget.receipt.sellerNip);
    _buyerNipController =
        TextEditingController(text: widget.receipt.buyerNip);
    _netAmountController =
        TextEditingController(text: widget.receipt.netAmount?.toString() ?? '');
    _vatAmountController =
        TextEditingController(text: widget.receipt.vatAmount?.toString() ?? '');
    _category = widget.receipt.category;
    _vatRate = widget.receipt.vatRate;
    _isKsefInvoice = widget.receipt.isKsefInvoice;
    _sharedWithFamily = widget.receipt.sharedWithFamily;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _ksefNumberController.dispose();
    _sellerNipController.dispose();
    _buyerNipController.dispose();
    _netAmountController.dispose();
    _vatAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'merchant_name': _merchantController.text,
        'amount': double.tryParse(_amountController.text),
        'category': _category,
        'notes': _notesController.text,
        'is_ksef_invoice': _isKsefInvoice,
        'shared_with_family': _sharedWithFamily,
      };

      if (_isKsefInvoice) {
        updates.addAll({
          'ksef_number': _ksefNumberController.text.isEmpty
              ? null
              : _ksefNumberController.text,
          'seller_nip': _sellerNipController.text.isEmpty
              ? null
              : _sellerNipController.text,
          'buyer_nip': _buyerNipController.text.isEmpty
              ? null
              : _buyerNipController.text,
          'net_amount': double.tryParse(_netAmountController.text),
          'vat_amount': double.tryParse(_vatAmountController.text),
          'gross_amount': double.tryParse(_amountController.text),
          'vat_rate': _vatRate,
        });
      }

      await ref.read(receiptRepositoryProvider).updateReceipt(
            widget.receipt.id,
            updates,
          );
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          _isKsefInvoice ? 'Edytuj fakturę KSeF' : 'Edytuj paragon'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _merchantController,
              decoration: const InputDecoration(labelText: 'Nazwa sklepu'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Kwota',
                suffixText: 'zł',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategoria'),
              items: AppConstants.receiptCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notatki'),
              maxLines: 2,
            ),

            // KSeF section
            const SizedBox(height: 24),
            const Divider(),
            SwitchListTile(
              title: const Text('Faktura KSeF',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: _isKsefInvoice,
              onChanged: (v) => setState(() => _isKsefInvoice = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isKsefInvoice) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _ksefNumberController,
                decoration: const InputDecoration(
                    labelText: 'Numer KSeF'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sellerNipController,
                      decoration: const InputDecoration(
                          labelText: 'NIP sprzedawcy'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _buyerNipController,
                      decoration: const InputDecoration(
                          labelText: 'NIP nabywcy'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _netAmountController,
                      decoration: const InputDecoration(
                          labelText: 'Netto'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _vatAmountController,
                      decoration: const InputDecoration(
                          labelText: 'VAT'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _vatRate,
                decoration: const InputDecoration(
                    labelText: 'Stawka VAT'),
                items: _vatRates
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _vatRate = v),
              ),
            ],

            // Family sharing
            const SizedBox(height: 16),
            const Divider(),
            SwitchListTile(
              title: const Text('Udostępnij rodzinie',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text('Widoczny dla członków rodziny',
                  style: TextStyle(fontSize: 12)),
              value: _sharedWithFamily,
              onChanged: (v) => setState(() => _sharedWithFamily = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Zapisz'),
        ),
      ],
    );
  }
}
