import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../receipts/data/models/receipt_model.dart';

class WarrantyDialog extends ConsumerStatefulWidget {
  final ReceiptModel receipt;
  final VoidCallback? onSaved;

  const WarrantyDialog({
    super.key,
    required this.receipt,
    this.onSaved,
  });

  @override
  ConsumerState<WarrantyDialog> createState() => _WarrantyDialogState();
}

class _WarrantyDialogState extends ConsumerState<WarrantyDialog> {
  final _monthsController = TextEditingController(text: '12');
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _monthsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final months = int.tryParse(_monthsController.text);
    if (months == null || months < 1 || months > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj okres gwarancji (1-120 miesięcy)')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final startDate = widget.receipt.purchaseDate ?? DateTime.now();
      final endDate = DateTime(
        startDate.year,
        startDate.month + months,
        startDate.day,
      );

      await SupabaseService.client.from('warranties').insert({
        'receipt_id': widget.receipt.id,
        'user_id': userId,
        'warranty_months': months,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate.toIso8601String().split('T').first,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'status': 'active',
      });

      await SupabaseService.client
          .from('receipts')
          .update({'has_warranty': true})
          .eq('id', widget.receipt.id);

      try {
        await SupabaseService.invokeFunction(
          'process-gamification',
          body: {'userId': userId},
        );
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Gwarancja $months miesięcy została dodana pomyślnie'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd dodawania gwarancji: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_rounded, size: 22),
          SizedBox(width: 8),
          Text('Dodaj gwarancję'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store (disabled)
            TextField(
              controller: TextEditingController(
                  text: widget.receipt.merchantName ?? 'Nieznany sklep'),
              decoration: const InputDecoration(
                labelText: 'Sklep',
                prefixIcon: Icon(Icons.store_rounded, size: 20),
              ),
              enabled: false,
            ),
            const SizedBox(height: 12),
            // Purchase date (disabled)
            TextField(
              controller: TextEditingController(
                text: Formatters.formatDate(widget.receipt.purchaseDate),
              ),
              decoration: const InputDecoration(
                labelText: 'Data zakupu',
                prefixIcon: Icon(Icons.calendar_today, size: 20),
              ),
              enabled: false,
            ),
            const SizedBox(height: 16),
            // Warranty months
            TextField(
              controller: _monthsController,
              decoration: const InputDecoration(
                labelText: 'Okres gwarancji (miesiące)',
                hintText: '12',
                prefixIcon: Icon(Icons.timer_outlined, size: 20),
                helperText: 'Zakres: 1-120 miesięcy',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notatki (opcjonalne)',
                hintText: 'Np. numer seryjny, warunki gwarancji...',
                prefixIcon: Icon(Icons.note_outlined, size: 20),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(builder: (context) {
                      final months =
                          int.tryParse(_monthsController.text) ?? 12;
                      final startDate =
                          widget.receipt.purchaseDate ?? DateTime.now();
                      final endDate = DateTime(
                        startDate.year,
                        startDate.month + months,
                        startDate.day,
                      );
                      return Text(
                        'Gwarancja do: ${Formatters.formatDate(endDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.shield_rounded, size: 18),
          label: Text(_isSaving ? 'Zapisywanie...' : 'Dodaj gwarancję'),
        ),
      ],
    );
  }
}
