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
  String? _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _merchantController =
        TextEditingController(text: widget.receipt.merchantName);
    _amountController =
        TextEditingController(text: widget.receipt.amount?.toString() ?? '');
    _notesController = TextEditingController(text: widget.receipt.notes);
    _category = widget.receipt.category;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(receiptRepositoryProvider).updateReceipt(
        widget.receipt.id,
        {
          'merchant_name': _merchantController.text,
          'amount': double.tryParse(_amountController.text),
          'category': _category,
          'notes': _notesController.text,
        },
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
      title: const Text('Edytuj paragon'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _merchantController,
              decoration: const InputDecoration(labelText: 'Nazwa sklepu'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Kwota',
                suffixText: 'zł',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategoria'),
              items: AppConstants.receiptCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notatki'),
              maxLines: 3,
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
