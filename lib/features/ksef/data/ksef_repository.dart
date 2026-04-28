import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

      return _parseSyncResponse(response.data);
    } on FunctionException catch (e) {
      throw _parseFunctionException(e, 'synchronizacji faktur');
    } catch (e) {
      if (e is KsefException) rethrow;
      debugPrint('KSeF sync error: $e');
      throw KsefException('Błąd synchronizacji KSeF: $e');
    }
  }

  /// Download a single invoice as PDF/XML via Edge Function
  Future<String?> downloadInvoice(String ksefNumber) async {
    _ensureKsefConfigured();

    try {
      final response = await SupabaseService.invokeFunction(
        'download-ksef-invoice',
        body: {'ksefNumber': ksefNumber, 'format': 'xml'},
      );

      debugPrint('KSeF download response: ${response.status}');
      debugPrint('KSeF download data: ${response.data}');

      if (response.data == null) return null;

      final data = _parseMap(response.data);
      if (data == null) return null;

      final error = data['error'] as String?;
      if (error != null) throw KsefException(error);

      return data['url'] as String? ??
          data['xml'] as String? ??
          data['pdf'] as String?;
    } on FunctionException catch (e) {
      throw _parseFunctionException(e, 'pobierania faktury');
    } catch (e) {
      if (e is KsefException) rethrow;
      debugPrint('KSeF download error: $e');
      throw KsefException('Błąd pobierania faktury: $e');
    }
  }

  /// Test KSeF connection by calling the edge function with a small range
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

      final data = _parseMap(response.data);
      if (data == null) return false;

      // Edge Function returns {success: bool, ...}
      final success = data['success'] as bool? ?? false;
      if (!success) {
        final error = data['error'] as String?;
        debugPrint('KSeF test failed: $error');
        return false;
      }
      return true;
    } on FunctionException catch (e) {
      debugPrint('KSeF test FunctionException: ${e.status} ${e.details}');
      return false;
    } catch (e) {
      debugPrint('KSeF test connection failed: $e');
      return false;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────

  KsefSyncResult _parseSyncResponse(dynamic raw) {
    if (raw == null) {
      return KsefSyncResult(totalFetched: 0, saved: 0, skipped: 0);
    }

    final data = _parseMap(raw);
    if (data == null) {
      return KsefSyncResult(totalFetched: 0, saved: 0, skipped: 0);
    }

    final success = data['success'] as bool? ?? true;
    final error = data['error'] as String?;
    if (!success || error != null) {
      throw KsefException(error ?? 'Nieznany błąd KSeF');
    }

    // Edge Function actual response shape:
    // { success, environment, totalFound, newInvoices, message, invoices }
    final totalFound =
        data['totalFound'] as int? ?? data['count'] as int? ?? 0;
    final newInvoices = data['newInvoices'] as int? ??
        data['saved'] as int? ??
        0;
    final skipped = totalFound - newInvoices;
    final message = data['message'] as String?;

    return KsefSyncResult(
      totalFetched: totalFound,
      saved: newInvoices,
      skipped: skipped < 0 ? 0 : skipped,
      serverMessage: message,
    );
  }

  KsefException _parseFunctionException(
      FunctionException e, String operation) {
    debugPrint('=== KSeF FunctionException ===');
    debugPrint('Status: ${e.status}');
    debugPrint('Details: ${e.details}');
    debugPrint('Reason: ${e.reasonPhrase}');

    String? errorMessage;
    final details = e.details;
    if (details is Map) {
      errorMessage = details['error'] as String? ??
          details['message'] as String?;
    } else if (details is String && details.isNotEmpty) {
      errorMessage = details;
    }

    final statusLabel = e.status == 400
        ? 'Nieprawidłowe dane'
        : e.status == 401
            ? 'Brak autoryzacji'
            : e.status == 403
                ? 'Brak dostępu'
                : e.status == 500
                    ? 'Błąd serwera'
                    : 'Błąd';

    return KsefException(
      errorMessage ?? 'Błąd $operation ($statusLabel)',
      statusCode: e.status,
    );
  }

  Map<String, dynamic>? _parseMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
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
  final String? serverMessage;

  KsefSyncResult({
    required this.totalFetched,
    required this.saved,
    required this.skipped,
    this.serverMessage,
  });

  String get summary {
    // Prefer server's own message if available
    if (serverMessage != null && serverMessage!.isNotEmpty) {
      if (totalFetched > 0 && saved == 0) {
        return '$serverMessage (znaleziono $totalFetched, wszystkie już istnieją)';
      }
      return serverMessage!;
    }

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
  final int? statusCode;

  KsefException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
