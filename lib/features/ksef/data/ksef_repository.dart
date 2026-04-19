import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/profile_service.dart';
import 'ksef_api_service.dart';
import 'models/ksef_models.dart';

final ksefApiServiceProvider = Provider<KsefApiService>((ref) {
  return KsefApiService(environment: KsefEnvironment.production);
});

final ksefRepositoryProvider = Provider<KsefRepository>((ref) {
  return KsefRepository(ref);
});

class KsefRepository {
  final Ref _ref;

  KsefRepository(this._ref);

  KsefApiService get _api => _ref.read(ksefApiServiceProvider);

  /// Start a KSeF session using stored credentials from profile
  Future<KsefSessionToken> startSession() async {
    final profile = _ref.read(profileProvider).value;
    if (profile == null) {
      throw KsefApiException('Zaloguj się do aplikacji');
    }
    if (profile.ksefNip == null || profile.ksefNip!.isEmpty) {
      throw KsefApiException('Uzupełnij NIP w ustawieniach KSeF');
    }
    if (profile.ksefToken == null || profile.ksefToken!.isEmpty) {
      throw KsefApiException('Uzupełnij token API KSeF w ustawieniach');
    }

    return await _api.initSessionWithToken(
      nip: profile.ksefNip!,
      apiToken: profile.ksefToken!,
    );
  }

  /// Ensure we have an active session, start one if needed
  Future<void> ensureSession() async {
    if (!_api.hasActiveSession) {
      await startSession();
    }
  }

  /// Fetch invoices from KSeF and save them to Supabase
  Future<KsefSyncResult> syncInvoices({
    required DateTime dateFrom,
    required DateTime dateTo,
    String subjectType = 'subject1',
  }) async {
    await ensureSession();

    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) throw KsefApiException('Użytkownik niezalogowany');

    debugPrint('=== KSeF Sync: $dateFrom - $dateTo ===');

    final criteria = KsefQueryCriteria(
      dateFrom: dateFrom,
      dateTo: dateTo,
      subjectType: subjectType,
    );

    // Try synchronous query first (up to 100 invoices)
    List<KsefInvoice> invoices;
    try {
      invoices = await _api.queryInvoicesSync(criteria: criteria);
    } catch (e) {
      debugPrint('Sync query failed, trying async: $e');
      invoices = await _fetchInvoicesAsync(criteria);
    }

    debugPrint('KSeF: fetched ${invoices.length} invoices');

    // Save to Supabase
    int saved = 0;
    int skipped = 0;
    for (final invoice in invoices) {
      try {
        // Check if already exists
        final existing = await SupabaseService.client
            .from('receipts')
            .select('id')
            .eq('user_id', userId)
            .eq('ksef_number', invoice.ksefReferenceNumber)
            .maybeSingle();

        if (existing != null) {
          skipped++;
          continue;
        }

        // Insert new invoice as receipt
        await SupabaseService.client
            .from('receipts')
            .insert(invoice.toReceiptJson(userId));
        saved++;
      } catch (e) {
        debugPrint(
            'KSeF: failed to save invoice ${invoice.ksefReferenceNumber}: $e');
      }
    }

    debugPrint('KSeF Sync complete: $saved saved, $skipped skipped');

    // Terminate session
    await _api.terminateSession();

    return KsefSyncResult(
      totalFetched: invoices.length,
      saved: saved,
      skipped: skipped,
    );
  }

  /// Fetch invoices using async query (for large datasets)
  Future<List<KsefInvoice>> _fetchInvoicesAsync(
      KsefQueryCriteria criteria) async {
    final queryId = await _api.queryInvoicesAsyncInit(criteria: criteria);

    // Poll for completion (max 60 seconds)
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 2));

      final status = await _api.queryInvoicesAsyncStatus(queryId);
      final processingCode = status['processingCode'] as int? ?? 0;

      debugPrint('KSeF Async status: processingCode=$processingCode');

      if (processingCode == 200) {
        // Ready to fetch
        return await _api.queryInvoicesAsyncFetch(queryId);
      }
      if (processingCode >= 400) {
        throw KsefApiException(
          'Błąd zapytania KSeF: ${status['processingDescription'] ?? processingCode}',
        );
      }
    }

    throw KsefApiException('Przekroczono czas oczekiwania na dane z KSeF');
  }

  /// Download full invoice XML
  Future<String> downloadInvoiceXml(String ksefReferenceNumber) async {
    await ensureSession();
    final xml = await _api.downloadInvoice(ksefReferenceNumber);
    await _api.terminateSession();
    return xml;
  }

  /// Test connection - try to start and terminate session
  Future<bool> testConnection() async {
    try {
      await startSession();
      await _api.terminateSession();
      return true;
    } catch (e) {
      debugPrint('KSeF test connection failed: $e');
      return false;
    }
  }

  /// Get invoice status from KSeF (public endpoint, no session needed)
  Future<Map<String, dynamic>> getInvoiceStatus(
      String ksefReferenceNumber) async {
    return await _api.getInvoiceStatus(ksefReferenceNumber);
  }
}

class KsefSyncResult {
  final int totalFetched;
  final int saved;
  final int skipped;

  KsefSyncResult({
    required this.totalFetched,
    required this.saved,
    required this.skipped,
  });

  String get summary {
    final parts = <String>[];
    if (saved > 0) parts.add('$saved nowych');
    if (skipped > 0) parts.add('$skipped pominięto (duplikaty)');
    if (parts.isEmpty) return 'Brak nowych faktur';
    return 'Pobrano ${parts.join(', ')}';
  }
}
