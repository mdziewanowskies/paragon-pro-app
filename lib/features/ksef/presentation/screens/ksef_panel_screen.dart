import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/share_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/cupertino_date_picker.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/locked_feature_view.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../widgets/ksef_settings.dart';
import '../widgets/ksef_invoice_table.dart';
import '../widgets/vat_summary.dart';
import '../../../receipts/data/receipt_repository.dart';
import '../../../receipts/data/models/receipt_model.dart';
import '../../data/ksef_repository.dart';

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
  String? _syncMessage;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  Future<void> _syncInvoices() async {
    final from = _dateFrom ?? DateTime.now().subtract(const Duration(days: 30));
    final to = _dateTo ?? DateTime.now();

    setState(() {
      _isSyncing = true;
      _syncMessage = 'Łączenie z KSeF...';
    });

    try {
      final ksefRepo = ref.read(ksefRepositoryProvider);

      setState(() => _syncMessage = 'Pobieranie faktur z KSeF...');

      final result = await ksefRepo.syncInvoices(
        dateFrom: from,
        dateTo: to,
      );

      ref.invalidate(ksefInvoicesProvider);

      if (mounted) {
        setState(() => _syncMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary),
            backgroundColor:
                result.saved > 0 ? Colors.green : null,
          ),
        );
      }
    } on KsefException catch (e) {
      if (mounted) {
        setState(() => _syncMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd KSeF: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _downloadInvoice(String ksefNumber) async {
    try {
      final ksefRepo = ref.read(ksefRepositoryProvider);
      final result = await ksefRepo.downloadInvoice(ksefNumber);

      if (mounted && result != null) {
        // Save XML to temp file and share
        final dir = await getTemporaryDirectory();
        final safeNumber = ksefNumber.replaceAll(RegExp(r'[^\w\-]'), '_');
        final file = File('${dir.path}/faktura_$safeNumber.xml');
        await file.writeAsString(result, encoding: utf8);

        await shareFiles(context, [XFile(file.path)],
            subject: 'Faktura KSeF: $ksefNumber');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('XML faktury gotowy do udostępnienia')),
          );
        }
        return;
      }
    } on KsefException catch (e) {
      if (mounted) {
        final msg = e.message.contains('PDF')
            ? 'KSeF nie udostępnia PDF — użyj eksportu XML w zakładce Raporty'
            : 'Błąd: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // KSeF is Premium-only. Free + Family Lite users hit a soft
    // upsell screen instead of the panel — keeps the feature visible
    // in nav for the natural funnel without leaking access.
    final sub = ref.watch(subscriptionProvider).valueOrNull;
    if (sub != null && !sub.isPremium) {
      return const LockedFeatureView(
        icon: Icons.description_rounded,
        title: 'KSeF — Twój Asystent VAT',
        description:
            'Synchronizuj faktury z Krajowego Systemu e-Faktur, '
            'pobieraj XML-e i ogarniaj VAT bez ręcznej roboty.',
        perks: [
          'Automatyczna synchronizacja faktur z KSeF API',
          'Eksport XML i pism reklamacyjnych',
          'Podsumowanie VAT w czasie rzeczywistym',
          'Bez limitów paragonów i pełna analityka',
        ],
        ctaLabel: 'Odblokuj KSeF z Premium',
        analyticsEvent: 'paywall_view_ksef',
      );
    }

    final profile = ref.watch(profileProvider);
    final invoices = ref.watch(ksefInvoicesProvider);
    final hasKsefToken = profile.value?.ksefToken != null &&
        profile.value!.ksefToken!.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
            Haptics.medium();
            ref.invalidate(ksefInvoicesProvider);
            await Future<void>.delayed(const Duration(milliseconds: 350));
            Haptics.success();
          },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KSeF settings — only when not configured
            if (!hasKsefToken) ...[
              KsefSettings(
                onTokenSaved: () => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],

            // Sync section — only when configured
            if (hasKsefToken) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sync_rounded,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Synchronizacja faktur',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pobierz faktury bezpośrednio z KSeF API (produkcja)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Date range
                      Row(
                        children: [
                          Expanded(
                            child: _DatePickerField(
                              label: 'Od',
                              value: _dateFrom,
                              onChanged: (d) =>
                                  setState(() => _dateFrom = d),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DatePickerField(
                              label: 'Do',
                              value: _dateTo,
                              onChanged: (d) =>
                                  setState(() => _dateTo = d),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Sync button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncInvoices,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_download_rounded),
                          label: Text(_isSyncing
                              ? (_syncMessage ?? 'Synchronizacja...')
                              : 'Pobierz faktury z KSeF'),
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
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : VatSummary(invoices: list),
              ),
              const SizedBox(height: 16),

              // Invoice table
              Row(
                children: [
                  Text(
                    'Faktury KSeF',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  invoices.when(
                    data: (list) => Text(
                      '${list.length} faktur',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              invoices.when(
                loading: () => const GenericCardSkeleton(),
                error: (e, _) => Text('Błąd: $e'),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.description_outlined,
                        title: 'Brak faktur KSeF',
                        subtitle:
                            'Wybierz zakres dat i kliknij "Pobierz faktury z KSeF"',
                      )
                    : KsefInvoiceTable(
                        invoices: list,
                        onDownloadXml: (ksefNumber) =>
                            _downloadInvoice(ksefNumber),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showCupertinoDateDialog(
          context: context,
          initialDate:
              value ?? DateTime.now().subtract(const Duration(days: 30)),
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
        );
        onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
        ),
        child: Text(
          value != null
              ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}'
              : 'Wybierz datę',
          style: TextStyle(
            fontSize: 14,
            color: value != null
                ? null
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
