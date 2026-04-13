import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../widgets/ksef_settings.dart';
import '../widgets/ksef_invoice_table.dart';
import '../widgets/vat_summary.dart';
import '../../../receipts/data/receipt_repository.dart';
import '../../../receipts/data/models/receipt_model.dart';

final ksefInvoicesProvider =
    FutureProvider.autoDispose<List<ReceiptModel>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return [];
  return await ref.read(receiptRepositoryProvider).getKsefInvoices(
        userId: userId,
      );
});

class KsefPanelScreen extends ConsumerStatefulWidget {
  const KsefPanelScreen({super.key});

  @override
  ConsumerState<KsefPanelScreen> createState() => _KsefPanelScreenState();
}

class _KsefPanelScreenState extends ConsumerState<KsefPanelScreen> {
  bool _isSyncing = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  Future<void> _syncInvoices() async {
    setState(() => _isSyncing = true);
    try {
      final response = await SupabaseService.invokeFunction(
        'fetch-ksef-invoices',
        body: {
          'dateFrom': _dateFrom?.toIso8601String().split('T').first,
          'dateTo': _dateTo?.toIso8601String().split('T').first,
        },
      );

      if (mounted) {
        final count = response.data?['count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zsynchronizowano $count faktur z KSeF'),
          ),
        );
        ref.invalidate(ksefInvoicesProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd synchronizacji: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final invoices = ref.watch(ksefInvoicesProvider);
    final hasKsefToken = profile.value?.ksefToken != null &&
        profile.value!.ksefToken!.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ksefInvoicesProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasKsefToken) ...[
              const KsefSettings(),
              const SizedBox(height: 24),
            ],
            // Sync button
            if (hasKsefToken) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sync_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Synchronizacja KSeF',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _dateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null) setState(() => _dateFrom = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Od',
                                  isDense: true,
                                ),
                                child: Text(_dateFrom != null
                                    ? '${_dateFrom!.day}.${_dateFrom!.month}.${_dateFrom!.year}'
                                    : 'Wybierz'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _dateTo ?? DateTime.now(),
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null) setState(() => _dateTo = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Do',
                                  isDense: true,
                                ),
                                child: Text(_dateTo != null
                                    ? '${_dateTo!.day}.${_dateTo!.month}.${_dateTo!.year}'
                                    : 'Wybierz'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncInvoices,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(
                              _isSyncing ? 'Synchronizacja...' : 'Pobierz faktury'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // VAT Summary
              invoices.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) =>
                    list.isEmpty ? const SizedBox.shrink() : VatSummary(invoices: list),
              ),
              const SizedBox(height: 16),
              // Invoice table
              Text(
                'Faktury KSeF',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              invoices.when(
                loading: () => const LoadingSpinner(),
                error: (e, _) => Text('Błąd: $e'),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.description_outlined,
                        title: 'Brak faktur KSeF',
                        subtitle: 'Zsynchronizuj faktury z KSeF',
                      )
                    : KsefInvoiceTable(invoices: list),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
