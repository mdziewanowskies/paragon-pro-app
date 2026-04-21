import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/profile_service.dart';

final ksefRepositoryProvider = Provider<KsefRepository>((ref) {
  return KsefRepository(ref);
});

class KsefRepository {
  final Ref _ref;

  KsefRepository(this._ref);

  /// Sync invoices from KSeF via Edge Function.
  /// The Edge Function reads ksef_token and ksef_nip from the user's
  /// profile internally — no need to pass them from the client.
  Future<KsefSyncResult> syncInvoices({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) throw KsefException('Użytkownik niezalogowany');

    _ensureKsefConfigured();

    debugPrint('=== KSeF Sync via Edge Function ===');
    debugPrint('dateFrom: $dateFrom, dateTo: $dateTo');

    try {
      final response = await SupabaseService.invokeFunction(
        'fetch-ksef-invoices',
        body: {
          if (dateFrom != null)
            'dateFrom': dateFrom.toIso8601String().split('T').first,
          if (dateTo != null)
            'dateTo': dateTo.toIso8601String().split('T').first,
        },
      );

      debugPrint('KSeF Edge Function response status: ${response.status}');
      debugPrint('KSeF Edge Function data: ${response.data}');

      if (response.data == null) {
        return KsefSyncResult(totalFetched: 0, saved: 0, skipped: 0);
      }

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      final count = data['count'] as int? ?? 0;
      final saved = data['saved'] as int? ?? count;
      final skipped = data['skipped'] as int? ?? 0;
      final error = data['error'] as String?;

      if (error != null) {
        throw KsefException(error);
      }

      return KsefSyncResult(
        totalFetched: count,
        saved: saved,
        skipped: skipped,
      );
    } catch (e) {
      if (e is KsefException) rethrow;
      debugPrint('KSeF sync error: $e');
      throw KsefException('Błąd synchronizacji KSeF: $e');
    }
  }

  /// Download a single invoice as PDF via Edge Function
  Future<String?> downloadInvoice(String ksefNumber) async {
    _ensureKsefConfigured();

    try {
      final response = await SupabaseService.invokeFunction(
        'download-ksef-invoice',
        body: {'ksefNumber': ksefNumber},
      );

      debugPrint('KSeF download response: ${response.status}');

      if (response.data == null) return null;

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;

      return data?['url'] as String? ?? data?['xml'] as String?;
    } catch (e) {
      debugPrint('KSeF download error: $e');
      throw KsefException('Błąd pobierania faktury: $e');
    }
  }

  /// Test KSeF connection by calling the edge function
  Future<bool> testConnection() async {
    _ensureKsefConfigured();

    try {
      final response = await SupabaseService.invokeFunction(
        'fetch-ksef-invoices',
        body: {
          'dateFrom': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .split('T')
              .first,
          'dateTo': DateTime.now().toIso8601String().split('T').first,
        },
      );

      debugPrint('KSeF test response: ${response.status}');
      debugPrint('KSeF test data: ${response.data}');

      // If we got a response without error, connection is OK
      if (response.data is Map) {
        final error = (response.data as Map)['error'];
        if (error != null) {
          debugPrint('KSeF test failed: $error');
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('KSeF test connection failed: $e');
      return false;
    }
  }

  void _ensureKsefConfigured() {
    final profile = _ref.read(profileProvider).value;
    if (profile?.ksefNip == null || profile!.ksefNip!.isEmpty) {
      throw KsefException('Uzupełnij NIP w ustawieniach KSeF');
    }
    if (profile.ksefToken == null || profile.ksefToken!.isEmpty) {
      throw KsefException('Uzupełnij token API KSeF w ustawieniach');
    }
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
    if (totalFetched == 0) return 'Brak nowych faktur w wybranym zakresie';
    final parts = <String>[];
    if (saved > 0) parts.add('$saved nowych');
    if (skipped > 0) parts.add('$skipped pominięto (duplikaty)');
    if (parts.isEmpty) return 'Pobrano $totalFetched faktur';
    return 'Pobrano ${parts.join(', ')}';
  }
}

class KsefException implements Exception {
  final String message;
  KsefException(this.message);

  @override
  String toString() => message;
}
