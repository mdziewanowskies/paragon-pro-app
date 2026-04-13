import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../receipts/data/models/receipt_model.dart';

class ComplaintLetterDialog extends ConsumerStatefulWidget {
  final ReceiptModel receipt;

  const ComplaintLetterDialog({super.key, required this.receipt});

  @override
  ConsumerState<ComplaintLetterDialog> createState() =>
      _ComplaintLetterDialogState();
}

class _ComplaintLetterDialogState
    extends ConsumerState<ComplaintLetterDialog> {
  final _descriptionController = TextEditingController();
  final _demandController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _demandController.dispose();
    super.dispose();
  }

  Future<void> _generateLetter() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opisz problem')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final profile = ref.read(profileProvider).value;

      await SupabaseService.invokeFunction(
        'generate-complaint-letter',
        body: {
          'receiptId': widget.receipt.id,
          'merchantName': widget.receipt.merchantName,
          'purchaseDate':
              widget.receipt.purchaseDate?.toIso8601String().split('T').first,
          'amount': widget.receipt.amount,
          'description': _descriptionController.text.trim(),
          'demand': _demandController.text.trim(),
          'customerName': profile?.fullName,
          'customerAddress': profile?.fullAddress,
          'bankAccount': profile?.bankAccountNumber,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Pismo reklamacyjne wygenerowane! Sprawdź email.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;

    return AlertDialog(
      title: const Text('Generuj pismo reklamacyjne'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
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
                    Text('Kwota: ${widget.receipt.amount} zł'),
                  if (widget.receipt.purchaseDate != null)
                    Text(
                        'Data: ${widget.receipt.purchaseDate!.day}.${widget.receipt.purchaseDate!.month}.${widget.receipt.purchaseDate!.year}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Profile check
            if (profile == null ||
                profile.fullName.isEmpty ||
                profile.fullAddress.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Uzupełnij profil (imię, nazwisko, adres) dla lepszego wyniku.',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Opis problemu *',
                hintText: 'Opisz co jest nie tak z produktem/usługą',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _demandController,
              decoration: const InputDecoration(
                labelText: 'Żądanie',
                hintText: 'Np. zwrot pieniędzy, wymiana, naprawa',
              ),
              maxLines: 2,
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
          onPressed: _isGenerating ? null : _generateLetter,
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.description_rounded, size: 18),
          label: Text(_isGenerating ? 'Generowanie...' : 'Generuj pismo'),
        ),
      ],
    );
  }
}
