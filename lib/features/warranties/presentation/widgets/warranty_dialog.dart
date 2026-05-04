import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/duplicate_detector.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_snackbar.dart';
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

  /// Builds the fingerprint string used by DuplicateDetector — what we
  /// consider "this warranty" for similarity purposes.
  String _fingerprint({
    required String merchant,
    required String notes,
    required ReceiptModel receipt,
  }) {
    final items = (receipt.items ?? const [])
        .map((it) => it is Map ? it['name']?.toString() ?? '' : '')
        .join(' ');
    return '$merchant $items $notes';
  }

  /// Pre-save check: query existing warranties for this user, compare
  /// fingerprints. Returns the first match or null.
  Future<Map<String, dynamic>?> _findDuplicate() async {
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final rows = await SupabaseService.client
          .from('warranties')
          .select('id, notes, receipts(id, merchant_name, items)')
          .eq('user_id', userId);

      final candidate = _fingerprint(
        merchant: widget.receipt.merchantName ?? '',
        notes: _notesController.text,
        receipt: widget.receipt,
      );

      for (final row in (rows as List)) {
        final existingReceipt =
            row['receipts'] as Map<String, dynamic>? ?? const {};
        final existingItems = existingReceipt['items'];
        final itemsText = existingItems is List
            ? existingItems
                .map((it) =>
                    it is Map ? it['name']?.toString() ?? '' : '')
                .join(' ')
            : '';
        final existingFp =
            '${existingReceipt['merchant_name'] ?? ''} $itemsText '
            '${row['notes'] ?? ''}';

        if (DuplicateDetector.isDuplicate(candidate, existingFp)) {
          return row as Map<String, dynamic>;
        }
      }
    } catch (e) {
      // If the duplicate check fails for any reason (network, schema)
      // fall through and let the insert proceed — never block save on
      // a defensive feature.
    }
    return null;
  }

  Future<void> _save() async {
    final months = int.tryParse(_monthsController.text);
    if (months == null || months < 1 || months > 120) {
      Haptics.error();
      AppSnack.show(
        context,
        'Podaj okres gwarancji (1-120 miesięcy)',
        kind: SnackKind.warning,
      );
      return;
    }

    setState(() => _isSaving = true);

    // F1-T1: fuzzy duplicate guard.
    final duplicate = await _findDuplicate();
    if (duplicate != null && mounted) {
      setState(() => _isSaving = false);
      final action = await _showDuplicateDialog(duplicate);
      if (action == _DupAction.openExisting) {
        AnalyticsService.warrantyDuplicateBlocked();
        // Close the create dialog so the user lands back on the
        // warranties list where the existing entry is visible.
        if (mounted) Navigator.pop(context);
        return;
      }
      if (action == _DupAction.cancel) {
        AnalyticsService.warrantyDuplicateBlocked();
        return;
      }
      // keepBoth → fall through and insert.
      setState(() => _isSaving = true);
    }

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

      // Schedule warranty expiry notifications (30, 7, 1 day before)
      final merchantName =
          widget.receipt.merchantName ?? 'Sklep';
      for (final daysBefore in [30, 7, 1]) {
        try {
          await NotificationService.scheduleWarrantyReminder(
            warrantyId: '${widget.receipt.id}_$daysBefore',
            merchantName: merchantName,
            expiryDate: endDate,
            daysBefore: daysBefore,
          );
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        Haptics.heavy();
        AnalyticsService.warrantyAdded(months: months);
        AppSnack.show(
          context,
          'Gwarancja $months miesięcy została dodana pomyślnie',
          kind: SnackKind.success,
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        AppSnack.show(
          context,
          'Błąd dodawania gwarancji: $e',
          kind: SnackKind.error,
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

  Future<_DupAction> _showDuplicateDialog(
    Map<String, dynamic> existing,
  ) async {
    Haptics.warning();
    final existingReceipt =
        existing['receipts'] as Map<String, dynamic>? ?? const {};
    final existingMerchant =
        (existingReceipt['merchant_name'] as String?) ?? 'Sklep';

    final result = await showDialog<_DupAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 22, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Wykryto duplikat')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wygląda na to, że masz już gwarancję dla podobnego '
              'produktu (sklep: $existingMerchant).',
            ),
            const SizedBox(height: 12),
            Text(
              'Chcesz dodać kolejną mimo wszystko?',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DupAction.cancel),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _DupAction.openExisting),
            child: const Text('Otwórz istniejącą'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _DupAction.keepBoth),
            child: const Text('Zachowaj oba'),
          ),
        ],
      ),
    );
    return result ?? _DupAction.cancel;
  }
}

enum _DupAction { cancel, openExisting, keepBoth }

